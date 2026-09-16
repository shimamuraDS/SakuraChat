mod store;
use libsignal_protocol::*;
use rand::{Rng, TryRngCore};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{collections::BTreeMap, time::SystemTime};
use store::*;
use zeroize::Zeroize;

type Error = Box<dyn std::error::Error>;
type Result<T> = std::result::Result<T, Error>;

#[derive(Serialize, Deserialize)]
struct Bundle {
    registration: u32,
    id: u32,
    identity: Vec<u8>,
    prekey: Vec<u8>,
    signed: Vec<u8>,
    signature: Vec<u8>,
    kyber: Vec<u8>,
    kyber_signature: Vec<u8>,
}
fn address(name: &str) -> Result<ProtocolAddress> {
    if name.is_empty() || name.len() > 128 || name.contains(':') { return Err("invalid account".into()); }
    Ok(ProtocolAddress::new(name.to_owned(), DeviceId::new(1).map_err(|_| "device")?))
}
fn bytes(value: &Value, key: &str) -> Result<Vec<u8>> { Ok(serde_json::from_value(value[key].clone())?) }

async fn operation(input: Value) -> Result<Value> {
    let op = input["op"].as_str().ok_or("operation")?;
    let mut rng = rand::rngs::OsRng.unwrap_err();
    let mut state: State = if op == "create" {
        let account = input["account"].as_str().ok_or("account")?.to_owned();
        address(&account)?;
        State { version: 1, account, verified: BTreeMap::new(), published_bundles: 0, pending_bundle: Value::Null,
            identity: Identities { pair: IdentityKeyPair::generate(&mut rng).serialize().into_vec(),
                registration: rng.random_range(1..16384), approved: BTreeMap::new() },
            sessions: Sessions::default(), prekeys: PreKeys::default(), signed: SignedKeys::default(),
            kyber: KyberKeys::default(), next_prekey: 1 }
    } else { serde_json::from_value(input["state"].clone())? };
    if state.version != 1 { return Err("state version".into()); }
    let local = address(&state.account)?;
    let pair = state.identity.get_identity_key_pair().await?;
    let mut output = json!({});
    match op {
        "create" | "public_identity" => { output["identity"] = json!(pair.identity_key().serialize().to_vec()); }
        "bundle" => {
            if state.prekeys.0.len() >= 100 || state.signed.0.len() >= 100 { return Err("prekey capacity".into()); }
            let id = state.next_prekey;
            state.next_prekey = id.checked_add(1).ok_or("prekey exhausted")?;
            let ec = KeyPair::generate(&mut rng);
            let signed = KeyPair::generate(&mut rng);
            let kyber = kem::KeyPair::generate(kem::KeyType::Kyber1024, &mut rng);
            let signature = pair.private_key().calculate_signature(&signed.public_key.serialize(), &mut rng)?;
            let kyber_signature = pair.private_key().calculate_signature(&kyber.public_key.serialize(), &mut rng)?;
            let timestamp = Timestamp::from_epoch_millis(SystemTime::now().duration_since(SystemTime::UNIX_EPOCH)?.as_millis() as u64);
            state.prekeys.save_pre_key(id.into(), &PreKeyRecord::new(id.into(), &ec)).await?;
            state.signed.save_signed_pre_key(id.into(), &SignedPreKeyRecord::new(id.into(), timestamp, &signed, &signature)).await?;
            state.kyber.save_kyber_pre_key(id.into(), &KyberPreKeyRecord::new(id.into(), timestamp, &kyber, &kyber_signature)).await?;
            output["bundle"] = serde_json::to_value(Bundle { registration: state.identity.registration, id,
                identity: pair.identity_key().serialize().to_vec(), prekey: ec.public_key.serialize().to_vec(),
                signed: signed.public_key.serialize().to_vec(), signature: signature.to_vec(),
                kyber: kyber.public_key.serialize().to_vec(), kyber_signature: kyber_signature.to_vec() })?;
        }
        "approve" | "safety_number" | "first_trust" => {
            let remote = address(input["peer"].as_str().ok_or("peer")?)?;
            let key = IdentityKey::decode(&bytes(&input, "identity")?)?;
            output["safety_number"] = json!(Fingerprint::new(2, 5200, state.account.as_bytes(), pair.identity_key(),
                remote.name().as_bytes(), &key).map_err(|_| "fingerprint")?.display_string().map_err(|_| "fingerprint")?);
            if op == "approve" || op == "first_trust" {
                let name = address_key(&remote);
                let serialized = key.serialize().to_vec();
                let changed = state.identity.approved.get(&name).is_some_and(|saved| saved != &serialized);
                output["identity_changed"] = json!(changed && op == "first_trust");
                if op == "approve" || !changed {
                    if changed { state.sessions.0.remove(&name); }
                    state.identity.approved.insert(name.clone(), serialized.clone());
                    if op == "approve" { state.verified.insert(name.clone(), serialized.clone()); }
                }
                output["verified"] = json!(state.verified.get(&name) == Some(&serialized));
                output["has_session"] = json!(match state.sessions.load_session(&remote).await? {
                    Some(session) => session.has_usable_sender_chain(SystemTime::now(), SessionUsabilityRequirements::all())?,
                    None => false,
                });
            }
        }
        "establish" => {
            let remote = address(input["peer"].as_str().ok_or("peer")?)?;
            let b: Bundle = serde_json::from_value(input["bundle"].clone())?;
            let bundle = PreKeyBundle::new(b.registration, DeviceId::new(1).map_err(|_| "device")?,
                Some((b.id.into(), PublicKey::deserialize(&b.prekey)?)), b.id.into(), PublicKey::deserialize(&b.signed)?,
                b.signature, b.id.into(), kem::PublicKey::deserialize(&b.kyber)?, b.kyber_signature,
                IdentityKey::decode(&b.identity)?)?;
            process_prekey_bundle(&remote, &local, &mut state.sessions, &mut state.identity, &bundle,
                                  SystemTime::now(), &mut rng).await?;
        }
        "encrypt" => {
            let remote = address(input["peer"].as_str().ok_or("peer")?)?;
            let plain = bytes(&input, "plaintext")?;
            if plain.is_empty() || plain.len() > 16384 { return Err("plaintext size".into()); }
            let message = message_encrypt(&plain, &remote, &local, &mut state.sessions, &mut state.identity,
                                          SystemTime::now(), &mut rng).await?;
            output["kind"] = json!(message.message_type() as u8);
            output["ciphertext"] = json!(message.serialize());
        }
        "decrypt" => {
            let remote = address(input["peer"].as_str().ok_or("peer")?)?;
            let cipher = bytes(&input, "ciphertext")?;
            if cipher.len() > 65536 { return Err("ciphertext size".into()); }
            let message = match input["kind"].as_u64() {
                Some(2) => CiphertextMessage::SignalMessage(SignalMessage::try_from(cipher.as_slice())?),
                Some(3) => CiphertextMessage::PreKeySignalMessage(PreKeySignalMessage::try_from(cipher.as_slice())?),
                _ => return Err("ciphertext kind".into()),
            };
            output["plaintext"] = json!(message_decrypt(&message, &remote, &local, &mut state.sessions,
                &mut state.identity, &mut state.prekeys, &state.signed, &mut state.kyber, &mut rng).await?);
        }
        _ => return Err("unknown operation".into()),
    }
    output["state"] = serde_json::to_value(state)?;
    Ok(output)
}

/// JSON is a local ABI envelope, never a network format. State contains private keys.
pub fn execute(input: &[u8]) -> Result<Vec<u8>> {
    if input.len() > 16 * 1024 * 1024 { return Err("request size".into()); }
    let output = futures::executor::block_on(operation(serde_json::from_slice(input)?))?;
    Ok(serde_json::to_vec(&output)?)
}

#[repr(C)]
pub struct Buffer { pub data: *mut u8, pub len: usize }

#[unsafe(no_mangle)]
pub extern "C" fn sakura_signal_abi_version() -> u32 { 1 }

/// # Safety
/// Input must reference `len` readable bytes; output must point to a writable Buffer.
/// Calls are stateless. Caller must persist output state atomically with the message.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn sakura_signal_call(input: *const u8, len: usize, output: *mut Buffer) -> i32 {
    if output.is_null() { return 1; }
    unsafe { *output = Buffer { data: std::ptr::null_mut(), len: 0 }; }
    if input.is_null() || len == 0 || len > 16 * 1024 * 1024 { return 1; }
    let result = std::panic::catch_unwind(|| execute(unsafe { std::slice::from_raw_parts(input, len) }));
    match result {
        Ok(Ok(bytes)) => {
            let bytes = bytes.into_boxed_slice();
            let len = bytes.len();
            unsafe { *output = Buffer { data: Box::into_raw(bytes) as *mut u8, len }; }
            0
        }
        _ => 2, // Never expose crypto errors, input, or private state through logs.
    }
}

/// # Safety
/// Buffer must be an unfreed result of sakura_signal_call from this same library.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn sakura_signal_free(buffer: Buffer) {
    if !buffer.data.is_null() {
        let mut bytes = unsafe { Box::from_raw(std::ptr::slice_from_raw_parts_mut(buffer.data, buffer.len)) };
        bytes.zeroize();
    }
}

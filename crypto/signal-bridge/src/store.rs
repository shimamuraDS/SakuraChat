use async_trait::async_trait;
use libsignal_protocol::*;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
type Result<T> = std::result::Result<T, SignalProtocolError>;

pub fn address_key(address: &ProtocolAddress) -> String {
    format!("{}:{}", address.name(), address.device_id())
}

#[derive(Clone, Serialize, Deserialize)]
pub struct Identities {
    pub pair: Vec<u8>,
    pub registration: u32,
    pub approved: BTreeMap<String, Vec<u8>>,
}
#[async_trait(?Send)]
impl IdentityKeyStore for Identities {
    async fn get_identity_key_pair(&self) -> Result<IdentityKeyPair> { IdentityKeyPair::try_from(self.pair.as_slice()) }
    async fn get_local_registration_id(&self) -> Result<u32> { Ok(self.registration) }
    async fn is_trusted_identity(&self, address: &ProtocolAddress, identity: &IdentityKey, _: Direction) -> Result<bool> {
        Ok(self.approved.get(&address_key(address)).is_some_and(|key| key.as_slice() == identity.serialize().as_ref()))
    }
    async fn save_identity(&mut self, address: &ProtocolAddress, identity: &IdentityKey) -> Result<IdentityChange> {
        if !self.is_trusted_identity(address, identity, Direction::Sending).await? {
            return Err(SignalProtocolError::UntrustedIdentity(address.clone()));
        }
        Ok(IdentityChange::NewOrUnchanged)
    }
    async fn get_identity(&self, address: &ProtocolAddress) -> Result<Option<IdentityKey>> {
        self.approved.get(&address_key(address)).map(|key| IdentityKey::decode(key)).transpose()
    }
}

#[derive(Clone, Default, Serialize, Deserialize)]
pub struct Sessions(pub BTreeMap<String, Vec<u8>>);
#[async_trait(?Send)]
impl SessionStore for Sessions {
    async fn load_session(&self, address: &ProtocolAddress) -> Result<Option<SessionRecord>> {
        self.0.get(&address_key(address)).map(|v| SessionRecord::deserialize(v)).transpose()
    }
    async fn store_session(&mut self, address: &ProtocolAddress, record: &SessionRecord) -> Result<()> {
        self.0.insert(address_key(address), record.serialize()?); Ok(())
    }
}

#[derive(Clone, Default, Serialize, Deserialize)]
pub struct PreKeys(pub BTreeMap<u32, Vec<u8>>);
#[async_trait(?Send)]
impl PreKeyStore for PreKeys {
    async fn get_pre_key(&self, id: PreKeyId) -> Result<PreKeyRecord> {
        PreKeyRecord::deserialize(self.0.get(&u32::from(id)).ok_or(SignalProtocolError::InvalidPreKeyId)?)
    }
    async fn save_pre_key(&mut self, id: PreKeyId, record: &PreKeyRecord) -> Result<()> {
        self.0.insert(id.into(), record.serialize()?); Ok(())
    }
    async fn remove_pre_key(&mut self, id: PreKeyId) -> Result<()> { self.0.remove(&id.into()); Ok(()) }
}

#[derive(Clone, Default, Serialize, Deserialize)]
pub struct SignedKeys(pub BTreeMap<u32, Vec<u8>>);
#[async_trait(?Send)]
impl SignedPreKeyStore for SignedKeys {
    async fn get_signed_pre_key(&self, id: SignedPreKeyId) -> Result<SignedPreKeyRecord> {
        SignedPreKeyRecord::deserialize(self.0.get(&u32::from(id)).ok_or(SignalProtocolError::InvalidSignedPreKeyId)?)
    }
    async fn save_signed_pre_key(&mut self, id: SignedPreKeyId, record: &SignedPreKeyRecord) -> Result<()> {
        self.0.insert(id.into(), record.serialize()?); Ok(())
    }
}

#[derive(Clone, Default, Serialize, Deserialize)]
pub struct KyberKeys(pub BTreeMap<u32, Vec<u8>>);
#[async_trait(?Send)]
impl KyberPreKeyStore for KyberKeys {
    async fn get_kyber_pre_key(&self, id: KyberPreKeyId) -> Result<KyberPreKeyRecord> {
        KyberPreKeyRecord::deserialize(self.0.get(&u32::from(id)).ok_or(SignalProtocolError::InvalidKyberPreKeyId)?)
    }
    async fn save_kyber_pre_key(&mut self, id: KyberPreKeyId, record: &KyberPreKeyRecord) -> Result<()> {
        self.0.insert(id.into(), record.serialize()?); Ok(())
    }
    async fn mark_kyber_pre_key_used(&mut self, id: KyberPreKeyId, _: SignedPreKeyId, _: &PublicKey) -> Result<()> {
        self.0.remove(&id.into()).ok_or(SignalProtocolError::InvalidKyberPreKeyId)?; Ok(())
    }
}

#[derive(Clone, Serialize, Deserialize)]
pub struct State {
    #[serde(default)]
    pub verified: BTreeMap<String, Vec<u8>>,
    #[serde(default)]
    pub published_bundles: u32,
    #[serde(default)]
    pub pending_bundle: serde_json::Value,
    pub version: u32,
    pub account: String,
    pub identity: Identities,
    pub sessions: Sessions,
    pub prekeys: PreKeys,
    pub signed: SignedKeys,
    pub kyber: KyberKeys,
    pub next_prekey: u32,
}

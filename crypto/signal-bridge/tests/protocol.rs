use sakura_signal_bridge::execute;
use serde_json::{Value, json};

struct Device { state: Value, identity: Value }
impl Device {
    fn new(name: &str) -> Self {
        let result: Value = serde_json::from_slice(&execute(&serde_json::to_vec(&json!({"op":"create", "account":name})).unwrap()).unwrap()).unwrap();
        Self { state: result["state"].clone(), identity: result["identity"].clone() }
    }
    fn run(&mut self, mut request: Value) -> Result<Value, Box<dyn std::error::Error>> {
        request["state"] = self.state.clone();
        let result: Value = serde_json::from_slice(&execute(&serde_json::to_vec(&request)?)?)?;
        self.state = result["state"].clone();
        Ok(result)
    }
}
fn setup() -> (Device, Device) {
    let mut alice = Device::new("alice");
    let mut bob = Device::new("bob");
    let bundle = bob.run(json!({"op":"bundle"})).unwrap()["bundle"].clone();
    assert!(alice.run(json!({"op":"establish", "peer":"bob", "bundle":bundle})).is_err());
    let a = alice.run(json!({"op":"approve", "peer":"bob", "identity":bob.identity})).unwrap();
    let b = bob.run(json!({"op":"approve", "peer":"alice", "identity":alice.identity})).unwrap();
    assert_eq!(a["safety_number"], b["safety_number"]);
    alice.run(json!({"op":"establish", "peer":"bob", "bundle":bundle})).unwrap();
    (alice, bob)
}
fn receive(peer: &str, message: &Value) -> Value {
    json!({"op":"decrypt", "peer":peer, "kind":message["kind"], "ciphertext":message["ciphertext"]})
}

#[test]
fn first_trust_is_not_verification_and_never_replaces_a_pinned_identity() {
    let mut alice = Device::new("alice");
    let mut bob = Device::new("bob");
    let bundle = bob.run(json!({"op":"bundle"})).unwrap()["bundle"].clone();
    let trust = alice.run(json!({"op":"first_trust", "peer":"bob", "identity":bob.identity})).unwrap();
    assert_eq!(trust["verified"], false);
    assert_eq!(trust["identity_changed"], false);
    alice.run(json!({"op":"establish", "peer":"bob", "bundle":bundle})).unwrap();
    bob.run(json!({"op":"first_trust", "peer":"alice", "identity":alice.identity})).unwrap();
    let message = alice.run(json!({"op":"encrypt", "peer":"bob", "plaintext":b"TOFU"})).unwrap();
    assert_eq!(bob.run(receive("alice", &message)).unwrap()["plaintext"], json!(b"TOFU"));
    let verified = alice.run(json!({"op":"approve", "peer":"bob", "identity":bob.identity})).unwrap();
    assert_eq!(verified["verified"], true);
    let replacement = Device::new("bob");
    let before = alice.state.clone();
    let changed = alice.run(json!({"op":"first_trust", "peer":"bob", "identity":replacement.identity})).unwrap();
    assert_eq!(changed["identity_changed"], true);
    assert_eq!(changed["verified"], false);
    assert_eq!(alice.state, before);
    let same = alice.run(json!({"op":"first_trust", "peer":"bob", "identity":bob.identity})).unwrap();
    assert_eq!(same["verified"], true);
    assert_eq!(same["has_session"], true);
}

#[test]
fn roundtrip_restart_out_of_order_and_replay() {
    let (mut alice, mut bob) = setup();
    let message = alice.run(json!({"op":"encrypt", "peer":"bob", "plaintext":b"hello"})).unwrap();
    assert_eq!(bob.run(receive("alice", &message)).unwrap()["plaintext"], json!(b"hello"));
    let before = bob.state.clone();
    assert!(bob.run(receive("alice", &message)).is_err());
    assert_eq!(bob.state, before);
    let reply = bob.run(json!({"op":"encrypt", "peer":"alice", "plaintext":b"reply"})).unwrap();
    assert_eq!(alice.run(receive("bob", &reply)).unwrap()["plaintext"], json!(b"reply"));
    let one = alice.run(json!({"op":"encrypt", "peer":"bob", "plaintext":b"one"})).unwrap();
    let two = alice.run(json!({"op":"encrypt", "peer":"bob", "plaintext":b"two"})).unwrap();
    // Each operation reconstructs the store from serialized state, including skipped-message keys.
    assert_eq!(bob.run(receive("alice", &two)).unwrap()["plaintext"], json!(b"two"));
    assert_eq!(bob.run(receive("alice", &one)).unwrap()["plaintext"], json!(b"one"));
}

#[test]
fn tampering_and_identity_change_fail_without_state_commit() {
    let (mut alice, mut bob) = setup();
    let message = alice.run(json!({"op":"encrypt", "peer":"bob", "plaintext":b"secret"})).unwrap();
    let before = bob.state.clone();
    let mut bad = receive("alice", &message);
    let data = bad["ciphertext"].as_array_mut().unwrap();
    let last = data.last_mut().unwrap(); *last = json!(last.as_u64().unwrap() ^ 1);
    assert!(bob.run(bad).is_err());
    assert_eq!(bob.state, before);
    assert!(bob.run(receive("alice", &message)).is_ok());
    let mut replacement = Device::new("bob");
    let bundle = replacement.run(json!({"op":"bundle"})).unwrap()["bundle"].clone();
    let before = alice.state.clone();
    assert!(alice.run(json!({"op":"establish", "peer":"bob", "bundle":bundle})).is_err());
    assert_eq!(alice.state, before);
}

#[test]
fn malformed_abi_input_is_rejected() {
    assert!(execute(b"not json").is_err());
    assert!(execute(br#"{"op":"decrypt","state":{}}"#).is_err());
    assert!(execute(&vec![0; 16 * 1024 * 1024 + 1]).is_err());
}

#[test]
fn identity_lookup_and_session_reuse_preserve_upload_recovery() {
    let (mut alice, bob) = setup();
    alice.state["pending_bundle"] = json!({"id":17});
    alice.state["published_bundles"] = json!(3);
    let identity = alice.run(json!({"op":"public_identity"})).unwrap();
    assert_eq!(identity["identity"], alice.identity);
    let approved = alice.run(json!({"op":"approve","peer":"bob","identity":bob.identity})).unwrap();
    assert_eq!(approved["has_session"], true);
    assert_eq!(alice.state["pending_bundle"], json!({"id":17}));
    assert_eq!(alice.state["published_bundles"], 3);
    let replacement = Device::new("bob");
    let changed = alice.run(json!({"op":"approve","peer":"bob","identity":replacement.identity})).unwrap();
    assert_eq!(changed["has_session"], false);
}

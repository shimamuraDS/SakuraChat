# Corresponding source — 0.1.2

The source archive contains the client, C ABI bridge, Cargo.lock, vendored Rust
dependencies and their license notices. Run Cargo from the archive root so it
loads `.cargo/config.toml`. Use Rust 1.98.1 MSVC with native Windows build tools,
Qt 6.8.3 MinGW x64, GCC 13.1, CMake and Ninja.

```powershell
cargo test --release --locked --offline --manifest-path crypto/signal-bridge/Cargo.toml
cargo build --release --locked --offline --manifest-path crypto/signal-bridge/Cargo.toml
cmake -S . -B build -G Ninja '-DCMAKE_BUILD_TYPE=Release' '-DSAKURA_DISTRIBUTION=ON' '-DSAKURA_RELEASE_VERSION=0.1.2' '-DSAKURA_PUBLISHER=shimamuraDS' '-DSAKURA_GATEWAY=https://47.105.85.58:8443' "-DSAKURA_CA_FILE=$PWD/ca.crt" '-DCMAKE_PREFIX_PATH=<Qt-directory>'
cmake --build build --target appSakuraChat tlsconfig_tests
```

Copy the Release bridge DLL beside the executable. See `docs/RELEASE.md` and
`tools/package-portable.ps1` for deployment. Public CA trust is embedded, not
read from an editable distribution configuration. No private keys are included.

Matching unmodified Qt and OpenSSL source archives are separate release assets.
All dependencies retain their licenses; see `licenses/` and
`release/THIRD_PARTY_NOTICES.txt`. Compatible LGPL dynamic libraries may be
replaced. The toolchains themselves are not included.

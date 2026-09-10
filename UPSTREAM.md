# Upstream provenance

`packages/quantus_sdk` was copied from the official
[`Quantus-Network/quantus-apps`](https://github.com/Quantus-Network/quantus-apps) repository at commit:

```text
76df7b06d7a092c9cdfb9a459f8effb9ddb5e737
```

The snapshot was taken on 2026-09-10 for the Quantus mainnet wallet build.

Local integration patches are intentionally limited to Android build plumbing:

- compile the native bridge with Android API 36 for current AndroidX compatibility;
- honor `ONLY_ARM64=true` so Cargokit builds only `aarch64-linux-android`.
- expose a supplied-keypair signing entry point so the app never has to persist a plaintext mnemonic.
- remove the iOS bridge declaration and source from this Android-only project.
- remove an unreferenced prebuilt Apple framework from the Android-only source tree.
- allow dated Rust channels and pin Cargokit to the known-good `nightly-2025-12-20` toolchain for reproducible CI builds.

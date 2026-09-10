# Security model

- Mnemonics are encrypted with AES-256-GCM. The key is derived from the user's wallet password with Argon2id
  (`64 MiB`, three iterations, one lane, a random 128-bit salt). The authenticated-encryption context binds the
  ciphertext to the wallet address, derivation path, and signature scheme.
- Only the versioned ciphertext envelope is stored through `flutter_secure_storage`. Android adds
  Keystore-backed RSA-OAEP/AES-GCM protection; the wallet password itself is never stored.
- Every transfer requires the wallet password. Decryption and ML-DSA key derivation happen only in memory for
  that signing operation; mutable secret-key buffers are overwritten immediately afterward.
- The current Dart flow briefly materializes the decrypted mnemonic as an immutable `String`. Its backing memory
  cannot be explicitly overwritten and becomes reclaimable only after garbage collection. The plaintext is never
  persisted, but this build does not claim immediate physical erasure of every in-memory copy.
- The mnemonic is never sent to an RPC endpoint and is not written to logs, preferences, analytics, or crash reports.
- The app only accepts the Quantus mainnet genesis
  `0xfb5487c0be6ae4ade2d41d16e50465129861636c2b8d61fa94d7a19631626fba`.
- Signing is blocked unless the runtime is exactly spec 152 / transaction version 6. A runtime upgrade requires
  review and a new app build.
- Mainnet RPC failover is provided by the official endpoints `rpc1-mainnet.quantus.com` and
  `rpc2-mainnet.quantus.com`.

This is newly assembled wallet software and has not received an independent security audit. Test with a small
amount before relying on it, keep an offline mnemonic backup, and never install builds from an untrusted source.

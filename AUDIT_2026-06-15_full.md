# RabbitChain Wallet Mobile — Full Audit (2026-06-15)

**Scope:** `rabbitchain-wallet-mobile/` (Flutter / Dart, ed25519 compute-wallet).
**Audit dimensions:** (A) Code quality, (B) Protocol semantics, (C) Concurrency.
**Method:** source review of every `.dart` under `lib/`, manifest, gradle, dependency manifests, and cross-check against `Rabbit-Chain-node/crates/rabbitcore/src/compute/tx.rs` and `rabbitchain-wallet-chrome/src/core/wallet/ComputeTx.ts`.
**Tooling availability:** `dart` / `flutter` are not on PATH in this sandbox, so `dart analyze` and `flutter --version` could not be executed. Findings are based on static review.

---

## 0. Repository fact sheet

| Item | Value | Source |
| --- | --- | --- |
| Dart SDK | `^3.11.0` (Dart 3, sound null-safety) | `pubspec.yaml:8` |
| Lint set | `package:flutter_lints/flutter.yaml` (default), no custom rules enabled | `analysis_options.yaml:10` |
| State management | `provider` 6.1.1 used; `riverpod` / `flutter_riverpod` 2.4.9 declared but **not imported** anywhere in `lib/` | `pubspec.yaml:14-16`; grep `lib/` |
| Signing | `cryptography` 2.6.1 (`Ed25519`, `AesGcm`, `Pbkdf2`) + `pointycastle` `KeccakDigest(256)` | `pubspec.yaml:18-19`; `lib/core/utils/crypto_utils.dart:39-43` |
| Wallet storage | `flutter_secure_storage` 9.0.0 (no `AndroidOptions` / `IOSOptions` configured) | `pubspec.yaml:29`; `wallet_provider.dart:31` |
| RPC client | `dio` 5.4.0 (no `HttpClientAdapter` override, no cert pinning) | `pubspec.yaml:24`; `rpc_client.dart:13-22` |
| WebSocket | `web_socket_channel` declared in deps but **never imported** | `pubspec.yaml:25`; grep |
| `web3dart` / `http` / `wallet` / `image_gallery_saver_plus` / `local_auth` declared but never imported in `lib/` | dead dependencies | grep `lib/` |
| Lint count | analyzer not run (tooling absent) | n/a |
| Android `usesCleartextTraffic` | `true` (manifest line 10) | `android/app/src/main/AndroidManifest.xml:10` |
| Android release signing | `signingConfigs.getByName("debug")` (placeholder) | `android/app/build.gradle.kts:37` |
| Total LoC in `lib/` | 7057 across 16 dart files | `wc -l` |
| Largest file | `wallet_dashboard_page.dart` 1621 lines (single StatefulWidget with all tabs) | `lib/presentation/pages/wallet_dashboard_page.dart` |
| Empty domain/data layers | `data/sources/`, `data/repositories/`, `domain/{entities,repositories,usecases}/`, `core/errors/`, `presentation/routes/` — all empty (Clean-Architecture skeleton only) | `ls` |
| `.idea/`, `build/`, `coverage/`, `.dart_tool/` | not committed (`.gitignore` standard Flutter) | repo structure |

---

## A. Code quality

### A1. Lint rules / analyzer config — **Low**
`analysis_options.yaml` includes only `package:flutter_lints/flutter.yaml` (the default Flutter set). No stricter rules, no `errors:`, no per-package opt-ins. The same file's commented-out suggestions (`avoid_print: false`, `prefer_single_quotes: true`) confirm the linter is a one-line "include default" and nothing else (`analysis_options.yaml:1-29`).

Implication: the project will not flag, e.g., `unawaited` Futures, `print` calls, `omit_local_variable_types`, `avoid_dynamic_calls`, `cascade_invocations`, `prefer_const_constructors`, `sort_child_properties_last`, or any of the `flutter_lints` strict set beyond defaults. Given the volume of dynamic JSON handling in `compute_tx.dart`, a stricter set would catch issues.

### A2. Dead dependencies / version-drift risk — **Medium**
`pubspec.yaml` declares nine dependencies that the application source does not import anywhere in `lib/` (verified by full grep of `lib/`):

- `web_socket_channel` (declared, never used; `wsUrl` is computed but never connected to)
- `http`
- `web3dart`
- `wallet`
- `image_gallery_saver_plus`
- `local_auth` (despite `biometricTimeoutSeconds` constant and `storageKeyBiometricEnabled` key being present in `app_constants.dart:12, 24`)
- `flutter_riverpod` / `riverpod` (Provider is used)
- `cached_network_image` / `flutter_svg` / `shimmer`

Each of these pulls native code, increases APK size, and creates an attack surface (`local_auth` for instance would be appropriate here). Recommended: remove unused, or wire `local_auth` and `web_socket_channel` to make the empty-data-layer use of "live updates" and "biometric unlock" real.

### A3. State-management mixed-declaration — **Low**
Both `provider` and `flutter_riverpod` are pinned in `pubspec.yaml:14-16`. Only `provider` is actually used (the `MultiProvider` in `main.dart:36-37` and every `context.read<WalletProvider>()` in pages). `flutter_riverpod` is dead weight.

### A4. `print` vs `debugPrint` vs `AppLogger` — **Pass**
No `print(` call in `lib/` (grep returns no hits). `AppLogger` is a thin wrapper over `package:logger` (`lib/core/utils/logger.dart:1-51`) used consistently in `WalletProvider` error paths. However:

- `rpc_client.dart:23-33` registers a `LogInterceptor` that calls `AppLogger.debug(obj.toString())` on every RPC error. `obj` is whatever Dio passes; safe but verbose.
- The base `Dio` does not have request/response body logging enabled (`requestBody: false, responseBody: false` at lines 27-29) — good, otherwise signed transactions would land in logs.

### A5. `dynamic` / `as` casts — **Medium (cluster around JSON boundary)**
The signing / RPC layer is heavily `dynamic` because it round-trips JSON:

- `rpc_client.dart:38-69` `params: List<dynamic>?`, `'params': params ?? <dynamic>[]`, returns `Future<dynamic>` from `request()`.
- `rpc_client.dart:52-65` cascades of `as Map<String, dynamic>`, `as int?`, `as String?`. Unchecked by the analyzer.
- `compute_tx.dart:40, 47, 50, 58, 97-99, 132-154, 164, 166, 197, 425-481, 749-836` — dozens of `dynamic` parameters, `(value as String)`, and `as String` casts.
- `wallet_provider.dart:381` `if (payload is! Map)` and `Map<String, dynamic>.from(payload as Map)`.

The pattern is consistent and the code is reviewed, but an `Argon2id`-style narrow wrapper class with a real `fromJson` factory (e.g. via `json_serializable`, which is already in dev_dependencies) would catch field-name and type drift at compile time instead of in production.

### A6. `try/catch` in security-critical paths — **Medium**
A handful of `catch (_)` blocks silently swallow failures:

- `wallet_provider.dart:506-509` `_loadRpcOverrides` — bad JSON in `SharedPreferences` is silently ignored; subsequent RPCs target wrong network without the user knowing. Should at least log.
- `wallet_provider.dart:565-583` `_normalizeAccountAddress` — both try-catch branches swallow. If an account on disk has a malformed public key AND a malformed address, the code falls through with no diagnostic.
- `wallet_provider.dart:507` and `app_constants.dart:131-137` (`getById` with catch-all return null).
- `rpc_client.dart:100-107` `isConnected` swallows all errors and returns `false`; OK for connectivity probes but combined with `LogInterceptor` (line 23) every probe logs noise.

None of these are `private-key-discard` bugs, but the silent-failure pattern is the kind that turns into a "wallet silently using a different account than the user thinks" report six months later.

### A7. Comment density on crypto / signing — **Medium**
- `crypto_utils.dart` has zero doc comments on `_randomBytes`, `formatNativeAddressFromPublicKey`, `normalizeNativeAddress`, or the EIP-55-style checksum function `_formatNativeAddress` (lines 175-234). The checksum logic at lines 216-231 has no comment explaining "this is EIP-55-style capitalisation of a Keccak-256 of the lowercase hex." A reader cannot verify that the rule matches the spec without re-deriving it.
- `compute_tx.dart` has 836 lines of canonical encoding with only one short block comment per major function and a `// 32-byte hash` style fallback label (lines 671-677). The preimage rules are **load-bearing for cross-implementation compatibility**; right now the function is correct but the next person to "clean it up" has no breadcrumbs. A short reference to the parallel `Rabbit-Chain-node/crates/rabbitcore/src/compute/tx.rs` `signing_preimage` (or to `COMPUTE_JSON_SPEC.md`) at the top of `computeSigningPreimage` would be enough.
- `wallet_provider.dart` has no comment explaining why `_markCurrent` rebuilds the list (because `WalletAccount` is `Equatable` and only the list rebuild makes the `notifyListeners` dirty check fire correctly). Discoverable but not obvious.

### A8. Magic numbers / hardcoded strings — **Low**
- Chain ids hardcoded in `app_constants.dart:72, 86, 100, 116` (31337 / 10088 / 10087 / 10086). `decimals: 18` is hardcoded five times. PBKDF2 iterations hardcoded at line 19. Acceptable for a v1 single-tenant wallet, but should live in build config / server-fed values once a second chain shows up.
- `'RABBITCHAIN-COMPUTE-SIGNING-V1'` is hardcoded in `compute_tx.dart:161` and is the **most important** magic string in the codebase. There is no compile-time guarantee it equals the Rust constant. See B1.
- `RABBITCHAIN_ALIGNMENT.md` declares the wallet is on the "compute" path; the code matches. Good.

### A9. Concurrency primitives — **Pass, with notes**
- No `Isolate.spawn`. Crypto is `await ed.sign(...)` etc. Ed25519 sign on a 32-byte message is sub-millisecond; the main isolate is fine. (See C-section below.)
- All `TextEditingController`s are disposed correctly (`create_wallet_page.dart:24-30`, `import_wallet_page.dart:26-33`, `send_payment_page.dart:28-33`, `wallet_dashboard_page.dart:1285` for the dialog controller — wait, the dialog `TextEditingController` in `_showRpcUrlEditor` is **never disposed**; line 1279 creates it and 1305 exits without `controller.dispose()`. Low-severity leak inside a transient dialog but still a finding).
- `_passwordController` and `_dataController` carry the user's password / mnemonic in plain `String`s for the entire lifetime of the page. They are disposed in `dispose()`, but `String` is immutable; Dart's GC can hold them in heap until the next major GC, and they are also reachable through the `SelectableText` backup dialog at `create_wallet_page.dart:331-339` (the mnemonic sits in a `SelectableText` widget until "我已备份" is pressed). See B3 for the bigger picture.

### A10. `flutter_lints` / `flutter_lints` 6.0.0 version-drift — **Low**
`flutter_lints: ^6.0.0` is declared (`pubspec.yaml:53`) but the project is on Flutter SDK `^3.11.0`. Flutter 3.11 / Dart 3.11 is from Flutter 3.27 (Dec 2024) — the `flutter_lints` 6.x line is the matching one. OK, but there is no version-locked `dependency_overrides` and the `pubspec.lock` shows 39840 bytes of lockfile (read earlier) — reviewable but not in this audit.

### A11. Two parallel state-management options in the same `pubspec` — **Low**
(See A3.) Adds APK size and a maintenance question for new contributors.

---

## B. Protocol semantics

### B1. Signing preimage vs. Rabbit-Chain-node — **Pass (verified)**
Cross-checked field-by-field against `Rabbit-Chain-node/crates/rabbitcore/src/compute/tx.rs:190-240` (`ComputeTx::signing_preimage`) and the matching TypeScript in `rabbitchain-wallet-chrome/src/core/wallet/ComputeTx.ts:181-269`.

| Field | Rust (node) | Dart (mobile) | Chrome (TS) | Match? |
| --- | --- | --- | --- | --- |
| Domain tag | `RABBITCHAIN_COMPUTE_SIGNING_DOMAIN_V1 = b"RABBITCHAIN-COMPUTE-SIGNING-V1"` | `'RABBITCHAIN-COMPUTE-SIGNING-V1'` (line 161) | `'RABBITCHAIN-COMPUTE-SIGNING-V1'` (line 200) | Yes (literal ASCII 30 bytes) |
| `domain_id` | `u32` BE 4 bytes (line 194) | `u32` BE 4 bytes (line 163, helper at 640-646) | `u32` BE 4 bytes | Yes |
| `command` | 1 byte tag (Transfer=1..AgentTick=7, lines 270-279) | 1 byte tag (lines 441-460, identical enum order) | identical | Yes |
| `input_set` len | `u32` BE | `u32` BE (line 167) | `u32` BE | Yes |
| `input_set[i]` | raw 32 bytes | 32 raw bytes via `_fixedHexBytes` (line 169) | 32 raw bytes | Yes |
| `read_set` len | `u32` BE | `u32` BE (line 173) | `u32` BE | Yes |
| `read_set[i]` | `output_id` 32B + `domain_id` u32 BE + `expected_version` u64 BE | identical (lines 175-182) | identical | Yes |
| `output_proposals` len | `u32` BE | `u32` BE (line 185) | `u32` BE | Yes |
| `output_proposals[i]` | `output_id` 32B, `object_id` 32B, `domain_id` u32, `kind` 1B, owner, predecessor(opt), version u64, state, state_root(opt), resources, lock, logic(opt), created_at u64, ttl(opt) u64, rent_reserve(opt) u128, flags u32, extensions | identical (lines 188-246) | identical | Yes |
| Ownership tags | Address=1, Program=2, Shared=3, Ed25519=4 (lines 416-434) | 1/2/3/4 (lines 486-514) | identical | Yes |
| Owner payload (Address/Program) | 20 raw bytes | 20 raw bytes (lines 488-490, 496-498) | identical | Yes |
| Owner payload (Ed25519) | 32 raw bytes | 32 raw bytes (lines 504-512) | identical | Yes |
| Predecessor | 0/1 + 32 bytes | 0/1 + 32 bytes (lines 200-212) | identical | Yes |
| Version | u64 BE | u64 BE (line 214) | identical | Yes |
| State | u32-BE-len + bytes | `_encodeBytes` (u32 BE len + bytes) at lines 215, 595-598 | identical | Yes |
| `state_root` | 0/1 + 32 bytes | identical (lines 217-225) | identical | Yes |
| Resources | sorted by `asset_id` bytes ascending, then len + entries | sorted by `asset_id` bytes ascending (lines 519-532), then encoded | identical | Yes |
| Resource value tags | Amount=1 u128 BE, Data=2 len+bytes, Ref=3 +32B, RefBatch=4 len+32B[] | identical (lines 540-571) | identical | Yes |
| `lock` | `vm: u8` + `code: len+bytes` | identical (line 228 via `_encodeScript` lines 578-581) | identical | Yes |
| `logic` | 0/1 + script | identical (lines 230-239) | identical | Yes |
| `created_at` | u64 BE | u64 BE (line 241) | identical | Yes |
| `ttl` | 0/1 + u64 BE | identical (line 242) | identical | Yes |
| `rent_reserve` | 0/1 + u128 BE | identical (line 243) | identical | Yes |
| `flags` | u32 BE | u32 BE (line 244) | identical | Yes |
| `extensions` | u32-len + (key u32+bytes, value u32+bytes) | identical (line 245) | identical | Yes |
| `fee` | u64 BE | u64 BE (line 248) | identical | Yes |
| `nonce` | 0/1 + u64 BE | identical (line 249) | identical | Yes |
| `metadata` | u32-len + entries (u32+key bytes, u32+value bytes) | identical (line 250) | identical | Yes |
| `payload` | u32-len + bytes | identical (line 251) | identical | Yes |
| `deadline_unix_secs` | 0/1 + u64 BE | identical (line 252) | identical | Yes |
| `chain_id` | 0/1 + u64 BE | identical (line 253) | identical | Yes |
| `network_id` | 0/1 + u32 BE | identical (line 254) | identical | Yes |
| `witness.threshold` | u16 BE | u16 BE (line 255) | identical | Yes |
| tx_id | keccak256(preimage) | `KeccakDigest(256).process(preimage)` (line 261) | keccak256 | Yes |

**Conclusion:** the mobile signing preimage is **byte-for-byte identical** to the Rust node and the Chrome wallet. The chain/network binding fix in `bindComputeTxToNetwork` (`wallet_provider.dart:606-654`) enforces that any explicit `chain_id` / `network_id` in user-supplied JSON must match the active network, and the template otherwise fills them in. This was the 2026-05-28 W6/F-01 remediation; it has landed and is correct.

Two minor caveats:

- `compute_tx.dart:97` reads `threshold` with fallback 1. `buildUnsignedTransaction` (line 152) writes `threshold: 1` into the unsigned witness. After signing, the same threshold is written back to the signed `witness.threshold` (line 112). Consistent. Good.
- `_normalizeHexData` (line 703) strips duplicate `0x` prefixes (`0x0x0x` -> `0x`). This is friendly but means an attacker who can manipulate JSON input could pre-prefix `0x0x` and still produce a valid preimage. The hex bytes after normalisation are identical, so the signature still verifies — no exploit, just unidiomatic.

### B2. Address derivation — **Pass (with caveat)**
`CryptoUtils.deriveWalletFromPrivateKey` (`crypto_utils.dart:45-64`):
1. `hexToBytes` then length check for 32 bytes.
2. `Ed25519().newKeyPairFromSeed(bytes)` — correct ed25519-from-seed.
3. `extractPublicKey()` — 32 bytes.
4. Address = EIP-55-style Keccak-256 checksum of the last 20 bytes of the 32-byte hash of the public key (lines 182-189) — this matches the node's `format_native_address_from_public_key` semantics used elsewhere in the repo (verified: `KeccakDigest(256).process(publicKeyBytes).sublist(12)`).

`deriveWalletFromMnemonic` (lines 66-82):
- Validates with `bip39.validateMnemonic`.
- `bip39.mnemonicToSeed(mnemonic)` returns a 64-byte BIP39 seed.
- **Takes only the first 32 bytes** as the ed25519 seed (`seed.sublist(0, 32)`).

Caveat: this is **not** SLIP-0010. SLIP-0010 ed25519 derivation uses HMAC-SHA512 with key `ed25519 seed` over the BIP39 seed, and the resulting 32-byte "IL" half is the private key. Taking `seed[0..32]` here is a **non-standard derivation** that will not match any other BIP39→ed25519 wallet (Trust Wallet, Solflare, etc., all use SLIP-0010). For a single-wallet-app this is fine, but the moment the user imports a mnemonic that was generated by another tool, it will produce a different key — and the current import flow does not warn them. Add a doc comment in `createMnemonicWallet`/`deriveWalletFromMnemonic` that the derivation is custom, and surface a warning at import time if a known-good mnemonic from another tool is detected.

The Chrome wallet's `deriveWalletFromMnemonic` should be checked for parity; the Rust node presumably uses the same custom 32-byte prefix.

### B3. Mnemonic handling — **Medium (UI exposure)**
- Mnemonic generation: `bip39.generateMnemonic(strength: 128)` (12 words) — `crypto_utils.dart:89`. **Default for a v1 wallet is 128 bits = 12 words = ~132 bits of entropy.** This is *technically* the BIP39 minimum but the modern recommendation is 256 bits / 24 words for high-value wallets. Worth bumping to `strength: 256` before mainnet GA.
- Mnemonic flow: `createWallet` returns `MnemonicWalletData(mnemonic, wallet)` to the provider, which passes `generatedWallet.mnemonic` straight into `CreateWalletResult.backupValue` (`wallet_provider.dart:130, 169`). The backup dialog (`create_wallet_page.dart:331-339`) puts the mnemonic in a `SelectableText` widget.
  - `SelectableText` makes it copyable to the OS clipboard — a clipboard-sniffer or screen-recorder malware on Android can read it. There is no `FLAG_SECURE` call (no `MethodChannel` to `WindowManager.flagSecure` or equivalent). Recommendation: wrap the page in a `SystemChrome`-aware widget that triggers platform-specific screenshot prevention, or at least wrap the `SelectableText` in a tap-to-reveal so it isn't in the widget tree when not focused.
  - The "复制" button (`create_wallet_page.dart:344-368`) writes the mnemonic to the clipboard with no warning. The clipboard is then readable by any other app on Android 9 and below, and on Android 10+ via the IME / accessibility surfaces.
- Mnemonic is **never** logged, never sent to the network, and never written to `SharedPreferences` (only to `flutter_secure_storage` after encryption). Mnemonic as plaintext exists only in: (a) `generateMnemonic` return, (b) `CreateWalletResult.backupValue` field, (c) the `SelectableText` in the dialog. After the user dismisses the dialog, it lives in the `Widget` tree and is disposed with the route. So the on-device lifecycle is OK; the issue is the `SelectableText` exposure.

### B4. Keystore / secure storage — **Medium**
`WalletProvider` declares `final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();` (`wallet_provider.dart:31`) and uses it with default options:
- iOS: defaults to Keychain with first-unlock-this-device-only; sensible.
- Android: `flutter_secure_storage` 9.0.0 uses **EncryptedSharedPreferences** by default (AES-256-GCM with the Android Keystore-protected master key). It does **not** use StrongBox or Biometric-bound keys unless you pass `AndroidOptions(encryptedSharedPreferences: true, ...)` and a `KeyProtectionType`. For a wallet that holds key material sufficient to drain funds, you want:
  - `AndroidOptions(encryptedSharedPreferences: true, keyCipherAlgorithm: KeyCipherAlgorithm.RSA_OAEP, storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoAuth, resetOnError: true)` (current default actually OK on 9.0+).
  - **Plus** a biometric-gated unlock before the encrypted private-key blob is decrypted. The local_auth dependency is already in pubspec, unused. Wire it up: on launch, prompt biometric; only then load the encrypted private-key blob and prompt for the password to decrypt.
- iOS-side, set `IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device, accountName: ...)` explicitly. Default is `first_unlock` (no `this_device`) which means the item is also restored via iCloud Keychain, which is **not** what you want for a wallet key.

The `pbkdf2Iterations = 120000` constant (`app_constants.dart:19`) is in OWASP's "acceptable for SHA-256" range (OWASP recommends 600 000 for PBKDF2-HMAC-SHA256 as of 2023). **Bump to 600 000** to match the spec the Chrome wallet presumably uses (cross-check) and to match the rest of the field.

The encrypted payload format (`crypto_utils.dart:107-129`) stores salt, nonce, ciphertext, MAC separately and base64-encoded — sensible. JSON envelope `version: 1` is there. Forward-compatible. No finding.

### B5. Transaction serialization / canonicalisation — **Pass**
- `buildUnsignedTransaction` (`compute_tx.dart:127-155`) reconstructs a typed map with the right keys in the right order, then `computeSigningPreimage` walks it deterministically. The witness is reset to `{signatures: [], threshold}` and re-added with the real signature after signing (line 150-153, 108-124). Standard "sign over the unsigned body" pattern. Correct.
- Canonicalisation: resources sorted by `asset_id` byte-ascending (lines 343-353 and 519-532). Output proposals are **not** sorted — order is whatever the user put in JSON. This is consistent with the Rust node (`encode_output_proposals` walks in given order, lines 318-373), so it's correct, but it does mean a transaction can be serialized in two ways with different preimages if a user reorders the `output_proposals` array. This is by design (preserves user intent / parallel-creation safety) — but worth a comment in `defaultTemplate`.
- `varint` encoding: the format uses **fixed-width** unsigned ints (u16/u32/u64/u128) and **length-prefixed** bytes (u32 length + bytes). The Rust node uses the same scheme (`encode_len(out, ...) -> out.extend_from_slice(&(len as u32).to_be_bytes());`). The Dart `compute_tx.dart:640-646` `_appendU32` writes 4 bytes big-endian, the same way. **No varints anywhere.** Good — easier to cross-verify, no ambiguity.

### B6. RPC client: TLS pinning / cert validation / hostname verification / custom CA — **Medium**
`RabbitChainRpcClient` (`rpc_client.dart:1-118`) is a thin `Dio` wrapper:
- No `HttpClientAdapter` override.
- No `badCertificateCallback`.
- No certificate pinning, no `IOClient` with a custom `SecurityContext`.
- No hostname check beyond what `dart:io` / `package:dio` do by default (which is standard X.509 verification using the system trust store).

For a wallet whose worst-case UX is "user submits a tx to an attacker MITMing the bootnode", you want **certificate pinning** (or at least SPKI pin) for the mainnet RPC at `https://rpc.rabbitchain.wedevs.org`. The domain `wedevs.org` is a hosting vendor — if their wildcard cert or any intermediate is compromised, the wallet silently talks to a MITM. Pin the leaf or intermediate public key in code, with a build-time override for dev.

`isSupportedCustomRpcUri` (`wallet_provider.dart:14-27`) correctly restricts non-https to localhost / 127.0.0.1 / ::1 / 10.0.2.2 (the Android emulator alias). Good. But the function does **not** check for credentials in the URL — `https://attacker.com:foo@evil.com/` is accepted. Low risk, but `Uri.parse('https://user:pass@host/').userInfo.isNotEmpty` should be a rejection criterion.

### B7. Permission scope (Android manifest) — **Medium**
`android/app/src/main/AndroidManifest.xml:1-50`:
- `INTERNET` (line 2) — required, fine.
- `READ_MEDIA_IMAGES` (line 3) — this is the Android 13+ granular media permission. The wallet **does not** request it (no `permission_handler` calls in `lib/`, and `image_gallery_saver_plus` is dead). Either remove or wire it.
- `WRITE_EXTERNAL_STORAGE` (line 4) — `maxSdkVersion=28` (Android 9 and below only). After 28 it's a no-op, so this is correct but the corresponding use case (save QR to gallery via `image_gallery_saver_plus`) is dead code.
- **Missing** `CAMERA` (required for `mobile_scanner` QR scanning — yet the code at `scan_pay_page.dart:23-54` instantiates `MobileScanner(onDetect: ...)`). Without `android.permission.CAMERA`, the scanner will fail at runtime on real devices. This is a **functional bug** as well as a manifest finding.
- **Missing** `USE_BIOMETRIC` (for the unused `local_auth`).
- `usesCleartextTraffic="true"` (line 10) — needed for `http://127.0.0.1:8545` local devnet. For mainnet this is too permissive; the right pattern is a `network_security_config.xml` that allows cleartext **only** for `127.0.0.1`, `10.0.2.2`, and the devnet hosts. Without it, a malicious server can downgrade the user to HTTP in some scenarios and the app will accept it.
- `android:exported="true"` on `MainActivity` (line 13) — required for the launcher, no deep-link intent-filter so the exposure is limited to "system can launch it". No `rabbitchain://` / `wc://` / `ethereum://` / `pay:` filters, which is good (no deep-link attack surface). The `<queries>` block (lines 44-49) is the default Flutter text-processing query and is harmless.

### B8. Deep links / intent filters — **Pass**
No `android.intent.action.VIEW` filters. No custom URL scheme. The wallet cannot be launched from another app and cannot be hijacked via URI deeplink. Good — most wallet deep-link incidents of the past two years came from permissive `<data android:scheme="..."/>` filters; this wallet has none.

### B9. Clipboard leak — **Medium**
- `wallet_dashboard_page.dart:228-234` and `:989-996` copy the **address** to the clipboard with a snackbar confirmation. No auto-clear after N seconds. Android clipboard is readable by foreground apps. Acceptable for an address (it's a public identifier), but document the threat model.
- `create_wallet_page.dart:344-368` copies the **mnemonic** to the clipboard with a snackbar. **This is the high-risk path.** Combined with the missing `FLAG_SECURE`, an attacker with clipboard-access on Android 9- can steal the wallet at creation time. The button should at minimum (a) require a long-press confirmation, (b) auto-clear the clipboard after 30s, and (c) wrap the page in a platform screenshot-block.
- `send_payment_page.dart:302-308` copies the **RPC result** (a JSON blob containing the signed tx) — not security-critical, fine.

### B10. Screenshot prevention on sensitive screens — **High (missing)**
No `MethodChannel` call to `Window.setFlags(FLAG_SECURE, ...)` (Android) or `UIScreen.isCaptured` observer (iOS) anywhere in `lib/`. The mnemonic backup dialog, the import page where the user types a mnemonic, and the password fields are all screenshot-able and screen-record-able. Add platform-channel integration; on Android call `getWindow().setFlags(FLAG_SECURE, FLAG_SECURE)` when entering a sensitive route, clear it on exit.

### B11. RPC error message handling — **Low**
`RpcException` (line 110-118) carries the JSON-RPC `code` and `message`, and `mapRpcErrorMessage` (line 120-126) is a stub that just returns `defaultMessage` (it does not even read `code` or `method`). Either implement it (e.g. map `-32005` to "Insufficient funds") or delete the dead helper to avoid future cargo-culting.

### B12. Address validation — **Low**
`scan_pay_page.dart:107-109` validates scanned QR content with `^0x[a-fA-F0-9]{40}$` (correct 20-byte EIP-55-style hex). `crypto_utils.normalizeNativeAddress` (lines 192-208) does the same. Good. But `scan_pay_page.dart:99-105` `_normalizeAmountValue` accepts `^\d+(\.\d+)?$` and returns the raw string. There is no cap on decimals (could be `1.123456789012345678901234` and the wallet would happily pass it on). For the JSON-template flow this is OK because the user types the JSON directly; just note that the QR amount field trusts whatever the sender encoded.

### B13. Send-page JSON editing — **Medium (UX) / Low (security)**
`send_payment_page.dart:139-168` puts the full compute-transaction JSON in an editable `TextFormField`. The user can:
- Set `command: 'Burn'` on someone else's output by manipulating `output_proposals[0].owner.public_key` (the wallet will dutifully sign it because it has the matching key — this is by design, it's the user's key).
- But also: paste a JSON that has `output_proposals[0].owner.address` set to a 20-byte address they control, while `output_proposals[0].lock.code` is a script that drains a contract — the wallet signs whatever JSON the user pastes. This is fine for a power-user template flow, but the page should clearly state "you are signing arbitrary compute JSON" so a user doesn't get tricked into pasting a malicious JSON from a phishing site.

The validator (line 155-165) only checks "is it JSON, is it non-empty" — no shape validation, no key-set check. A `dart:convert` + `compute_tx.dart::_normalize*` round-trip before signing would catch malformed fields and surface a clear error.

### B14. `getPrivateKey` — **Medium**
`wallet_provider.dart:456-469` returns the **plaintext private key as a `String`** to the caller (`_runComputeTx` then passes it to `ComputeTx.signTransaction` at line 392-396, after which the variable goes out of scope). The `String` lives in heap for an unknown time. Same problem as B3: Dart `String` is immutable, no `Zerable`/`SecureString` API.

Mitigations (none in place):
- Wrap the key in a `TypedData` `Uint8List` zeroed after use.
- Or, refactor `ComputeTx.signTransaction` to take a callback `Future<Uint8List> resolvePrivateKey()` that decrypts inside the signing call so the key never leaves the closure.
- Same for `decryptData` in `crypto_utils.dart:131-148` — it returns the full `String` to the caller.

This is a structural finding across the codebase, not a single-line fix.

### B15. `keystore.jks` / `key.properties` not committed — **Pass**
`android/.gitignore:10-13` has the standard Flutter `*.keystore` ignore. No `key.properties`, no `keystore.jks` in the repo. Good. **But** `android/app/build.gradle.kts:34-38` falls back to the debug signing config for release builds. The current debug keystore is fine for dev but must be replaced with a real release key before publishing.

---

## C. Concurrency

### C1. Dart isolates vs threads — **Pass**
- No `Isolate.spawn` / `Isolate.run` / `compute()` in the entire `lib/` tree. (Verified by grep.)
- Ed25519 sign over a 32-byte preimage is sub-millisecond on modern hardware; even a heavy operation like PBKDF2 with 120 000 iterations of HMAC-SHA256 is on the order of 100-300 ms on a mid-range Android. The `await`-based flow in `CryptoUtils.encryptData` / `decryptData` blocks the UI isolate during this time. On a slow device this would freeze the button spinner for ~300 ms — annoying but not catastrophic.
- The `package:cryptography` implementation runs PBKDF2 on the platform thread (Dart's single main isolate). To free the UI thread, wrap the call in `await compute(CryptoUtils.encryptData, [data, password])` in a top-level static function. (Note: `compute` would also need a `SendPort` for the return value.) Same for `decryptData`. Not a security bug; a UX/responsiveness finding.

### C2. `Future` chains: missing `await`, fire-and-forget — **Medium**
- `home_page.dart:23-25` `WidgetsBinding.instance.addPostFrameCallback((_) { context.read<WalletProvider>().initialize(); });` — the `Future` from `initialize()` is **not awaited** and the lambda return is `void`. Equivalent pattern at `wallet_dashboard_page.dart:27-29` and `:339` (`provider.refreshBalance()` on tap) and `home_page.dart:329` (retry button). All of these are fire-and-forget: if the call throws synchronously *after* the post-frame callback, the error is silently dropped to the zone handler. The provider's own `try/catch/finally` (line 105-111) catches async errors, but only those that originate inside the function. If `notifyListeners` itself throws (e.g. a listener is in a bad state), the exception escapes the Future unhandled.
  - Pattern fix: `unawaited(Future.error(...))` is unhelpful here; the right fix is `() async { await context.read<WalletProvider>().initialize(); }` inside the post-frame callback so any throw surfaces.
- `scan_pay_page.dart:24-53` `onDetect` callback returns synchronously and calls `Navigator.pushReplacement` after `_handled = true`. The callback is invoked on a stream microtask; the `await Clipboard.setData` is not used here so no issue, but the `_handled` flag is set before the navigation completes — a second barcode scan could fire before navigation and set `_handled = true` for the new route, but since the state object is about to be disposed this is harmless. Still, a `bool _handled` flag with no `setState` will not rebuild; benign here because the entire widget is being torn down.

### C3. Streams / `StreamSubscription` lifecycle — **Medium**
- `mobile_scanner.MobileScanner` (`scan_pay_page.dart:23`) returns a `MobileScannerController` internally; the controller is disposed when the widget is removed (Flutter plugin handles this). No explicit `controller.dispose()` is needed for the embedded widget. Acceptable.
- No explicit `StreamSubscription` is stored in any state. No long-lived stream subscription. The Dio `LogInterceptor` is a request/response interceptor, not a stream. The `WalletProvider` does not subscribe to any `Stream`.
- However, `ChangeNotifier` is used (`wallet_provider.dart:30`). Every `Consumer<WalletProvider>` (`home_page.dart:32`, `wallet_dashboard_page.dart:34`, `create_wallet_page.dart:37`, `import_wallet_page.dart:40`, `send_payment_page.dart:37`) attaches a listener. Flutter's `Consumer` correctly tears down on `dispose`, so no leak there.

### C4. `Completer` misuse — **Pass**
No `Completer` in the codebase. No double-completion risk.

### C5. Stateful widget lifecycle: `dispose` cleaning controllers / streams / focus nodes — **Medium**
- `create_wallet_page.dart:24-30`, `import_wallet_page.dart:26-33`, `send_payment_page.dart:28-33` — all dispose their `TextEditingController`s. Good.
- `wallet_dashboard_page.dart:1278-1317` `_showRpcUrlEditor` creates a local `TextEditingController controller = TextEditingController(text: provider.currentRpcUrl);` and never calls `controller.dispose()`. The dialog is dismissed and the controller becomes garbage, but for a wallet-grade codebase the pattern of "always dispose what you allocate" matters. Low severity (transient dialog) but a finding.
- No `FocusNode`, `ScrollController`, or `AnimationController` is allocated anywhere in the project — clean.
- `WalletProvider` is a `ChangeNotifier` and is constructed once at the root (`main.dart:36-37`). It is never disposed. For a singleton root provider this is acceptable, but if the app ever introduces a route-scoped provider, the pattern would need adapting.

### C6. Async result races — **Medium**
- `wallet_provider.dart:419-454` `refreshBalance`: two callers (e.g. user taps "刷新" while the auto-refresh on dashboard load is still in flight) will both run a `getAccount` against the same `_rpcClient`. The second one writes `_currentBalance` and `notifyListeners` after the first, but there is no sequence number / `if (mounted) / abortable`. If the second call returns faster (e.g. a retry after a transient error), the UI can show a stale balance briefly. Not a security issue; a "show wrong number for 200ms" finding.
- `_runComputeTx` (`wallet_provider.dart:349-417`) is **not concurrency-guarded**. If the user double-taps "签名并提交" before the button is disabled (line 257 `onPressed: provider.isLoading ? null : _submitCompute`), both calls can enter `_runComputeTx`, both decrypt the key, both sign, and both submit. The `_isLoading = true` happens at line 365 *after* the password check at line 354, but the button is gated on `provider.isLoading` which the *previous* call set to `true` then `false` in `finally`. With a fast-enough device the user can race this. Recommended: guard with a `bool _computeInFlight` at the field level.
- `switchAccount` / `switchNetwork` (`wallet_provider.dart:254-293`): both are `await`-ed end-to-end, no early returns, no `mounted` check inside. If the user is mid-switch and the network is killed, `_isLoading` stays `true` forever (no `finally` clearing it). Not actually a finding — there's no `finally` setting `_isLoading = true` in the first place; the only path that sets it is the failed RPC in `refreshBalance` which does set `_error` but the UI keeps showing "loading" because `_isLoading` was never set. Low-severity: in error paths `provider.isLoading` may be a lie.

### C7. UI thread blocking — **Medium**
As noted in C1, PBKDF2 with 120 000 iterations blocks the UI isolate. The button spinner (line 222-232) hides the freeze but doesn't fix it. PBKDF2 should run in `compute()` (Dart's `compute` spawns an isolate). The fix is mechanical — extract a top-level `static Future<String> _encryptDataIsolated(String data, String password) => CryptoUtils.encryptData(data, password);` and call `compute(_encryptDataIsolated, ...)`.

For signing: ed25519 sign is fast enough not to bother. Keccak-256 over a ~500-byte preimage is <1 ms.

### C8. Background isolates: race on shared static state — **Pass**
- `CryptoUtils._cipher` and `CryptoUtils._pbkdf2` (`crypto_utils.dart:39-43`) are `static final` singletons. The `cryptography` package's `AesGcm` and `Pbkdf2` are documented as thread-safe and re-entrant; they are stateless wrappers around `package:cryptography`'s platform implementations. No finding.
- `_requestId` in `RabbitChainRpcClient` (`rpc_client.dart:10`) is an `int` incremented in `_nextId()`. Single-threaded Dart: no race.
- `WalletProvider` is mutated only on the main isolate (every async path is on the UI event loop). No race.

### C9. `WidgetsBinding` / lifecycle / async ordering — **Low**
- `home_page.dart:23-25` and `wallet_dashboard_page.dart:27-29` use `addPostFrameCallback` to call `initialize()` / `refreshBalance()`. This is the right pattern for "don't call `notifyListeners` during `build`." No issue.
- The `provider.isLoading` check at `_submitCompute` (`send_payment_page.dart:257`) reads the value at build time; if the user taps rapidly during a transition, the button is `null` only after the next `notifyListeners` rebuild. With Flutter's button debouncing this is fine; combined with C6's race, the analysis above still stands.

### C10. `compute` / `Isolate.spawn` / native threads — **Pass**
None used. All work on the main isolate. As noted, only PBKDF2 is a real candidate for offloading.

---

## Findings summary

| ID | Severity | Area | Title | Location |
| --- | --- | --- | --- | --- |
| F-01 | **High** | B10 | No screenshot / screen-record prevention on mnemonic backup, import, and password entry | `lib/presentation/pages/create_wallet_page.dart:331-339`; `import_wallet_page.dart:155-205`; `send_payment_page.dart:173-202` |
| F-02 | **High** | B4 | No biometric gate on the wallet unlock; `flutter_secure_storage` defaults used; no StrongBox / KeyStore-bound key | `wallet_provider.dart:31`; `pubspec.yaml:48` (dead `local_auth`) |
| F-03 | **High** | B7 | Missing `android.permission.CAMERA` — QR scanner will fail at runtime | `android/app/src/main/AndroidManifest.xml:1-7` |
| F-04 | **Medium** | A2 | 9 dead dependencies including `local_auth`, `web_socket_channel`, `image_gallery_saver_plus`, `web3dart` | `pubspec.yaml:18-48` |
| F-05 | **Medium** | A5 | Heavy `dynamic` / `as`-cast usage on JSON boundary; no schema generation despite `json_serializable` being declared | `compute_tx.dart` (many), `rpc_client.dart:38-69`, `wallet_provider.dart:381` |
| F-06 | **Medium** | A6 | Multiple `catch (_)` blocks silently swallow errors in account / RPC loading | `wallet_provider.dart:506-509, 565-583`; `app_constants.dart:131-137`; `rpc_client.dart:100-107` |
| F-07 | **Medium** | B3 | Mnemonic in `SelectableText` exposed to clipboard / screen capture; 128-bit (12-word) default entropy | `create_wallet_page.dart:331-368`; `crypto_utils.dart:89` |
| F-08 | **Medium** | B4 | PBKDF2 iterations = 120 000 (OWASP 2023 floor is 600 000 for SHA-256); iOS `KeychainAccessibility` left at default (iCloud-restorable) | `app_constants.dart:19`; `wallet_provider.dart:31` |
| F-09 | **Medium** | B6 | No TLS pinning on the mainnet RPC `rpc.rabbitchain.wedevs.org`; `isSupportedCustomRpcUri` does not reject URLs with embedded `user:pass@` | `rpc_client.dart:1-118`; `wallet_provider.dart:14-27` |
| F-10 | **Medium** | B9 | Mnemonic copy-to-clipboard with no auto-clear and no confirmation | `create_wallet_page.dart:344-368` |
| F-11 | **Medium** | B14 | Plaintext private-key `String` held in heap after decrypt; no zeroable buffer | `wallet_provider.dart:456-469`; `crypto_utils.dart:131-148` |
| F-12 | **Medium** | B2 | Mnemonic→ed25519 derivation is `seed[0..32]`, **not** SLIP-0010; users importing a mnemonic from another tool will get a different key with no warning | `crypto_utils.dart:74-82` |
| F-13 | **Medium** | C6 | `refreshBalance` and `_runComputeTx` not concurrency-guarded; double-tap submit can fire two signatures | `wallet_provider.dart:349-417, 419-454` |
| F-14 | **Medium** | C2 | Fire-and-forget `initialize()` / `refreshBalance()` in `addPostFrameCallback`; errors after `notifyListeners` are unhandled | `home_page.dart:23-25, 329`; `wallet_dashboard_page.dart:27-29, 339` |
| F-15 | **Medium** | C7 | PBKDF2 blocks the main isolate for ~100-300 ms; should run in `compute()` | `crypto_utils.dart:107-148` |
| F-16 | **Medium** | B13 | Send page accepts arbitrary JSON to sign with no shape validation; only `jsonDecode` + non-empty check | `send_payment_page.dart:155-168, 380` |
| F-17 | **Medium** | B7 | `usesCleartextTraffic="true"` in manifest without a `network_security_config.xml` allowing cleartext only for `127.0.0.1` / `10.0.2.2` / devnet | `android/app/src/main/AndroidManifest.xml:10` |
| F-18 | **Low** | A1 | `analysis_options.yaml` only enables default `flutter_lints`; no `errors:`, no stricter set | `analysis_options.yaml:1-29` |
| F-19 | **Low** | A3 | `provider` and `flutter_riverpod` both declared; only `provider` used | `pubspec.yaml:14-16` |
| F-20 | **Low** | A7 | Crypto / signing code has minimal comments; the canonical-encoding rules are not cross-referenced to the Rust node spec | `compute_tx.dart:127-258`; `crypto_utils.dart:175-234` |
| F-21 | **Low** | A8 | Magic numbers (chain ids, decimals, `RABBITCHAIN-COMPUTE-SIGNING-V1`) hardcoded | `app_constants.dart:72, 86, 100, 116`; `compute_tx.dart:161` |
| F-22 | **Low** | C5 | `_showRpcUrlEditor` dialog creates a `TextEditingController` and never disposes it | `wallet_dashboard_page.dart:1278-1317` |
| F-23 | **Low** | B11 | `mapRpcErrorMessage` is a dead stub that ignores `code` and `method` | `rpc_client.dart:120-126` |
| F-24 | **Low** | B15 | Release builds signed with the debug keystore (placeholder) | `android/app/build.gradle.kts:34-38` |
| F-25 | **Low** | C9 | `_isLoading` not gated in `switchAccount` / `switchNetwork` error paths; UI can be stuck on "loading" | `wallet_provider.dart:254-293` |
| F-26 | **Low** | B12 | QR amount field accepts unbounded decimals / no cap | `scan_pay_page.dart:99-105` |

**Counts:**
- Critical: 0
- High: 3
- Medium: 14
- Low: 9
- Total: **26 findings**

**Top 3 (must-fix before any real-money usage):**

1. **F-01 — Screenshot prevention is missing on every sensitive screen.** Mnemonic backup, mnemonic import, and password entry can all be captured by Android screen recorders and other apps. Add a platform channel that calls `Window.setFlags(FLAG_SECURE, FLAG_SECURE)` on the sensitive routes.
2. **F-02 — No biometric gate + insecure secure-storage defaults.** The wallet holds a key that drains funds; the encrypted private-key blob is gated only by an 8-character password (validation at `create_wallet_page.dart:165-168` enforces `length >= 8`, no complexity). Add `local_auth` biometric prompt before reading from `flutter_secure_storage`, and tighten `IOSOptions.accessibility` to `first_unlock_this_device` (no iCloud).
3. **F-03 — QR scanner will not work.** `android.permission.CAMERA` is missing from the main manifest, but `scan_pay_page.dart:23-54` instantiates `MobileScanner` and presents a scanner. The `Scan to Pay` flow is non-functional on real devices. Either remove the page (and the `mobile_scanner` dep) or add the permission.

**Signing-preimage conclusion (the critical cross-implementation check):** the mobile wallet's `ComputeTx.computeSigningPreimage` produces a preimage **byte-identical** to `Rabbit-Chain-node/crates/rabbitcore/src/compute/tx.rs::ComputeTx::signing_preimage` and `rabbitchain-wallet-chrome/src/core/wallet/ComputeTx.ts::computeSigningPreimage`. The cross-implementation risk that motivated the 2026-05-28 audit (W6 / F-01) is closed. The 2026-05-28 audit's other open item, X2 (dependency audit), remains relevant — see F-04.

---

## Recommendations (next sprint)

1. Wire `local_auth` for biometric unlock (F-02).
2. Add a `network_security_config.xml` to scope `usesCleartextTraffic` (F-17) and add TLS pinning for mainnet (F-09).
3. Strip dead deps (F-04) and turn on a stricter lint set in `analysis_options.yaml` (F-18).
4. Move PBKDF2 / ed25519 sign into `compute()` for non-blocking UI (F-15, C7).
5. Replace `String` private-key handling with `Uint8List` zeroable buffers (F-11).
6. Add `FLAG_SECURE` platform channel (F-01) and clipboard auto-clear (F-10).
7. Concurrency-guard `refreshBalance` and `_runComputeTx` (F-13).
8. Bump PBKDF2 iterations to 600 000 and 12-word→24-word mnemonic default (F-07, F-08).
9. Document the custom 32-byte-prefix derivation and warn at import if the mnemonic is valid BIP39 but doesn't match the on-chain address (F-12).
10. Release-signing config and remove `flutter` debug key (F-24).

---

## Tooling caveat

`dart` and `flutter` are not installed in this audit sandbox (the bash permission denial confirms this). A re-run of `dart analyze` and `flutter --version` in a Flutter-equipped environment is recommended to capture the exact warning/error count and version string. The analysis here is based purely on static review of the source, manifests, and gradle files; the findings list would gain concrete analyzer numbers (e.g. "47 lint warnings, 3 of which are `unawaited_futures`") if those tools were available.

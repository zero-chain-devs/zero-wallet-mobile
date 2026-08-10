import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/digests/keccak.dart';

import '../../data/models/wallet_models.dart';
import '../constants/app_constants.dart';

class DerivedWalletData {
  final String privateKey;
  final String publicKey;
  final String address;
  final SignatureScheme signatureScheme;

  const DerivedWalletData({
    required this.privateKey,
    required this.publicKey,
    required this.address,
    required this.signatureScheme,
  });
}

class MnemonicWalletData {
  final String mnemonic;
  final DerivedWalletData wallet;

  const MnemonicWalletData({required this.mnemonic, required this.wallet});
}

class CryptoUtils {
  CryptoUtils._();

  static const String nativeAddressPrefix = '0x';

  static final Cipher _cipher = AesGcm.with256bits();
  static final Pbkdf2 _pbkdf2 = Pbkdf2.hmacSha256(
    iterations: AppConstants.pbkdf2Iterations,
    bits: 256,
  );

  static Future<DerivedWalletData> deriveWalletFromPrivateKey(
    String privateKey,
  ) async {
    final bytes = hexToBytes(privateKey);
    if (bytes.length != 32) {
      throw ArgumentError('Private key must be 32 bytes');
    }

    final ed = Ed25519();
    final keyPair = await ed.newKeyPairFromSeed(bytes);
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBytes = Uint8List.fromList(publicKey.bytes);

    return DerivedWalletData(
      privateKey: hex.encode(bytes),
      publicKey: hex.encode(publicKeyBytes),
      address: formatNativeAddressFromPublicKey(hex.encode(publicKeyBytes)),
      signatureScheme: SignatureScheme.ed25519,
    );
  }

  static Future<DerivedWalletData> deriveWalletFromMnemonic(
    String mnemonic,
  ) async {
    final normalizedMnemonic = normalizeMnemonic(mnemonic);
    if (!bip39.validateMnemonic(normalizedMnemonic)) {
      throw ArgumentError('Invalid mnemonic');
    }

    final seed = bip39.mnemonicToSeed(normalizedMnemonic);
    if (seed.length < 32) {
      throw StateError('Mnemonic seed is too short');
    }

    return deriveWalletFromPrivateKey(
      bytesToHex(Uint8List.fromList(seed.sublist(0, 32))),
    );
  }

  static Future<DerivedWalletData> createNativeWallet() async {
    return deriveWalletFromPrivateKey(bytesToHex(_randomBytes(32)));
  }

  static Future<MnemonicWalletData> createMnemonicWallet() async {
    final mnemonic = bip39.generateMnemonic(strength: 128);
    final wallet = await deriveWalletFromMnemonic(mnemonic);
    return MnemonicWalletData(mnemonic: mnemonic, wallet: wallet);
  }

  static String normalizeMnemonic(String mnemonic) {
    return mnemonic
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .join(' ');
  }

  static bool isValidMnemonic(String mnemonic) {
    return bip39.validateMnemonic(normalizeMnemonic(mnemonic));
  }

  static Future<String> encryptData(String data, String password) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final secretBox = await _cipher.encrypt(
      utf8.encode(data),
      secretKey: secretKey,
      nonce: nonce,
    );

    return jsonEncode({
      'version': 1,
      'kdf': 'pbkdf2-sha256',
      'iterations': AppConstants.pbkdf2Iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    });
  }

  static Future<String> decryptData(String encrypted, String password) async {
    final payload = jsonDecode(encrypted) as Map<String, dynamic>;
    final salt = base64Decode(payload['salt'] as String);
    final nonce = base64Decode(payload['nonce'] as String);
    final cipherText = base64Decode(payload['cipherText'] as String);
    final macBytes = base64Decode(payload['mac'] as String);
    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    final clearText = await _cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
      secretKey: secretKey,
    );

    return utf8.decode(clearText);
  }

  static String normalizeHex(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Hex value is empty');
    }
    return trimmed.startsWith('0x') ? trimmed : '0x$trimmed';
  }

  static String stripHexPrefix(String value) {
    return value.startsWith('0x') ? value.substring(2) : value;
  }

  static Uint8List hexToBytes(String value) {
    final normalized = stripHexPrefix(value);
    if (normalized.length.isOdd) {
      throw ArgumentError('Hex value must have even length');
    }
    return Uint8List.fromList(hex.decode(normalized));
  }

  static String bytesToHex(Uint8List bytes, {bool include0x = false}) {
    final encoded = hex.encode(bytes);
    return include0x ? '0x$encoded' : encoded;
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static String formatNativeAddressFromPublicKey(String publicKeyHex) {
    final publicKeyBytes = hexToBytes(publicKeyHex);
    if (publicKeyBytes.length != 32) {
      throw ArgumentError('Native public key must be 32 bytes');
    }
    final digest = KeccakDigest(256).process(publicKeyBytes);
    final addressRaw = digest.sublist(digest.length - 20);
    return _formatNativeAddress(addressRaw);
  }

  /// RabbitChain address checksum (matches chain-core `format_rabbit_address`).
  ///
  /// Takes a 42-char address string (`0x` + 40 hex digits), normalizes the
  /// body to lowercase, applies the keccak256 nibble-based checksum, and
  /// returns the canonical form.
  ///
  /// This is deliberately different from EIP-55 (which checksums the original
  /// mixed-case address).  RabbitChain checksums the **lowercase** body.
  static String rabbitChecksumAddress(String address) {
    final normalized = normalizeNativeAddress(address);
    return normalized;
  }

  /// Check whether [address] is a well-formed RabbitChain address
  /// (`0x` prefix + 40 hex-digit body).  Does not verify checksum correctness.
  static bool isValidRabbitAddress(String address) {
    final trimmed = address.trim();
    if (!trimmed.startsWith(nativeAddressPrefix)) return false;
    final body = trimmed.substring(nativeAddressPrefix.length);
    return RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(body);
  }

  static String normalizeNativeAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Native address is empty');
    }

    final body = trimmed.startsWith(nativeAddressPrefix)
        ? trimmed.substring(nativeAddressPrefix.length)
        : trimmed;

    if (!RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(body)) {
      throw ArgumentError('Native address body must be 20-byte hex');
    }

    final bytes = Uint8List.fromList(hex.decode(body));
    return _formatNativeAddress(bytes);
  }

  static String _formatNativeAddress(List<int> rawAddress) {
    if (rawAddress.length != 20) {
      throw ArgumentError('Native address body must be 20 bytes');
    }

    final lowerHex = hex.encode(rawAddress);
    final hash = KeccakDigest(
      256,
    ).process(Uint8List.fromList(utf8.encode(lowerHex)));

    final checksummed = StringBuffer();
    for (var i = 0; i < lowerHex.length; i++) {
      final ch = lowerHex.codeUnitAt(i);
      final hashByte = hash[i ~/ 2];
      final nibble = i.isEven ? (hashByte >> 4) & 0x0f : hashByte & 0x0f;
      final isHexLetter = ch >= 0x61 && ch <= 0x66;
      if (isHexLetter && nibble >= 8) {
        checksummed.writeCharCode(ch - 32);
      } else {
        checksummed.writeCharCode(ch);
      }
    }

    return '$nativeAddressPrefix$checksummed';
  }
}

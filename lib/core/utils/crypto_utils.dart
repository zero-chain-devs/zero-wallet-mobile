import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/digests/keccak.dart';
import 'package:wallet/wallet.dart' as wallet;

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

class CryptoUtils {
  CryptoUtils._();

  static final Cipher _cipher = AesGcm.with256bits();
  static final Pbkdf2 _pbkdf2 = Pbkdf2.hmacSha256(
    iterations: AppConstants.pbkdf2Iterations,
    bits: 256,
  );

  static String generateMnemonic({int wordCount = 12}) {
    final strength = switch (wordCount) {
      12 => 128,
      15 => 160,
      18 => 192,
      21 => 224,
      24 => 256,
      _ => throw ArgumentError('Unsupported mnemonic length: $wordCount'),
    };

    return bip39.generateMnemonic(strength: strength);
  }

  static bool validateMnemonic(String mnemonic) {
    return bip39.validateMnemonic(_normalizeMnemonic(mnemonic));
  }

  static Future<DerivedWalletData> deriveWalletFromMnemonic(
    String mnemonic, {
    String derivationPath = AppConstants.defaultDerivationPath,
    SignatureScheme signatureScheme = SignatureScheme.secp256k1,
  }) async {
    final normalizedMnemonic = _normalizeMnemonic(mnemonic);
    if (!bip39.validateMnemonic(normalizedMnemonic)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }

    if (signatureScheme != SignatureScheme.secp256k1) {
      throw UnsupportedError(
        'Native ed25519 wallet should use raw private key backup, not mnemonic derivation',
      );
    }

    final seed = bip39.mnemonicToSeed(normalizedMnemonic, passphrase: '');
    final master = wallet.ExtendedPrivateKey.master(seed, wallet.xprv);
    final derived = master.forPath(derivationPath);
    if (derived is! wallet.ExtendedPrivateKey) {
      throw StateError('Unable to derive extended private key');
    }

    final privateKey = wallet.PrivateKey(derived.key);
    final publicKey = wallet.ethereum.createPublicKey(privateKey);
    final privateKeyBytes = _bigIntTo32Bytes(derived.key);

    return DerivedWalletData(
      privateKey: hex.encode(privateKeyBytes),
      publicKey: hex.encode(publicKey.value),
      address: wallet.ethereum.createAddress(publicKey),
      signatureScheme: SignatureScheme.secp256k1,
    );
  }

  static Future<DerivedWalletData> deriveWalletFromPrivateKey(
    String privateKey, {
    required SignatureScheme signatureScheme,
  }) async {
    final bytes = hexToBytes(privateKey);
    if (bytes.length != 32) {
      throw ArgumentError('Private key must be 32 bytes');
    }

    switch (signatureScheme) {
      case SignatureScheme.secp256k1:
        final key = wallet.ethereum.createPrivateKey(bytes);
        final publicKey = wallet.ethereum.createPublicKey(key);
        return DerivedWalletData(
          privateKey: hex.encode(bytes),
          publicKey: hex.encode(publicKey.value),
          address: wallet.ethereum.createAddress(publicKey),
          signatureScheme: SignatureScheme.secp256k1,
        );
      case SignatureScheme.ed25519:
        final ed = Ed25519();
        final keyPair = await ed.newKeyPairFromSeed(bytes);
        final publicKey = await keyPair.extractPublicKey();
        final publicKeyBytes = Uint8List.fromList(publicKey.bytes);
        final digest = KeccakDigest(256).process(publicKeyBytes);
        final addressRaw = digest.sublist(digest.length - 20);
        return DerivedWalletData(
          privateKey: hex.encode(bytes),
          publicKey: hex.encode(publicKeyBytes),
          address: 'native1${hex.encode(addressRaw)}',
          signatureScheme: SignatureScheme.ed25519,
        );
    }
  }

  static Future<DerivedWalletData> createNativeWallet() async {
    return deriveWalletFromPrivateKey(
      bytesToHex(_randomBytes(32)),
      signatureScheme: SignatureScheme.ed25519,
    );
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

  static Uint8List _bigIntTo32Bytes(BigInt value) {
    final normalized = value.toRadixString(16).padLeft(64, '0');
    return Uint8List.fromList(
      List<int>.generate(
        32,
        (index) => int.parse(
          normalized.substring(index * 2, index * 2 + 2),
          radix: 16,
        ),
      ),
    );
  }

  static String _normalizeMnemonic(String mnemonic) {
    return mnemonic.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');
  }
}

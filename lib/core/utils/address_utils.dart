import 'dart:typed_data';

import 'package:pointycastle/digests/keccak.dart';

const _nativeAddressPrefix = '0x';
const _addressBodyPattern = r'^[a-f0-9]{40}$';

/// RabbitChain address checksum.
///
/// Algorithm (different from EIP-55):
/// 1. Take the 40-char lowercase hex body (without 0x prefix)
/// 2. Compute keccak256(lower_hex_body) → 32 bytes
/// 3. For each hex char at index i (0-based):
///    - hashByte = hash[i >> 1]
///    - nibble = i even ? (hashByte >> 4) : (hashByte & 0x0f)
///    - if nibble >= 8 and the char is a-f, uppercase it
/// 4. Return "0x" + checksummed body
String rabbitChecksumAddress(String address) {
  final trimmed = address.trim();
  final body = trimmed.startsWith(_nativeAddressPrefix)
      ? trimmed.substring(2)
      : trimmed;
  final lowerBody = body.toLowerCase();

  if (lowerBody.length != 40 || !RegExp(_addressBodyPattern).hasMatch(lowerBody)) {
    throw ArgumentError('Invalid RabbitChain address: $address');
  }

  final hash = KeccakDigest(256).process(
    Uint8List.fromList(lowerBody.codeUnits),
  );

  final checksummed = StringBuffer();
  for (var i = 0; i < lowerBody.length; i++) {
    final ch = lowerBody.codeUnitAt(i);
    final hashByte = hash[i >> 1];
    final nibble = (i & 1) == 0 ? (hashByte >> 4) & 0x0f : hashByte & 0x0f;
    final isHexLetter = ch >= 0x61 && ch <= 0x66;
    if (isHexLetter && nibble >= 8) {
      checksummed.writeCharCode(ch - 32);
    } else {
      checksummed.writeCharCode(ch);
    }
  }

  return '$_nativeAddressPrefix$checksummed';
}

/// Check whether [address] is a well-formed RabbitChain address
/// (`0x` prefix + 40 hex-digit body). Does not verify checksum correctness.
bool isValidRabbitAddress(String address) {
  final trimmed = address.trim();
  if (!trimmed.startsWith(_nativeAddressPrefix)) return false;
  final body = trimmed.substring(2);
  return RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(body);
}

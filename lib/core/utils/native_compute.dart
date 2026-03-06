import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/digests/keccak.dart';

import 'crypto_utils.dart';

class NativeCompute {
  NativeCompute._();

  static const List<String> commands = <String>[
    'Transfer',
    'Invoke',
    'Mint',
    'Burn',
    'Anchor',
    'Reveal',
    'AgentTick',
  ];

  static const List<String> objectKinds = <String>[
    'Asset',
    'Code',
    'State',
    'Capability',
    'Agent',
    'Anchor',
    'Ticket',
  ];

  static Map<String, dynamic> defaultTemplate({
    required String publicKey,
    required int chainId,
    required int networkId,
  }) {
    return <String, dynamic>{
      'domain_id': 0,
      'command': 'Mint',
      'input_set': <String>[],
      'read_set': <Map<String, dynamic>>[],
      'output_proposals': <Map<String, dynamic>>[
        <String, dynamic>{
          'output_id': randomHash32(),
          'object_id': randomHash32(),
          'domain_id': 0,
          'kind': 'State',
          'owner': <String, dynamic>{
            'type': 'NativeEd25519',
            'public_key': publicKey.isEmpty ? '0x${'00' * 32}' : publicKey,
          },
          'predecessor': null,
          'version': 1,
          'state': '0x01',
          'logic': null,
        },
      ],
      'payload': '0x',
      'deadline_unix_secs': null,
      'chain_id': chainId,
      'network_id': networkId,
      'threshold': 1,
    };
  }

  static String prettyTemplate({
    required String publicKey,
    required int chainId,
    required int networkId,
  }) {
    return const JsonEncoder.withIndent('  ').convert(
      defaultTemplate(
        publicKey: publicKey,
        chainId: chainId,
        networkId: networkId,
      ),
    );
  }

  static Future<Map<String, dynamic>> signTransaction({
    required Map<String, dynamic> input,
    required String privateKeyHex,
    required String publicKeyHex,
  }) async {
    final threshold = _readInt(input['threshold'], fallback: 1);
    final unsigned = buildUnsignedTransaction(input, threshold: threshold);
    final preimage = computeSigningPreimage(unsigned);
    final txId = computeTxId(preimage);

    final ed = Ed25519();
    final keyPair = await ed.newKeyPairFromSeed(
      CryptoUtils.hexToBytes(privateKeyHex),
    );
    final signature = await ed.sign(preimage, keyPair: keyPair);

    return <String, dynamic>{
      ...unsigned,
      'tx_id': txId,
      'witness': <String, dynamic>{
        'threshold': threshold,
        'signatures': <Map<String, dynamic>>[
          <String, dynamic>{
            'scheme': 'ed25519',
            'signature': CryptoUtils.bytesToHex(
              Uint8List.fromList(signature.bytes),
              include0x: true,
            ),
            'public_key': _normalizeHexData(publicKeyHex),
          },
        ],
      },
    };
  }

  static Map<String, dynamic> buildUnsignedTransaction(
    Map<String, dynamic> input, {
    required int threshold,
  }) {
    return <String, dynamic>{
      'domain_id': _readInt(input['domain_id']),
      'command': _normalizeCommand(input['command']),
      'input_set': _asList(
        input['input_set'],
      ).map((item) => _normalizeHash32(item.toString())).toList(),
      'read_set': _asList(
        input['read_set'],
      ).map((item) => _normalizeReadRef(_asMap(item))).toList(),
      'output_proposals': _asList(
        input['output_proposals'],
      ).map((item) => _normalizeOutputProposal(_asMap(item))).toList(),
      'payload': _normalizeHexData(input['payload']?.toString() ?? '0x'),
      'deadline_unix_secs': _readNullableInt(input['deadline_unix_secs']),
      'chain_id': _readNullableInt(input['chain_id']),
      'network_id': _readNullableInt(input['network_id']),
      'witness': <String, dynamic>{
        'signatures': <Map<String, dynamic>>[],
        'threshold': threshold,
      },
    };
  }

  static Uint8List computeSigningPreimage(Map<String, dynamic> tx) {
    final out = <int>[];
    _appendBytes(
      out,
      Uint8List.fromList(utf8.encode('ZEROCHAIN-COMPUTE-SIGNING-V1')),
    );
    _appendU32(out, _readInt(tx['domain_id']));
    out.add(_commandTag(tx['command'] as String));

    final inputSet = _asList(tx['input_set']);
    _appendU32(out, inputSet.length);
    for (final input in inputSet) {
      _appendBytes(out, _fixedHexBytes(input.toString(), 32, '32-byte hash'));
    }

    final readSet = _asList(tx['read_set']);
    _appendU32(out, readSet.length);
    for (final read in readSet) {
      final item = _asMap(read);
      _appendBytes(
        out,
        _fixedHexBytes(item['output_id'].toString(), 32, '32-byte hash'),
      );
      _appendU32(out, _readInt(item['domain_id']));
      _appendU64(out, _readInt(item['expected_version']));
    }

    final outputProposals = _asList(tx['output_proposals']);
    _appendU32(out, outputProposals.length);
    for (final proposalValue in outputProposals) {
      final proposal = _asMap(proposalValue);
      _appendBytes(
        out,
        _fixedHexBytes(proposal['output_id'].toString(), 32, '32-byte hash'),
      );
      _appendBytes(
        out,
        _fixedHexBytes(proposal['object_id'].toString(), 32, '32-byte hash'),
      );
      _appendU32(out, _readInt(proposal['domain_id']));
      out.add(_objectKindTag(proposal['kind'] as String));
      _encodeOwnership(
        out,
        proposal['owner'] as Map<String, dynamic>? ??
            <String, dynamic>{'type': 'Shared'},
      );

      if (proposal['predecessor'] != null) {
        out.add(1);
        _appendBytes(
          out,
          _fixedHexBytes(
            proposal['predecessor'].toString(),
            32,
            '32-byte hash',
          ),
        );
      } else {
        out.add(0);
      }

      _appendU64(out, _readInt(proposal['version']));
      _encodeBytes(out, _hexToBytes(proposal['state']?.toString() ?? '0x'));

      if (proposal['logic'] != null) {
        out.add(1);
        _encodeBytes(out, _hexToBytes(proposal['logic'].toString()));
      } else {
        out.add(0);
      }
    }

    _encodeBytes(out, _hexToBytes(tx['payload']?.toString() ?? '0x'));
    _encodeOptionalU64(out, _readNullableInt(tx['deadline_unix_secs']));
    _encodeOptionalU64(out, _readNullableInt(tx['chain_id']));
    _encodeOptionalU32(out, _readNullableInt(tx['network_id']));
    _appendU16(out, _readInt(_asMap(tx['witness'])['threshold'], fallback: 1));

    return Uint8List.fromList(out);
  }

  static String computeTxId(Uint8List preimage) {
    final digest = KeccakDigest(256).process(preimage);
    return _normalizeHash32(CryptoUtils.bytesToHex(digest, include0x: true));
  }

  static String randomHash32() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    return CryptoUtils.bytesToHex(bytes, include0x: true);
  }

  static Map<String, dynamic> _normalizeReadRef(Map<String, dynamic> item) {
    return <String, dynamic>{
      'output_id': _normalizeHash32(item['output_id'].toString()),
      'domain_id': _readInt(item['domain_id']),
      'expected_version': _readInt(item['expected_version']),
    };
  }

  static Map<String, dynamic> _normalizeOutputProposal(
    Map<String, dynamic> item,
  ) {
    final predecessorRaw = item['predecessor'];
    final logicRaw = item['logic'];
    return <String, dynamic>{
      'output_id': _normalizeHash32(item['output_id'].toString()),
      'object_id': _normalizeHash32(item['object_id'].toString()),
      'domain_id': _readInt(item['domain_id']),
      'kind': _normalizeObjectKind(item['kind']),
      'owner': _normalizeOwner(item['owner']),
      'predecessor':
          predecessorRaw == null || predecessorRaw.toString().trim().isEmpty
          ? null
          : _normalizeHash32(predecessorRaw.toString()),
      'version': _readInt(item['version']),
      'state': _normalizeHexData(item['state']?.toString() ?? '0x'),
      'logic': logicRaw == null || logicRaw.toString().trim().isEmpty
          ? null
          : _normalizeHexData(logicRaw.toString()),
    };
  }

  static Map<String, dynamic>? _normalizeOwner(dynamic value) {
    if (value == null) {
      return null;
    }

    final owner = _asMap(value);
    final type = owner['type']?.toString() ?? 'Shared';
    switch (type) {
      case 'Shared':
        return <String, dynamic>{'type': 'Shared'};
      case 'Address':
      case 'Program':
        return <String, dynamic>{
          'type': type,
          'address': _normalizeAddress20(owner['address'].toString()),
        };
      case 'NativeEd25519':
        return <String, dynamic>{
          'type': type,
          'public_key': _normalizePublicKey32(owner['public_key'].toString()),
        };
      default:
        throw ArgumentError('Unsupported owner type: $type');
    }
  }

  static String _normalizeCommand(dynamic value) {
    final command = value?.toString() ?? '';
    if (!commands.contains(command)) {
      throw ArgumentError('Unsupported command: $command');
    }
    return command;
  }

  static String _normalizeObjectKind(dynamic value) {
    final kind = value?.toString() ?? '';
    if (!objectKinds.contains(kind)) {
      throw ArgumentError('Unsupported object kind: $kind');
    }
    return kind;
  }

  static int _commandTag(String command) {
    switch (command) {
      case 'Transfer':
        return 1;
      case 'Invoke':
        return 2;
      case 'Mint':
        return 3;
      case 'Burn':
        return 4;
      case 'Anchor':
        return 5;
      case 'Reveal':
        return 6;
      case 'AgentTick':
        return 7;
      default:
        throw ArgumentError('Unsupported command: $command');
    }
  }

  static int _objectKindTag(String kind) {
    switch (kind) {
      case 'Asset':
        return 1;
      case 'Code':
        return 2;
      case 'State':
        return 3;
      case 'Capability':
        return 4;
      case 'Agent':
        return 5;
      case 'Anchor':
        return 6;
      case 'Ticket':
        return 7;
      default:
        throw ArgumentError('Unsupported object kind: $kind');
    }
  }

  static void _encodeOwnership(List<int> out, Map<String, dynamic> owner) {
    switch (owner['type']) {
      case 'Address':
        out.add(1);
        _appendBytes(
          out,
          _fixedHexBytes(owner['address'].toString(), 20, '20-byte address'),
        );
        return;
      case 'Program':
        out.add(2);
        _appendBytes(
          out,
          _fixedHexBytes(owner['address'].toString(), 20, '20-byte address'),
        );
        return;
      case 'Shared':
        out.add(3);
        return;
      case 'NativeEd25519':
        out.add(4);
        _appendBytes(
          out,
          _fixedHexBytes(
            owner['public_key'].toString(),
            32,
            '32-byte public key',
          ),
        );
        return;
      default:
        throw ArgumentError('Unsupported owner type: ${owner['type']}');
    }
  }

  static void _encodeBytes(List<int> out, Uint8List bytes) {
    _appendU32(out, bytes.length);
    _appendBytes(out, bytes);
  }

  static void _encodeOptionalU64(List<int> out, int? value) {
    if (value == null) {
      out.add(0);
      return;
    }

    out.add(1);
    _appendU64(out, value);
  }

  static void _encodeOptionalU32(List<int> out, int? value) {
    if (value == null) {
      out.add(0);
      return;
    }

    out.add(1);
    _appendU32(out, value);
  }

  static void _appendBytes(List<int> out, Uint8List bytes) {
    out.addAll(bytes);
  }

  static void _appendU16(List<int> out, int value) {
    final normalized = value & 0xffff;
    out.add((normalized >> 8) & 0xff);
    out.add(normalized & 0xff);
  }

  static void _appendU32(List<int> out, int value) {
    final normalized = value & 0xffffffff;
    out.add((normalized >> 24) & 0xff);
    out.add((normalized >> 16) & 0xff);
    out.add((normalized >> 8) & 0xff);
    out.add(normalized & 0xff);
  }

  static void _appendU64(List<int> out, int value) {
    var bigint = BigInt.from(value);
    final bytes = Uint8List(8);
    for (var index = 7; index >= 0; index -= 1) {
      bytes[index] = (bigint & BigInt.from(0xff)).toInt();
      bigint = bigint >> 8;
    }
    _appendBytes(out, bytes);
  }

  static Uint8List _fixedHexBytes(String value, int length, String label) {
    final bytes = _hexToBytes(value);
    if (bytes.length != length) {
      throw ArgumentError('$label length mismatch');
    }
    return bytes;
  }

  static Uint8List _hexToBytes(String value) {
    return CryptoUtils.hexToBytes(_normalizeHexData(value));
  }

  static String _normalizeHash32(String value) {
    final normalized = _normalizeHexData(value);
    if (_hexToBytes(normalized).length != 32) {
      throw ArgumentError('Expected 32-byte hash');
    }
    return normalized;
  }

  static String _normalizePublicKey32(String value) {
    final normalized = _normalizeHexData(value);
    if (_hexToBytes(normalized).length != 32) {
      throw ArgumentError('Expected 32-byte public key');
    }
    return normalized;
  }

  static String _normalizeAddress20(String value) {
    final normalized = _normalizeHexData(value);
    if (_hexToBytes(normalized).length != 20) {
      throw ArgumentError('Expected 20-byte address');
    }
    return normalized;
  }

  static String _normalizeHexData(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '0x';
    }
    return trimmed.startsWith('0x') ? trimmed : '0x$trimmed';
  }

  static List<dynamic> _asList(dynamic value) {
    if (value == null) {
      return <dynamic>[];
    }
    if (value is List<dynamic>) {
      return value;
    }
    if (value is List) {
      return value.toList();
    }
    throw ArgumentError('Expected JSON array');
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value == null) {
      return <String, dynamic>{};
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    throw ArgumentError('Expected JSON object');
  }

  static int _readInt(dynamic value, {int? fallback}) {
    if (value == null) {
      if (fallback != null) {
        return fallback;
      }
      throw ArgumentError('Expected integer value');
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    throw ArgumentError('Expected integer value');
  }

  static int? _readNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    return _readInt(value);
  }
}

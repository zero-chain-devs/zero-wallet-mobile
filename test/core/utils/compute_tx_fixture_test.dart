import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_wallet/core/utils/compute_tx.dart';

Map<String, dynamic> loadFixture(String name) {
  final file = File(
    '../zero-chain/fixtures/compute_json/$name.json',
  );
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('ComputeTx shared fixtures', () {
    test('matches address owner fixture canonicalization', () {
      final fixture = loadFixture('address_owner_mint');
      final input = fixture['input'] as Map<String, dynamic>;
      final expected = fixture['expected'] as Map<String, dynamic>;

      final unsigned = ComputeTx.buildUnsignedTransaction(
        input,
        threshold: ((input['witness'] as Map<String, dynamic>)['threshold']) as int,
      );
      final txId = ComputeTx.computeTxId(
        ComputeTx.computeSigningPreimage(unsigned),
      );

      final outputs = unsigned['output_proposals'] as List<dynamic>;
      final firstOutput = outputs.first as Map<String, dynamic>;
      final resources = firstOutput['resources'] as List<dynamic>;

      expect(txId, expected['canonical_tx_id']);
      expect(firstOutput['owner'], expected['owner']);
      expect(
        resources
            .map((item) => (item as Map<String, dynamic>)['asset_id'])
            .toList(),
        expected['resource_asset_ids_sorted'],
      );
    });

    test('matches ed25519 owner fixture canonicalization', () {
      final fixture = loadFixture('ed25519_owner_mint');
      final input = fixture['input'] as Map<String, dynamic>;
      final expected = fixture['expected'] as Map<String, dynamic>;

      final unsigned = ComputeTx.buildUnsignedTransaction(
        input,
        threshold: ((input['witness'] as Map<String, dynamic>)['threshold']) as int,
      );
      final txId = ComputeTx.computeTxId(
        ComputeTx.computeSigningPreimage(unsigned),
      );

      final outputs = unsigned['output_proposals'] as List<dynamic>;
      final firstOutput = outputs.first as Map<String, dynamic>;

      expect(txId, expected['canonical_tx_id']);
      expect(firstOutput['owner'], expected['owner']);
    });
  });
}

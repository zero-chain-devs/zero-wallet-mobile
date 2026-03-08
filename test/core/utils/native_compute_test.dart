import 'package:flutter_test/flutter_test.dart';
import 'package:zero_wallet/core/utils/crypto_utils.dart';
import 'package:zero_wallet/core/utils/native_compute.dart';

String repeatHex(String pair) => List<String>.filled(32, pair).join();

void main() {
  group('NativeCompute', () {
    test(
      'defaultTemplate preserves network parameters and native owner key',
      () {
        final publicKey = '0x${repeatHex('11')}';
        final template = NativeCompute.defaultTemplate(
          publicKey: publicKey,
          chainId: 10086,
          networkId: 1,
        );
        final outputs = template['output_proposals'] as List<dynamic>;
        final firstOutput = outputs.first as Map<String, dynamic>;
        final owner = firstOutput['owner'] as Map<String, dynamic>;

        expect(template['chain_id'], 10086);
        expect(template['network_id'], 1);
        expect(firstOutput['output_id'], matches(RegExp(r'^0x[a-f0-9]{64}$')));
        expect(firstOutput['object_id'], matches(RegExp(r'^0x[a-f0-9]{64}$')));
        expect(owner['type'], 'NativeEd25519');
        expect(owner['public_key'], publicKey);
      },
    );

    test('defaultTemplate falls back to a zeroed public key when empty', () {
      final template = NativeCompute.defaultTemplate(
        publicKey: '',
        chainId: 10086,
        networkId: 9,
      );
      final outputs = template['output_proposals'] as List<dynamic>;
      final firstOutput = outputs.first as Map<String, dynamic>;
      final owner = firstOutput['owner'] as Map<String, dynamic>;

      expect(owner['public_key'], '0x${repeatHex('00')}');
      expect(template['network_id'], 9);
    });

    test('buildUnsignedTransaction sorts resources and normalizes payload', () {
      final unsigned = NativeCompute.buildUnsignedTransaction(<String, dynamic>{
        'domain_id': 0,
        'command': 'Mint',
        'payload': '01',
        'output_proposals': <Map<String, dynamic>>[
          <String, dynamic>{
            'output_id': '0x${repeatHex('aa')}',
            'object_id': '0x${repeatHex('bb')}',
            'domain_id': 0,
            'kind': 'State',
            'owner': <String, dynamic>{'type': 'Shared'},
            'version': 1,
            'state': '01',
            'resources': <Map<String, dynamic>>[
              <String, dynamic>{
                'asset_id': '0x${repeatHex('ff')}',
                'value': <String, dynamic>{'type': 'Amount', 'amount': '2'},
              },
              <String, dynamic>{
                'asset_id': '0x${repeatHex('01')}',
                'value': <String, dynamic>{'type': 'Amount', 'amount': '1'},
              },
            ],
          },
        ],
      }, threshold: 2);

      final outputs = unsigned['output_proposals'] as List<dynamic>;
      final firstOutput = outputs.first as Map<String, dynamic>;
      final resources = firstOutput['resources'] as List<dynamic>;

      expect(unsigned['payload'], '0x01');
      expect((unsigned['witness'] as Map<String, dynamic>)['threshold'], 2);
      expect(firstOutput['state'], '0x01');
      expect(
        resources.map((item) => (item as Map<String, dynamic>)['asset_id']),
        <String>['0x${repeatHex('01')}', '0x${repeatHex('ff')}'],
      );
    });

    test(
      'signTransaction returns tx id and ed25519 witness envelope',
      () async {
        final privateKey = repeatHex('22');
        final wallet = await CryptoUtils.deriveWalletFromPrivateKey(privateKey);

        final signed = await NativeCompute.signTransaction(
          input: <String, dynamic>{
            'domain_id': 0,
            'command': 'Mint',
            'chain_id': 10086,
            'network_id': 1,
            'threshold': 1,
            'output_proposals': <Map<String, dynamic>>[
              <String, dynamic>{
                'output_id': '0x${repeatHex('33')}',
                'object_id': '0x${repeatHex('44')}',
                'domain_id': 0,
                'kind': 'State',
                'owner': <String, dynamic>{
                  'type': 'NativeEd25519',
                  'public_key': wallet.publicKey,
                },
                'version': 1,
                'state': '0x01',
              },
            ],
          },
          privateKeyHex: wallet.privateKey,
          publicKeyHex: wallet.publicKey,
        );

        final witness = signed['witness'] as Map<String, dynamic>;
        final signatures = witness['signatures'] as List<dynamic>;
        final firstSignature = signatures.first as Map<String, dynamic>;

        expect(signed['tx_id'], matches(RegExp(r'^0x[a-f0-9]{64}$')));
        expect(witness['threshold'], 1);
        expect(firstSignature['scheme'], 'ed25519');
        expect(firstSignature['public_key'], '0x${wallet.publicKey}');
        expect(
          firstSignature['signature'],
          matches(RegExp(r'^0x[a-f0-9]{128}$')),
        );
      },
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_wallet/core/constants/app_constants.dart';
import 'package:zero_wallet/data/models/wallet_models.dart';
import 'package:zero_wallet/presentation/providers/wallet_provider.dart';

void main() {
  group('isSupportedCustomRpcUri', () {
    test('accepts https endpoints and local development http endpoints', () {
      expect(isSupportedCustomRpcUri(Uri.parse('https://rpc.example.com')), isTrue);
      expect(isSupportedCustomRpcUri(Uri.parse('http://127.0.0.1:8545')), isTrue);
      expect(isSupportedCustomRpcUri(Uri.parse('http://localhost:8545')), isTrue);
      expect(isSupportedCustomRpcUri(Uri.parse('http://10.0.2.2:8545')), isTrue);
    });

    test('rejects non-local cleartext and unsupported schemes', () {
      expect(isSupportedCustomRpcUri(Uri.parse('http://192.168.1.10:8545')), isFalse);
      expect(isSupportedCustomRpcUri(Uri.parse('ftp://rpc.example.com')), isFalse);
      expect(isSupportedCustomRpcUri(Uri.parse('ws://127.0.0.1:8546')), isFalse);
    });
  });

  group('bindComputeTxToNetwork', () {
    final mainnet = WalletNetwork.fromConfig(NetworkConfig.mainnet);

    test('fills missing chain and network ids from the selected network', () {
      final bound = bindComputeTxToNetwork(<String, dynamic>{
        'domain_id': 0,
        'command': 'Mint',
      }, mainnet);

      expect(bound['chain_id'], NetworkConfig.mainnet.chainId);
      expect(bound['network_id'], NetworkConfig.mainnet.networkId);
    });

    test('keeps matching explicit chain and network ids', () {
      final bound = bindComputeTxToNetwork(<String, dynamic>{
        'chain_id': NetworkConfig.mainnet.chainId.toString(),
        'network_id': NetworkConfig.mainnet.networkId,
      }, mainnet);

      expect(bound['chain_id'], NetworkConfig.mainnet.chainId);
      expect(bound['network_id'], NetworkConfig.mainnet.networkId);
    });

    test('rejects wrong-network compute transactions before signing', () {
      expect(
        () => bindComputeTxToNetwork(<String, dynamic>{
          'chain_id': NetworkConfig.mainnet.chainId,
          'network_id': NetworkConfig.testnet.networkId,
        }, mainnet),
        throwsArgumentError,
      );
    });
  });
}

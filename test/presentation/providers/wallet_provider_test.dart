import 'package:flutter_test/flutter_test.dart';
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
}

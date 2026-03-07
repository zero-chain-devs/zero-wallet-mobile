import 'package:flutter_test/flutter_test.dart';
import 'package:zero_wallet/core/network/rpc_client.dart';

void main() {
  group('mapRpcErrorMessage', () {
    test('returns write-rpc hint for eth_sendRawTransaction disabled code', () {
      final message = mapRpcErrorMessage(
        code: -32010,
        method: 'eth_sendRawTransaction',
        defaultMessage: 'Ethereum write RPCs are disabled',
      );

      expect(message, contains('--rpc-enable-eth-write-rpcs'));
      expect(message, contains('eth_sendRawTransaction'));
    });

    test('keeps default message for unrelated rpc errors', () {
      final message = mapRpcErrorMessage(
        code: -32601,
        method: 'eth_getTransactionReceipt',
        defaultMessage: 'Method not found',
      );

      expect(message, 'Method not found');
    });
  });
}

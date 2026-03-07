import 'package:flutter_test/flutter_test.dart';
import 'package:zero_wallet/core/network/rpc_client.dart';

void main() {
  group('mapRpcErrorMessage', () {
    test('keeps default message for native rpc errors', () {
      final message = mapRpcErrorMessage(
        code: -32000,
        method: 'zero_submitComputeTx',
        defaultMessage: 'Native compute submission failed',
      );

      expect(message, 'Native compute submission failed');
    });

    test('keeps default message for unknown methods', () {
      final message = mapRpcErrorMessage(
        code: -32601,
        method: 'zero_getAccount',
        defaultMessage: 'Method not found',
      );

      expect(message, 'Method not found');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rabbitchain_wallet/data/models/wallet_models.dart';

void main() {
  group('WalletAccount.create', () {
    test('generates UUID ids for new accounts', () {
      final first = WalletAccount.create(
        name: 'first',
        address: '0x1111111111111111111111111111111111111111',
        publicKey: 'a' * 64,
        privateKeyEncrypted: 'enc-1',
      );
      final second = WalletAccount.create(
        name: 'second',
        address: '0x2222222222222222222222222222222222222222',
        publicKey: 'b' * 64,
        privateKeyEncrypted: 'enc-2',
      );

      final uuidV4 = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );

      expect(first.id, matches(uuidV4));
      expect(second.id, matches(uuidV4));
      expect(first.id, isNot(second.id));
    });
  });
}

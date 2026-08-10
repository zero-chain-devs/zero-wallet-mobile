import 'package:flutter_test/flutter_test.dart';
import 'package:rabbitchain_wallet/presentation/widgets/wallet_ui.dart';

void main() {
  group('walletShortAddress', () {
    test('keeps short values unchanged', () {
      expect(
        walletShortAddress('0x1234', prefix: 4, suffix: 2),
        '0x1234',
      );
    });

    test('shortens long values with configurable prefix and suffix', () {
      expect(
        walletShortAddress(
          '0x1111111111111111111111111111111111111111',
          prefix: 8,
          suffix: 6,
        ),
        '0x111111...111111',
      );
    });
  });
}

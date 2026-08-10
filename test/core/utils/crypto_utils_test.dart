import 'package:flutter_test/flutter_test.dart';
import 'package:rabbitchain_wallet/core/utils/crypto_utils.dart';
import 'package:rabbitchain_wallet/data/models/wallet_models.dart';

String repeatHex(String pair) => List<String>.filled(32, pair).join();

void main() {
  group('CryptoUtils', () {
    test('normalizes native addresses from supported prefixes', () {
      const body = '1111111111111111111111111111111111111111';

      final expected = CryptoUtils.normalizeNativeAddress('0x$body');
      expect(
        () => CryptoUtils.normalizeNativeAddress('BAD0x$body'),
        throwsA(isA<ArgumentError>()),
      );
      expect(expected, startsWith(CryptoUtils.nativeAddressPrefix));
    });

    test('encrypts and decrypts data with the same password', () async {
      const secret = 'native-private-key-material';
      const password = 'StrongPassphrase123!';

      final encrypted = await CryptoUtils.encryptData(secret, password);
      final decrypted = await CryptoUtils.decryptData(encrypted, password);

      expect(encrypted, isNot(secret));
      expect(decrypted, secret);
    });

    test(
      'derives deterministic wallet data from a fixed private key',
      () async {
        final privateKey = repeatHex('11');

        final first = await CryptoUtils.deriveWalletFromPrivateKey(privateKey);
        final second = await CryptoUtils.deriveWalletFromPrivateKey(privateKey);

        expect(first.privateKey, privateKey);
        expect(first.publicKey, second.publicKey);
        expect(first.address, second.address);
        expect(first.address, startsWith('0x'));
        expect(first.signatureScheme, SignatureScheme.ed25519);
      },
    );

    test(
      'generates and derives deterministic wallet data from a mnemonic',
      () async {
        const mnemonic =
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

        expect(CryptoUtils.isValidMnemonic(mnemonic), isTrue);

        final first = await CryptoUtils.deriveWalletFromMnemonic(mnemonic);
        final second = await CryptoUtils.deriveWalletFromMnemonic(
          '  Abandon   abandon abandon   abandon abandon abandon abandon abandon abandon abandon abandon ABOUT  ',
        );

        expect(first.privateKey, second.privateKey);
        expect(first.publicKey, second.publicKey);
        expect(first.address, second.address);
        expect(first.address, startsWith('0x'));
        expect(first.signatureScheme, SignatureScheme.ed25519);
      },
    );

    test('creates a valid mnemonic wallet backup', () async {
      final generated = await CryptoUtils.createMnemonicWallet();

      expect(CryptoUtils.isValidMnemonic(generated.mnemonic), isTrue);
      expect(generated.wallet.privateKey, hasLength(64));
      expect(generated.wallet.address, startsWith('0x'));
      expect(generated.wallet.signatureScheme, SignatureScheme.ed25519);
    });
  });
}

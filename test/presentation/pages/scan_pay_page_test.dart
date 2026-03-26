import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:zero_wallet/core/constants/app_constants.dart';
import 'package:zero_wallet/data/models/wallet_models.dart';
import 'package:zero_wallet/presentation/pages/scan_pay_page.dart';
import 'package:zero_wallet/presentation/providers/wallet_provider.dart';

class TestWalletProvider extends WalletProvider {
  TestWalletProvider({
    WalletAccount? currentAccount,
    WalletNetwork? currentNetwork,
  }) : _currentAccount = currentAccount ??
           WalletAccount(
             id: 'acct-1',
             name: 'qa-wallet',
             address: 'ZER0x1111111111111111111111111111111111111111',
             publicKey: '0x${'11' * 32}',
             privateKeyEncrypted: 'cipher',
             signatureScheme: SignatureScheme.ed25519,
             createdAt: DateTime.utc(2026, 3, 9),
             isCurrent: true,
           ),
       _currentNetwork = currentNetwork ??
           WalletNetwork.fromConfig(NetworkConfig.local, isActive: true);

  final WalletAccount _currentAccount;
  final WalletNetwork _currentNetwork;

  @override
  WalletAccount? get currentAccount => _currentAccount;

  @override
  WalletNetwork get currentNetwork => _currentNetwork;
}

Widget _wrap(TestWalletProvider provider) {
  return ChangeNotifierProvider<WalletProvider>.value(
    value: provider,
    child: const MaterialApp(home: ScanPayPage()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const scannerChannel = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/method',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(scannerChannel, (call) async {
      switch (call.method) {
        case 'state':
          return 1;
        case 'request':
          return true;
        case 'start':
          return {
            'torchable': false,
            'textureId': 1,
            'size': {'width': 100.0, 'height': 100.0},
          };
        case 'stop':
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(scannerChannel, null);
  });

  group('ScanPayPage', () {
    testWidgets('shows scanner guidance copy', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(TestWalletProvider()));
      await tester.pumpAndSettle();

      expect(find.text('Scan to Pay'), findsOneWidget);
      expect(
        find.textContaining('Scan recipient QR'),
        findsOneWidget,
      );
      expect(find.byType(MobileScanner), findsOneWidget);
    });

    testWidgets('shows snackbar for unsupported QR content', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(TestWalletProvider()));
      await tester.pumpAndSettle();

      final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      scanner.onDetect(
        BarcodeCapture(
          barcodes: const [Barcode(rawValue: 'not-an-address')],
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Unsupported QR content, please scan an address'),
        findsOneWidget,
      );
    });

    testWidgets('navigates to send page after scanning a supported address', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(TestWalletProvider()));
      await tester.pumpAndSettle();

      final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      scanner.onDetect(
        BarcodeCapture(
          barcodes: const [
            Barcode(rawValue: 'ZER0x1111111111111111111111111111111111111111'),
          ],
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compute 交易'), findsOneWidget);
      expect(find.text('交易内容'), findsOneWidget);
      expect(find.text('支付'), findsOneWidget);
    });
  });
}

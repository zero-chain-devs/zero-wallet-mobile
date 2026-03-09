import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zero_wallet/core/constants/app_constants.dart';
import 'package:zero_wallet/data/models/wallet_models.dart';
import 'package:zero_wallet/presentation/pages/import_wallet_page.dart';
import 'package:zero_wallet/presentation/providers/wallet_provider.dart';

class TestWalletProvider extends WalletProvider {
  TestWalletProvider({
    WalletAccount? currentAccount,
    WalletNetwork? currentNetwork,
    bool isLoading = false,
    String? error,
  }) : _currentAccount = currentAccount ??
           WalletAccount(
             id: 'acct-1',
             name: 'qa-wallet',
             address: 'ZER0x2222222222222222222222222222222222222222',
             publicKey: '0x${'22' * 32}',
             privateKeyEncrypted: 'cipher',
             signatureScheme: SignatureScheme.ed25519,
             createdAt: DateTime.utc(2026, 3, 9),
             isCurrent: true,
           ),
       _currentNetwork = currentNetwork ??
           WalletNetwork.fromConfig(NetworkConfig.local, isActive: true),
       _isLoading = isLoading,
       _error = error;

  final WalletAccount _currentAccount;
  final WalletNetwork _currentNetwork;
  final bool _isLoading;
  final String? _error;

  int importCalls = 0;
  String? lastName;
  String? lastData;
  String? lastPassword;
  WalletImportMode? lastImportMode;

  @override
  WalletAccount? get currentAccount => _currentAccount;

  @override
  WalletNetwork get currentNetwork => _currentNetwork;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  Future<void> refreshBalance() async {}

  @override
  Future<ImportWalletResult> importWallet({
    required String data,
    required String name,
    required String password,
    required WalletImportMode importMode,
    SignatureScheme signatureScheme = SignatureScheme.ed25519,
  }) async {
    importCalls += 1;
    lastName = name;
    lastData = data;
    lastPassword = password;
    lastImportMode = importMode;
    return ImportWalletResult(success: true, account: _currentAccount);
  }
}

Widget _wrap(TestWalletProvider provider) {
  return ChangeNotifierProvider<WalletProvider>.value(
    value: provider,
    child: const MaterialApp(home: ImportWalletPage()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
        case 'SystemSound.play':
        case 'SystemChrome.setApplicationSwitcherDescription':
        case 'SystemChrome.setSystemUIOverlayStyle':
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('ImportWalletPage', () {
    testWidgets('validates private key and password fields before submit', (
      WidgetTester tester,
    ) async {
      final provider = TestWalletProvider();

      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(4));

      await tester.enterText(fields.at(0), 'import-wallet');
      await tester.enterText(fields.at(1), 'not-hex');
      await tester.enterText(fields.at(2), 'StrongPass123');
      await tester.enterText(fields.at(3), 'StrongPass123');
      await tester.tap(find.widgetWithText(ElevatedButton, '导入钱包'));
      await tester.pumpAndSettle();

      expect(find.text('私钥必须是 32 字节 hex'), findsOneWidget);
      expect(provider.importCalls, 0);
    });

    testWidgets('submits successfully and navigates to dashboard', (
      WidgetTester tester,
    ) async {
      final provider = TestWalletProvider();

      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(4));

      await tester.enterText(fields.at(0), 'import-wallet');
      await tester.enterText(fields.at(1), '0x${'a' * 64}');
      await tester.enterText(fields.at(2), 'StrongPass123');
      await tester.enterText(fields.at(3), 'StrongPass123');
      await tester.tap(find.widgetWithText(ElevatedButton, '导入钱包'));
      await tester.pumpAndSettle();

      expect(provider.importCalls, 1);
      expect(provider.lastName, 'import-wallet');
      expect(provider.lastData, '0x${'a' * 64}');
      expect(provider.lastPassword, 'StrongPass123');
      expect(provider.lastImportMode, WalletImportMode.privateKey);
      expect(find.text('钱包导入成功'), findsOneWidget);
      expect(find.text('发送'), findsOneWidget);
      expect(find.text('接收'), findsOneWidget);
    });
  });
}

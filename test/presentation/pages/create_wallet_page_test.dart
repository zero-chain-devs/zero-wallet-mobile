import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zero_wallet/core/constants/app_constants.dart';
import 'package:zero_wallet/data/models/wallet_models.dart';
import 'package:zero_wallet/presentation/pages/create_wallet_page.dart';
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
             address: 'ZER0x1111111111111111111111111111111111111111',
             publicKey: '0x${'11' * 32}',
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

  int createCalls = 0;
  String? lastName;
  String? lastPassword;

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
  Future<CreateWalletResult> createWallet({
    required String name,
    required String password,
    SignatureScheme signatureScheme = SignatureScheme.ed25519,
  }) async {
    createCalls += 1;
    lastName = name;
    lastPassword = password;
    return CreateWalletResult(
      success: true,
      account: _currentAccount,
      backupValue: '0xabc123',
      backupTitle: '请备份 ed25519 私钥',
      backupDescription: '测试用备份提示',
    );
  }
}

Widget _wrap(TestWalletProvider provider) {
  return ChangeNotifierProvider<WalletProvider>.value(
    value: provider,
    child: const MaterialApp(home: CreateWalletPage()),
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

  group('CreateWalletPage', () {
    testWidgets('validates required fields before submit', (
      WidgetTester tester,
    ) async {
      final provider = TestWalletProvider();

      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, '创建钱包'));
      await tester.pumpAndSettle();

      expect(find.text('请输入账户名称'), findsOneWidget);
      expect(find.text('请输入钱包密码'), findsOneWidget);
      expect(find.text('请确认密码'), findsOneWidget);
      expect(provider.createCalls, 0);
    });

    testWidgets('submits successfully, shows backup dialog and enters dashboard', (
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
      expect(fields, findsNWidgets(3));

      await tester.enterText(fields.at(0), 'primary-wallet');
      await tester.enterText(fields.at(1), 'StrongPass123');
      await tester.enterText(fields.at(2), 'StrongPass123');
      await tester.tap(find.widgetWithText(ElevatedButton, '创建钱包'));
      await tester.pumpAndSettle();

      expect(provider.createCalls, 1);
      expect(provider.lastName, 'primary-wallet');
      expect(provider.lastPassword, 'StrongPass123');
      expect(find.text('请备份 ed25519 私钥'), findsOneWidget);
      expect(find.text('测试用备份提示'), findsOneWidget);
      expect(find.text('0xabc123'), findsOneWidget);

      await tester.tap(find.text('我已备份'));
      await tester.pumpAndSettle();

      expect(find.text('发送'), findsOneWidget);
      expect(find.text('接收'), findsOneWidget);
    });
  });
}

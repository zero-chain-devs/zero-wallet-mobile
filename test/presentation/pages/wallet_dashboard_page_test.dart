import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zero_wallet/core/constants/app_constants.dart';
import 'package:zero_wallet/data/models/wallet_models.dart';
import 'package:zero_wallet/presentation/pages/wallet_dashboard_page.dart';
import 'package:zero_wallet/presentation/providers/wallet_provider.dart';

class TestWalletProvider extends WalletProvider {
  TestWalletProvider({
    WalletAccount? currentAccount,
    WalletNetwork? currentNetwork,
    AccountBalance? currentBalance,
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
       _currentBalance = currentBalance,
       _error = error;

  final WalletAccount _currentAccount;
  final WalletNetwork _currentNetwork;
  final AccountBalance? _currentBalance;
  final String? _error;

  int refreshBalanceCalls = 0;

  @override
  WalletAccount? get currentAccount => _currentAccount;

  @override
  WalletNetwork get currentNetwork => _currentNetwork;

  @override
  AccountBalance? get currentBalance => _currentBalance;

  @override
  String? get error => _error;

  @override
  Future<void> refreshBalance() async {
    refreshBalanceCalls += 1;
  }
}

Widget _wrap(TestWalletProvider provider) {
  return ChangeNotifierProvider<WalletProvider>.value(
    value: provider,
    child: const MaterialApp(home: WalletDashboardPage()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final clipboardLog = <MethodCall>[];

  setUp(() {
    clipboardLog.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      clipboardLog.add(call);
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

  group('WalletDashboardPage', () {
    testWidgets('opens receive sheet and copies address', (
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(provider.refreshBalanceCalls, 1);
      expect(find.text('发送'), findsOneWidget);
      expect(find.text('接收'), findsOneWidget);

      await tester.tap(find.text('接收'));
      await tester.pumpAndSettle();

      expect(find.text('复制地址'), findsOneWidget);
      expect(find.text(provider.currentAccount!.address), findsOneWidget);
      expect(find.text(provider.currentNetwork.name), findsAtLeastNWidgets(1));

      await tester.tap(find.text('复制地址'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('地址已复制'), findsOneWidget);
      expect(
        clipboardLog.where((call) => call.method == 'Clipboard.setData'),
        isNotEmpty,
      );
    });

    testWidgets('switches bottom tabs and shows each tab headline', (
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('账户状态'), findsOneWidget);

      await tester.tap(find.text('兑换').last);
      await tester.pumpAndSettle();
      expect(find.text('打开 Compute 交易页'), findsOneWidget);
      expect(find.text('支付'), findsWidgets);

      await tester.tap(find.text('设置').last);
      await tester.pumpAndSettle();
      expect(find.text('账户切换'), findsOneWidget);
      expect(find.text('网络'), findsOneWidget);
      expect(find.text('Preview Surfaces'), findsOneWidget);
      expect(find.text('Markets Preview'), findsOneWidget);
      expect(find.text('Activity Preview'), findsOneWidget);
    });
  });
}

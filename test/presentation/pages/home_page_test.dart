import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zero_wallet/core/constants/app_constants.dart';
import 'package:zero_wallet/data/models/wallet_models.dart';
import 'package:zero_wallet/presentation/pages/home_page.dart';
import 'package:zero_wallet/presentation/providers/wallet_provider.dart';

class TestWalletProvider extends WalletProvider {
  TestWalletProvider({
    bool isLoading = false,
    bool isInitialized = true,
    bool hasWallet = false,
    String? error,
    WalletAccount? currentAccount,
    WalletNetwork? currentNetwork,
  }) : _isLoading = isLoading,
       _isInitialized = isInitialized,
       _hasWallet = hasWallet,
       _error = error,
       _currentAccount = currentAccount,
       _currentNetwork = currentNetwork ??
           WalletNetwork.fromConfig(NetworkConfig.local, isActive: true);

  final bool _isLoading;
  final bool _isInitialized;
  final bool _hasWallet;
  final String? _error;
  final WalletAccount? _currentAccount;
  final WalletNetwork _currentNetwork;

  int initializeCalls = 0;
  int refreshBalanceCalls = 0;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get hasWallet => _hasWallet;

  @override
  String? get error => _error;

  @override
  WalletAccount? get currentAccount => _currentAccount;

  @override
  WalletNetwork get currentNetwork => _currentNetwork;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
    notifyListeners();
  }

  @override
  Future<void> refreshBalance() async {
    refreshBalanceCalls += 1;
  }
}

Widget _wrapWithProvider(TestWalletProvider provider) {
  return ChangeNotifierProvider<WalletProvider>.value(
    value: provider,
    child: const MaterialApp(home: HomePage()),
  );
}

void main() {
  group('HomePage', () {
    testWidgets('switches welcome copy when bottom navigation changes', (
      WidgetTester tester,
    ) async {
      final provider = TestWalletProvider();

      await tester.pumpWidget(_wrapWithProvider(provider));
      await tester.pump();

      expect(find.textContaining('立即开始使用'), findsOneWidget);
      expect(provider.initializeCalls, 1);

      await tester.tap(find.text('设置').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('管理网络与偏好'), findsOneWidget);
      expect(find.textContaining('守护你的资产'), findsOneWidget);
    });

    testWidgets('shows error state and retries initialize when tapped', (
      WidgetTester tester,
    ) async {
      final provider = TestWalletProvider(
        isInitialized: false,
        error: 'boom init failed',
      );

      await tester.pumpWidget(_wrapWithProvider(provider));
      await tester.pump();

      expect(find.text('boom init failed'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(provider.initializeCalls, 1);

      await tester.tap(find.text('重试'));
      await tester.pump();

      expect(provider.initializeCalls, 2);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zero_wallet/core/constants/app_constants.dart';
import 'package:zero_wallet/data/models/wallet_models.dart';
import 'package:zero_wallet/presentation/pages/send_payment_page.dart';
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

  int simulateCalls = 0;
  String? lastJsonText;
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
  Future<ComputeTxActionResult> simulateComputeTx({
    required String jsonText,
    required String password,
  }) async {
    simulateCalls += 1;
    lastJsonText = jsonText;
    lastPassword = password;
    return ComputeTxActionResult(
      success: true,
      signedTx: <String, dynamic>{'txId': '0xabc'},
      result: <String, dynamic>{'ok': true},
    );
  }
}

Widget _wrapWithProvider(TestWalletProvider provider) {
  return ChangeNotifierProvider<WalletProvider>.value(
    value: provider,
    child: const MaterialApp(home: SendPaymentPage()),
  );
}

void main() {
  group('SendPaymentPage', () {
    testWidgets('validates password before simulate', (
      WidgetTester tester,
    ) async {
      final provider = TestWalletProvider();

      await tester.pumpWidget(_wrapWithProvider(provider));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '模拟'));
      await tester.pumpAndSettle();

      expect(find.text('请输入钱包密码'), findsOneWidget);
      expect(provider.simulateCalls, 0);
    });

    testWidgets('simulates native transaction and shows formatted result', (
      WidgetTester tester,
    ) async {
      final provider = TestWalletProvider();

      await tester.pumpWidget(_wrapWithProvider(provider));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText).last, 'StrongPass123');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '模拟'));
      await tester.pumpAndSettle();

      expect(provider.simulateCalls, 1);
      expect(provider.lastPassword, 'StrongPass123');
      expect(provider.lastJsonText, contains('"command": "Mint"'));
      expect(find.text('执行结果'), findsOneWidget);
      expect(find.textContaining('0xabc'), findsOneWidget);
      expect(find.textContaining('"ok": true'), findsOneWidget);
    });
  });
}

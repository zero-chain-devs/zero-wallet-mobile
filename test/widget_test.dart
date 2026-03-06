import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zero_wallet/core/theme/app_theme.dart';
import 'package:zero_wallet/presentation/providers/wallet_provider.dart';
import 'package:zero_wallet/presentation/pages/home_page.dart';

void main() {
  testWidgets('Wallet app loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => WalletProvider())],
        child: MaterialApp(
          title: 'Zero Wallet',
          theme: AppTheme.lightTheme,
          home: const HomePage(),
        ),
      ),
    );

    // Wait for initial frame
    await tester.pump();

    // Verify app loads (check for scaffold which is always present)
    expect(find.byType(Scaffold), findsOneWidget);
  });
}

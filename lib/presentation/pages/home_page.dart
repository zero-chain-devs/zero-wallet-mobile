import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/wallet_provider.dart';
import '../widgets/wallet_ui.dart';
import 'create_wallet_page.dart';
import 'import_wallet_page.dart';
import 'wallet_dashboard_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _welcomeNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WalletUi.background,
      body: Consumer<WalletProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!provider.isInitialized) {
            return _buildErrorState(
              provider.error ?? 'Failed to initialize wallet',
            );
          }

          if (!provider.hasWallet) {
            return _buildWelcomeScreen();
          }

          return const WalletDashboardPage();
        },
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    const chipLabels = <String>[
      'Zero Wallet Home',
      'Discover Zero',
      'Swap Preview',
      'Recent Activity',
      'Wallet Settings',
    ];
    const headlines = <String>[
      '立即开始使用\nZero Wallet',
      '探索行情与资产\n发现更多机会',
      '快速兑换资产\nCrypto <> Cash',
      '查看最近记录\n掌握资金流向',
      '管理网络与偏好\n守护你的资产',
    ];
    const descriptions = <String>[
      '当前版本聚焦原生链钱包，视觉按参考稿复刻为同一套 Phantom 风格深色界面。',
      '统一查看市场和资产变化，后续会接入更完整的行情与深度数据。',
      '支持在 ZeroChain 生态内进行资产交换，后续接入真实撮合与路由。',
      '交易与操作记录集中展示，方便快速定位每一笔动作。',
      '在这里切换网络、账户与安全设置，管理你的钱包环境。',
    ];
    final headline = headlines[_welcomeNavIndex];
    final description = descriptions[_welcomeNavIndex];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8F7CF7), Color(0xFFB89BFF)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 12),
                child: Stack(
                  children: [
                    Positioned(
                      left: -100,
                      top: 20,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x26FFFFFF),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -60,
                      top: 150,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x14FFFFFF),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 44,
                      top: 242,
                      child: Transform.rotate(
                        angle: 0.3,
                        child: Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: WalletUi.lime,
                            border: Border.all(
                              color: const Color(0xFF95A60B),
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55747E12),
                                blurRadius: 28,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF2C214A),
                                  width: 2.2,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.mode_comment_outlined,
                                  color: Color(0xFF2C214A),
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FloatingGlassCard(
                            title: 'Cash Balance',
                            subtitle: '\$18,207.41',
                            width: 192,
                            icon: Icons.chat_bubble_outline_rounded,
                          ),
                          const SizedBox(height: 14),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: _FloatingGlassCard(
                              title: 'Send',
                              subtitle: 'To friends',
                              width: 174,
                              icon: Icons.attach_money_rounded,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const _FloatingGlassCard(
                            title: 'Trade',
                            subtitle: 'Crypto <> Cash',
                            width: 208,
                            icon: Icons.compare_arrows_rounded,
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              chipLabels[_welcomeNavIndex],
                              style: const TextStyle(
                                color: Color(0xFF2B1F52),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            headline,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 46,
                              fontWeight: FontWeight.w900,
                              height: 0.92,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            description,
                            style: const TextStyle(
                              color: Color(0xF0FFFFFF),
                              fontSize: 15,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _navigateToCreateWallet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: WalletUi.lime,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                '输入',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _navigateToImportWallet,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                '导入已有钱包',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            WalletBottomNav(
              currentIndex: _welcomeNavIndex,
              onTap: (index) => setState(() => _welcomeNavIndex = index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: WalletDarkCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: WalletUi.negative,
                  size: 54,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        context.read<WalletProvider>().initialize(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WalletUi.lime,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      '重试',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToCreateWallet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateWalletPage()),
    );
  }

  void _navigateToImportWallet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ImportWalletPage()),
    );
  }
}

class _FloatingGlassCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double width;
  final IconData icon;

  const _FloatingGlassCard({
    required this.title,
    required this.subtitle,
    required this.width,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

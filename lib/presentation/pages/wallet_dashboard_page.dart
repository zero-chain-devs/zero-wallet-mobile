import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/wallet_models.dart';
import '../providers/wallet_provider.dart';
import '../widgets/wallet_ui.dart';
import 'create_wallet_page.dart';
import 'import_wallet_page.dart';
import 'send_payment_page.dart';

class WalletDashboardPage extends StatefulWidget {
  const WalletDashboardPage({super.key});

  @override
  State<WalletDashboardPage> createState() => _WalletDashboardPageState();
}

class _WalletDashboardPageState extends State<WalletDashboardPage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().refreshBalance();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, _) {
        final account = provider.currentAccount;
        if (account == null) {
          return Scaffold(
            backgroundColor: WalletUi.background,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: WalletDarkCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.white54,
                          size: 52,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '未找到钱包账户',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '请先创建或导入账户，再继续使用钱包。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: WalletBottomNav(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
            ),
          );
        }

        final pages = <Widget>[
          _HomeTab(
            provider: provider,
            account: account,
            onSend: () => _openSend(context),
            onSwap: () => setState(() => _selectedIndex = 1),
            onReceive: () => _showReceiveSheet(
              context,
              account,
              provider.currentNetwork.name,
            ),
            onBuy: () => setState(() => _selectedIndex = 2),
          ),
          _SwapTab(account: account, onOpenSend: () => _openSend(context)),
          _SettingsTab(provider: provider, account: account),
        ];

        return Scaffold(
          backgroundColor: WalletUi.background,
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(_selectedIndex),
                child: pages[_selectedIndex],
              ),
            ),
          ),
          bottomNavigationBar: WalletBottomNav(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
          ),
        );
      },
    );
  }

  void _openSend(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SendPaymentPage()),
    );
  }

  Future<void> _showReceiveSheet(
    BuildContext context,
    WalletAccount account,
    String networkName,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: WalletUi.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '接收',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: QrImageView(
                      data: account.address,
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    networkName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.46),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    walletShortAddress(
                      account.address,
                      prefix: account.signatureScheme == SignatureScheme.ed25519
                          ? 10
                          : 8,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      account.address,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: account.address),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('地址已复制')));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WalletUi.lime,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text(
                        '复制地址',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeTab extends StatelessWidget {
  final WalletProvider provider;
  final WalletAccount account;
  final VoidCallback onSend;
  final VoidCallback onSwap;
  final VoidCallback onReceive;
  final VoidCallback onBuy;

  const _HomeTab({
    required this.provider,
    required this.account,
    required this.onSend,
    required this.onSwap,
    required this.onReceive,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final isNative = account.signatureScheme == SignatureScheme.ed25519;
    final currentBalance = provider.currentBalance;
    final nonceText = provider.currentNonceHex ?? '0x0';
    final refreshedAtText = currentBalance?.updatedAt == null
        ? '--'
        : TimeOfDay.fromDateTime(currentBalance!.updatedAt).format(context);
    final rpcHostText = _formatRpcHost(provider.currentRpcUrl);
    final balanceText = isNative
        ? '${currentBalance?.balanceFormatted ?? '0'} ${currentBalance?.symbol ?? provider.currentNetwork.currencySymbol}'
        : '\$${currentBalance?.balanceFormatted ?? "0.00"}';
    final assetRows = <Map<String, Object>>[
      {
        'name': isNative ? '当前账户' : 'Solana',
        'subtitle': isNative
            ? 'ed25519 / compute'
            : '${currentBalance?.balanceFormatted ?? '0'} ${currentBalance?.symbol ?? provider.currentNetwork.currencySymbol}',
        'value': balanceText,
        'delta': isNative
            ? '余额已同步'
            : '-\$0.12',
        'positive': isNative,
        'color': const Color(0xFF6D5BFF),
        'avatar': isNative ? 'ZN' : 'S',
      },
      {
        'name': '当前网络',
        'subtitle': provider.currentNetwork.name,
        'value': '--',
        'delta': provider.currentNetwork.currencySymbol,
        'positive': true,
        'color': const Color(0xFF8B5CF6),
        'avatar': 'NW',
      },
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        WalletHeader(
          eyebrow: '@${account.name}',
          title: account.name,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleIconButton(
                icon: Icons.history_rounded,
                onTap: () => provider.refreshBalance(),
              ),
              const SizedBox(width: 10),
              _CircleIconButton(icon: Icons.search_rounded, onTap: onBuy),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          balanceText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.w900,
            height: 0.95,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _DeltaPill(label: isNative ? 'native' : '-\$0.11'),
            const SizedBox(width: 8),
            _DeltaPill(label: isNative ? 'ready' : '-3.98%'),
          ],
        ),
        const SizedBox(height: 14),
        WalletDarkCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(child: _StatusTile(label: 'Nonce', value: nonceText)),
              const SizedBox(width: 10),
              Expanded(child: _StatusTile(label: '最近刷新', value: refreshedAtText)),
              const SizedBox(width: 10),
              Expanded(child: _StatusTile(label: '当前 RPC', value: rpcHostText)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            WalletActionTile(
              icon: Icons.send_rounded,
              label: '发送',
              onTap: onSend,
            ),
            const SizedBox(width: 10),
            WalletActionTile(
              icon: Icons.sync_alt_rounded,
              label: '兑换',
              onTap: onSwap,
            ),
            const SizedBox(width: 10),
            WalletActionTile(
              icon: Icons.qr_code_2_rounded,
              label: '接收',
              onTap: onReceive,
            ),
            const SizedBox(width: 10),
            WalletActionTile(
              icon: Icons.attach_money_rounded,
              label: '购买',
              onTap: onBuy,
            ),
          ],
        ),
        if ((provider.error ?? '').isNotEmpty) ...[
          const SizedBox(height: 18),
          WalletBanner(message: provider.error!, error: true),
        ] else ...[
          const SizedBox(height: 18),
          const WalletBanner(
            message: 'RPC 状态正常，账户余额与状态信息已同步。',
            error: false,
          ),
        ],
        const SizedBox(height: 22),
        const WalletSectionTitle(title: '账户状态'),
        const SizedBox(height: 10),
        ...assetRows.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: WalletDarkCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: WalletTokenRow(
                name: item['name']! as String,
                subtitle: item['subtitle']! as String,
                value: item['value']! as String,
                delta: item['delta']! as String,
                positive: item['positive']! as bool,
                color: item['color']! as Color,
                avatar: item['avatar']! as String,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatRpcHost(String rpcUrl) {
  try {
    final uri = Uri.parse(rpcUrl);
    return uri.host.isEmpty ? rpcUrl : uri.host;
  } catch (_) {
    return rpcUrl;
  }
}

class _StatusTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatusTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketsTab extends StatelessWidget {
  const _MarketsTab();

  @override
  Widget build(BuildContext context) {
    const groups = [
      {
        'title': '流行代币',
        'items': [
          [
            '1',
            'WAR',
            '\$57M MC',
            '\$0.0573',
            '+70.52%',
            Color(0xFF475569),
            'WA',
          ],
          [
            '2',
            'RADR',
            '\$321K MC',
            '\$0.0003378',
            '+843.31%',
            Color(0xFFF97316),
            'RA',
          ],
          [
            '3',
            'SOL人生',
            '\$225K MC',
            '\$0.00023324',
            '+3,202.88%',
            Color(0xFF7C3AED),
            'SO',
          ],
        ],
      },
      {
        'title': '流行永续合约',
        'items': [
          [
            '1',
            'CL',
            '\$412M Vol',
            '\$89.33',
            '+12.44%',
            Color(0xFF94A3B8),
            'CL',
          ],
          [
            '2',
            'BRENTOIL',
            '\$49M Vol',
            '\$91.50',
            '+7.96%',
            Color(0xFF0EA5E9),
            'BR',
          ],
        ],
      },
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        const WalletPreviewBanner(
          title: '预览页',
          label: '仅供参考',
          message: '本页当前仅展示静态市场样式，不代表真实价格、成交量或排名。',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: Colors.white54),
                    const SizedBox(width: 10),
                    Text(
                      '网站，代币，URL',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Text(
                '4',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            _TopModeChip(label: '币币', accent: Color(0xFF34D399), light: false),
            SizedBox(width: 10),
            _TopModeChip(label: '永续合约', accent: Colors.white, light: true),
            SizedBox(width: 10),
            _TopModeChip(label: '列表', accent: WalletUi.accent, light: false),
          ],
        ),
        const SizedBox(height: 18),
        ...groups.map((group) {
          final items = group['items']! as List<List<Object>>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WalletSectionTitle(title: group['title']! as String),
                const SizedBox(height: 10),
                WalletDarkCard(
                  child: Column(
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        if (index > 0) const SizedBox(height: 14),
                        WalletMarketRow(
                          rank: items[index][0] as String,
                          name: items[index][1] as String,
                          subtitle: items[index][2] as String,
                          price: items[index][3] as String,
                          change: items[index][4] as String,
                          color: items[index][5] as Color,
                          avatar: items[index][6] as String,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _SwapTab extends StatelessWidget {
  final WalletAccount account;
  final VoidCallback onOpenSend;

  const _SwapTab({required this.account, required this.onOpenSend});

  @override
  Widget build(BuildContext context) {
    final isNative = account.signatureScheme == SignatureScheme.ed25519;
    const title = 'ZeroChain';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        const WalletPreviewBanner(
          title: '预览页',
          label: '仅供参考',
          message: '本页当前是静态兑换演示面板，展示值不代表真实撮合或报价。',
        ),
        const SizedBox(height: 14),
        const WalletHeader(
          eyebrow: 'ZeroChain 预览页',
          title: '兑换',
          trailing: _CircleIconButton(icon: Icons.tune_rounded),
        ),
        const SizedBox(height: 16),
        WalletDarkCard(
          child: Column(
            children: [
              _SwapPanel(
                title: '支付',
                badge: title,
                bigValue: '0',
                tokenLabel: isNative ? 'ZERO' : 'SOL',
                subValue: isNative ? '0.00000 ZERO' : '0.02479 SOL',
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: WalletUi.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sync_alt_rounded,
                    color: Color(0xFF1B1031),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _SwapPanel(
                title: '收到',
                badge: isNative ? 'COMPUTE' : 'USDC',
                bigValue: '0',
                tokenLabel: isNative ? 'COMPUTE' : 'USDC',
                subValue: isNative ? '0 COMPUTE' : '0 USDC',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onOpenSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WalletUi.lime,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    isNative ? '打开 Compute 交易页' : '打开发送页',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Text(
              '代币',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 18),
            Text(
              '永续合约',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            _FilterChip(label: '排名'),
            SizedBox(width: 8),
            _FilterChip(label: 'Solana'),
            SizedBox(width: 8),
            _FilterChip(label: '24 小时'),
          ],
        ),
        const SizedBox(height: 14),
        const WalletDarkCard(
          child: Column(
            children: [
              WalletMarketRow(
                rank: '1',
                name: 'WAR',
                subtitle: '\$57M MC',
                price: '\$0.0573',
                change: '+70.52%',
                color: Color(0xFF475569),
                avatar: 'WA',
              ),
              SizedBox(height: 14),
              WalletMarketRow(
                rank: '2',
                name: 'RADR',
                subtitle: '\$321K MC',
                price: '\$0.0003378',
                change: '+843.31%',
                color: Color(0xFFF97316),
                avatar: 'RA',
              ),
              SizedBox(height: 14),
              WalletMarketRow(
                rank: '3',
                name: 'SOL人生',
                subtitle: '\$225K MC',
                price: '\$0.00023324',
                change: '+3,202.88%',
                color: Color(0xFF7C3AED),
                avatar: 'SO',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context) {
    const hotItems = [
      ['WAR', '\$57M MC', '200', Color(0xFF475569), 'WA'],
      ['RADR', '\$312K MC', '47', Color(0xFFF97316), 'RA'],
      ['USOR', '\$8.2M MC', '22', Color(0xFFD4AF37), 'US'],
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        const WalletPreviewBanner(
          title: '预览页',
          label: '仅供参考',
          message: '本页当前仅展示静态活动与聊天样式，不代表真实用户动态。',
        ),
        const SizedBox(height: 14),
        const WalletHeader(eyebrow: 'ZeroChain 预览页', title: '聊天'),
        const SizedBox(height: 20),
        const WalletSectionTitle(title: '热门'),
        const SizedBox(height: 12),
        WalletDarkCard(
          child: Column(
            children: [
              for (var index = 0; index < hotItems.length; index++) ...[
                if (index > 0) const SizedBox(height: 14),
                Row(
                  children: [
                    WalletTokenAvatar(
                      label: hotItems[index][4] as String,
                      color: hotItems[index][3] as Color,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hotItems[index][0] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hotItems[index][1] as String,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.52),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.people_alt_outlined,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.52),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hotItems[index][2] as String,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 26),
        const WalletSectionTitle(title: '最近'),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 42),
          child: Column(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 70,
                color: Colors.white.withValues(alpha: 0.16),
              ),
              const SizedBox(height: 12),
              Text(
                '当前没有可展示的活动记录。',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.34),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  final WalletProvider provider;
  final WalletAccount account;

  const _SettingsTab({required this.provider, required this.account});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        WalletHeader(
          eyebrow: '@${account.name}',
          title: '设置',
          trailing: _CircleIconButton(
            icon: Icons.refresh_rounded,
            onTap: () => provider.refreshBalance(),
          ),
        ),
        const SizedBox(height: 16),
        if ((provider.error ?? '').isNotEmpty) ...[
          WalletBanner(message: provider.error!, error: true),
          const SizedBox(height: 16),
        ],
        WalletDarkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '当前账户',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                account.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                walletShortAddress(
                  account.address,
                  prefix: account.signatureScheme == SignatureScheme.ed25519
                      ? 10
                      : 8,
                ),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.58)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: account.address),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('地址已复制')));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WalletUi.lime,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text(
                        '复制地址',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SendPaymentPage(),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text(
                        '交易页',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        WalletDarkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '账户切换',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              for (
                var index = 0;
                index < provider.accounts.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(height: 10),
                _SelectionRow(
                  title: provider.accounts[index].name,
                  subtitle:
                      'ZeroChain 账户 · ${walletShortAddress(provider.accounts[index].address)}',
                  selected: provider.accounts[index].id == account.id,
                  onTap: () =>
                      provider.switchAccount(provider.accounts[index].id),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        WalletDarkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '网络',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              for (final config in NetworkConfig.predefined) ...[
                _SelectionRow(
                  title: config.name,
                  subtitle: 'chain ${config.chainId} · net ${config.networkId}',
                  selected: config.id == provider.currentNetwork.id,
                  onTap: () => provider.switchNetwork(config.id),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                provider.currentRpcUrl,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRpcUrlEditor(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('编辑 RPC'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _resetRpcUrl(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('恢复默认'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        WalletDarkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '预览页面',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '管理网络与预览入口',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const WalletPreviewBanner(
                title: '预览页',
                label: '仅供参考',
                message: '设计预览入口：市场、聊天与静态兑换样式已从主导航降权，只保留为预览。',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const _MarketsTab()),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.wallet_outlined, size: 18),
                      label: const Text('市场预览'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const _ActivityTab()),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: const Text('活动预览'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateWalletPage(),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text(
                  '创建账户',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImportWalletPage(),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.download_rounded),
                label: const Text(
                  '导入账户',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showRpcUrlEditor(BuildContext context) async {
    final controller = TextEditingController(text: provider.currentRpcUrl);
    final nextUrl = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑 RPC URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'http://host:port',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (nextUrl == null || nextUrl.isEmpty || !context.mounted) {
      return;
    }
    final ok = await provider.updateCurrentNetworkRpcUrl(nextUrl);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'RPC URL 已更新' : (provider.error ?? 'RPC URL 更新失败')),
      ),
    );
  }

  Future<void> _resetRpcUrl(BuildContext context) async {
    final ok = await provider.resetCurrentNetworkRpcUrl();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '已恢复默认 RPC URL' : (provider.error ?? '恢复默认失败')),
      ),
    );
  }
}

class _TopModeChip extends StatelessWidget {
  final String label;
  final Color accent;
  final bool light;

  const _TopModeChip({
    required this.label,
    required this.accent,
    required this.light,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: light ? Colors.white : accent,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: light ? const Color(0xFF141414) : const Color(0xFF111111),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SwapPanel extends StatelessWidget {
  final String title;
  final String badge;
  final String bigValue;
  final String tokenLabel;
  final String subValue;

  const _SwapPanel({
    required this.title,
    required this.badge,
    required this.bigValue,
    required this.tokenLabel,
    required this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  bigValue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: badge == 'USDC'
                            ? const Color(0xFF3B82F6)
                            : WalletUi.accent,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tokenLabel.substring(0, 1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tokenLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              subValue,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;

  const _FilterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.86),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CircleIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.72)),
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final String label;

  const _DeltaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: WalletUi.negative,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SelectionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: selected
                          ? Colors.black54
                          : Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 16,
                color: selected ? Colors.black : WalletUi.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

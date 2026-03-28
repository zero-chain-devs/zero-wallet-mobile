import 'package:flutter/material.dart';

class WalletUi {
  static const Color background = Color(0xFF050505);
  static const Color surface = Color(0xFF151515);
  static const Color surfaceElevated = Color(0xFF1B1B1B);
  static const Color panel = Color(0xFF111111);
  static const Color accent = Color(0xFFB693FF);
  static const Color lime = Color(0xFFDDF247);
  static const Color positive = Color(0xFF34D399);
  static const Color negative = Color(0xFFFF7C5B);

  static InputDecoration inputDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.24)),
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: WalletUi.accent),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: WalletUi.negative),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: WalletUi.negative),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }
}

class WalletDarkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const WalletDarkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WalletUi.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 42,
            offset: Offset(0, 18),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class WalletHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget? trailing;

  const WalletHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 14,
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        ...(trailing == null ? const <Widget>[] : <Widget>[trailing!]),
      ],
    );
  }
}

class WalletSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const WalletSectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        ...(trailing == null ? const <Widget>[] : <Widget>[trailing!]),
      ],
    );
  }
}

class WalletChoicePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const WalletChoicePill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? Colors.black
                  : Colors.white.withValues(alpha: 0.62),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class WalletBanner extends StatelessWidget {
  final String message;
  final bool error;
  final String? actionLabel;
  final VoidCallback? onAction;

  const WalletBanner({
    super.key,
    required this.message,
    this.error = true,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: error
            ? const Color(0xFF26100D)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: error
              ? const Color(0x44FF7C5B)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: error
                    ? const Color(0xFFFFB49C)
                    : Colors.white.withValues(alpha: 0.72),
                height: 1.45,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class WalletPreviewBanner extends StatelessWidget {
  final String title;
  final String label;
  final String message;

  const WalletPreviewBanner({
    super.key,
    required this.title,
    required this.label,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2612),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x66F4C95D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF7DFA3),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x66F4C95D)),
                ),
                child: const Text(
                  '仅供参考',
                  style: TextStyle(
                    color: Color(0xFFF7DFA3),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFFFBE7B6),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class WalletActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const WalletActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Icon(icon, color: WalletUi.accent),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WalletTokenAvatar extends StatelessWidget {
  final String label;
  final Color color;
  final String? badge;

  const WalletTokenAvatar({
    super.key,
    required this.label,
    required this.color,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, Colors.black.withValues(alpha: 0.92)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              left: -3,
              bottom: -3,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDE047),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WalletTokenRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final String value;
  final String delta;
  final bool positive;
  final Color color;
  final String avatar;
  final String? badge;

  const WalletTokenRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.value,
    required this.delta,
    required this.positive,
    required this.color,
    required this.avatar,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        WalletTokenAvatar(label: avatar, color: color, badge: badge),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              delta,
              style: TextStyle(
                color: positive ? WalletUi.positive : WalletUi.negative,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class WalletMarketRow extends StatelessWidget {
  final String rank;
  final String name;
  final String subtitle;
  final String price;
  final String change;
  final Color color;
  final String avatar;

  const WalletMarketRow({
    super.key,
    required this.rank,
    required this.name,
    required this.subtitle,
    required this.price,
    required this.change,
    required this.color,
    required this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    return WalletTokenRow(
      name: name,
      subtitle: subtitle,
      value: price,
      delta: change,
      positive: true,
      color: color,
      avatar: avatar,
      badge: rank,
    );
  }
}

class WalletBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const WalletBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: WalletUi.panel,
        borderRadius: BorderRadius.circular(28),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: WalletUi.accent,
        unselectedItemColor: Colors.white38,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '首页'),
          BottomNavigationBarItem(
            icon: Icon(Icons.sync_alt_rounded),
            label: '兑换',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

String walletShortAddress(String value, {int prefix = 6, int suffix = 4}) {
  if (value.length <= prefix + suffix + 3) {
    return value;
  }

  return '${value.substring(0, prefix)}...${value.substring(value.length - suffix)}';
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/wallet_models.dart';
import '../providers/wallet_provider.dart';
import '../widgets/wallet_ui.dart';
import 'wallet_dashboard_page.dart';

class ImportWalletPage extends StatefulWidget {
  const ImportWalletPage({super.key});

  @override
  State<ImportWalletPage> createState() => _ImportWalletPageState();
}

class _ImportWalletPageState extends State<ImportWalletPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dataController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  SignatureScheme _signatureScheme = SignatureScheme.secp256k1;
  WalletImportMode _importMode = WalletImportMode.privateKey;

  @override
  void dispose() {
    _nameController.dispose();
    _dataController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNative = _signatureScheme == SignatureScheme.ed25519;
    final inputLabel = isNative
        ? '原生私钥'
        : _importMode == WalletImportMode.mnemonic
        ? '助记词'
        : '私钥';
    final inputHint = isNative
        ? '输入 32 字节 hex 私钥'
        : _importMode == WalletImportMode.mnemonic
        ? '输入 BIP39 助记词'
        : '输入 32 字节 hex 私钥';

    return Scaffold(
      backgroundColor: WalletUi.background,
      body: SafeArea(
        child: Consumer<WalletProvider>(
          builder: (context, provider, _) {
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Row(
                    children: [
                      _BackButton(onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@ZeroWallet',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '导入钱包',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  WalletDarkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '导入模式',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            children: [
                              WalletChoicePill(
                                label: 'EVM',
                                active: !isNative,
                                onTap: () => setState(
                                  () => _signatureScheme =
                                      SignatureScheme.secp256k1,
                                ),
                              ),
                              WalletChoicePill(
                                label: '原生',
                                active: isNative,
                                onTap: () => setState(() {
                                  _signatureScheme = SignatureScheme.ed25519;
                                  _importMode = WalletImportMode.privateKey;
                                }),
                              ),
                            ],
                          ),
                        ),
                        if (!isNative) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              children: [
                                WalletChoicePill(
                                  label: '私钥',
                                  active:
                                      _importMode ==
                                      WalletImportMode.privateKey,
                                  onTap: () => setState(
                                    () => _importMode =
                                        WalletImportMode.privateKey,
                                  ),
                                ),
                                WalletChoicePill(
                                  label: '助记词',
                                  active:
                                      _importMode == WalletImportMode.mnemonic,
                                  onTap: () => setState(
                                    () =>
                                        _importMode = WalletImportMode.mnemonic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  WalletDarkCard(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: WalletUi.inputDecoration(
                            label: '账户名称',
                            hint: isNative ? 'native-1' : 'evm-1',
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                              color: Colors.white54,
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return '请输入账户名称';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _dataController,
                          style: const TextStyle(color: Colors.white),
                          maxLines:
                              isNative ||
                                  _importMode == WalletImportMode.privateKey
                              ? 3
                              : 4,
                          decoration: WalletUi.inputDecoration(
                            label: inputLabel,
                            hint: inputHint,
                            prefixIcon: const Icon(
                              Icons.vpn_key_outlined,
                              color: Colors.white54,
                            ),
                            alignLabelWithHint: true,
                          ),
                          validator: (value) {
                            final input = (value ?? '').trim();
                            if (input.isEmpty) {
                              return '请输入$inputLabel';
                            }
                            if (isNative ||
                                _importMode == WalletImportMode.privateKey) {
                              final normalized = input.startsWith('0x')
                                  ? input.substring(2)
                                  : input;
                              if (!RegExp(
                                r'^[a-fA-F0-9]{64}$',
                              ).hasMatch(normalized)) {
                                return '私钥必须是 32 字节 hex';
                              }
                              return null;
                            }
                            final words = input.split(RegExp(r'\s+'));
                            if (![12, 15, 18, 21, 24].contains(words.length)) {
                              return '助记词词数应为 12 / 15 / 18 / 21 / 24';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: WalletUi.inputDecoration(
                            label: '钱包密码',
                            hint: '输入钱包密码',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.white54,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return '请输入钱包密码';
                            }
                            if ((value ?? '').length < 8) {
                              return '密码至少 8 位';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: WalletUi.inputDecoration(
                            label: '确认密码',
                            hint: '再次输入密码',
                            prefixIcon: const Icon(
                              Icons.lock_reset_rounded,
                              color: Colors.white54,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return '请确认密码';
                            }
                            if (value != _passwordController.text) {
                              return '两次密码不一致';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: provider.isLoading
                                ? null
                                : _importWallet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: WalletUi.lime,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: provider.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    '导入钱包',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((provider.error ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    WalletBanner(message: provider.error!, error: true),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _importWallet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<WalletProvider>();
    final result = await provider.importWallet(
      name: _nameController.text.trim(),
      data: _dataController.text.trim(),
      password: _passwordController.text,
      importMode: _signatureScheme == SignatureScheme.ed25519
          ? WalletImportMode.privateKey
          : _importMode,
      signatureScheme: _signatureScheme,
    );

    if (!mounted) {
      return;
    }

    if (!result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error ?? '导入钱包失败')));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('钱包导入成功')));

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WalletDashboardPage()),
      (route) => false,
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ),
    );
  }
}

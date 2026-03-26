import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/compute_tx.dart';
import '../providers/wallet_provider.dart';
import '../widgets/wallet_ui.dart';

class SendPaymentPage extends StatefulWidget {
  final String? initialTo;
  final String? initialAmount;

  const SendPaymentPage({super.key, this.initialTo, this.initialAmount});

  @override
  State<SendPaymentPage> createState() => _SendPaymentPageState();
}

class _SendPaymentPageState extends State<SendPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _computeJsonController = TextEditingController();
  bool _obscurePassword = true;
  String? _computeResult;

  @override
  void dispose() {
    _passwordController.dispose();
    _computeJsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, _) {
        final account = provider.currentAccount;
        final template = ComputeTx.prettyTemplate(
          publicKey: account?.publicKey ?? '',
          chainId: provider.currentNetwork.chainId,
          networkId: provider.currentNetwork.networkId,
        );

        if (_computeJsonController.text.isEmpty) {
          _computeJsonController.text = template;
        }

        return Scaffold(
          backgroundColor: WalletUi.background,
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Row(
                    children: [
                      _BackButton(onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@${account?.name ?? 'ZeroWallet'}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                            const Text(
                              'Compute 交易',
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
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if ((provider.error ?? '').isNotEmpty) ...[
                    WalletBanner(message: provider.error!, error: true),
                    const SizedBox(height: 16),
                  ],
                  WalletDarkCard(
                    child: Column(
                      children: [
                        _SwapPanel(
                          title: '支付',
                          badge: 'COMPUTE',
                          bigChild: const Text(
                            '0',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          trailingLabel: 'compute signing preimage',
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
                          title: '交易内容',
                          badge: 'COMPUTE',
                          bigChild: TextFormField(
                            controller: _computeJsonController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.5,
                            ),
                            maxLines: 10,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '{ ... }',
                              hintStyle: TextStyle(color: Colors.white24),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return '请输入 Compute 交易 JSON';
                              }
                              try {
                                jsonDecode((value ?? '').trim());
                              } catch (_) {
                                return 'Compute 交易 JSON 无法解析';
                              }
                              return null;
                            },
                          ),
                          trailingLabel: '下方密码用于签名 simulate / submit',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: WalletUi.inputDecoration(
                      label: '钱包密码',
                      hint: '输入密码以签名',
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
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: provider.isLoading
                              ? null
                              : () async {
                                  _computeJsonController.text = template;
                                },
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
                          icon: const Icon(Icons.data_object_rounded),
                          label: const Text(
                            '填充模板',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: provider.isLoading ? null : _simulateCompute,
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
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text(
                            '模拟',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : _submitCompute,
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
                              '签名并提交',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                  if ((_computeResult ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    WalletDarkCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                '执行结果',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: _computeResult!),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('结果已复制')),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text('复制'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: SelectableText(
                              _computeResult!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _simulateCompute() async {
    await _runCompute(submit: false);
  }

  Future<void> _submitCompute() async {
    await _runCompute(submit: true);
  }

  Future<void> _runCompute({required bool submit}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<WalletProvider>();
    final result = submit
        ? await provider.submitComputeTx(
            jsonText: _computeJsonController.text.trim(),
            password: _passwordController.text,
          )
        : await provider.simulateComputeTx(
            jsonText: _computeJsonController.text.trim(),
            password: _passwordController.text,
          );

    if (!mounted) {
      return;
    }

    if (!result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error ?? 'Compute 交易失败')));
      return;
    }

    final pretty = const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'signedTx': result.signedTx,
      'result': result.result,
    });
    setState(() {
      _computeResult = pretty;
    });
  }
}

class _SwapPanel extends StatelessWidget {
  final String title;
  final String badge;
  final Widget bigChild;
  final String trailingLabel;

  const _SwapPanel({
    required this.title,
    required this.badge,
    required this.bigChild,
    required this.trailingLabel,
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
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          bigChild,
          const SizedBox(height: 10),
          Text(
            trailingLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
        ],
      ),
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

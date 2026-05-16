import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_state.dart';
import '../../core/config/business_config_provider.dart';
import '../../core/widgets/business_logo.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController(text: 'admin');
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(_userCtrl.text.trim(), _passCtrl.text);
    } catch (e) {
      setState(() => _error = 'İstifadəçi adı və ya şifrə yanlışdır');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final biz = ref.watch(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.8),
                  radius: 1.2,
                  colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.bg],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const BusinessLogo(size: 72),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(biz.name, style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
                    if (biz.tagline.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(biz.tagline, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                    ] else ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text('Point of Sale', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    const SizedBox(height: AppSpacing.xxxl),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Daxil ol', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: AppSpacing.xxl),
                            AppTextField(
                              controller: _userCtrl,
                              label: 'İstifadəçi adı',
                              hint: 'admin',
                              prefixIcon: Icons.person_outline,
                              autofocus: true,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: _passCtrl,
                              label: 'Şifrə',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscure,
                              onSubmitted: (_) => _submit(),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                child: Text(_obscure ? 'Şifrəni göstər' : 'Gizlət'),
                              ),
                            ),
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerSoft,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            FilledButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Daxil ol'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Demo: admin / admin  •  kassir / kassir',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

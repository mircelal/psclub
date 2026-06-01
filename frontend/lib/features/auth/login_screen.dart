import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/feedback/app_feedback.dart';
import '../../core/config/business_config_provider.dart';
import '../../core/widgets/business_logo.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/widgets/app_dialog.dart';

/// Giriş ekranı — həmişə yüksək kontrastlı brend fon + ağ forma kartı.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!kIsWeb) await AppFeedback.unlock();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(_userCtrl.text.trim(), _passCtrl.text);
      if (!kIsWeb) AppFeedback.success();
    } on DioException catch (e) {
      final msg = e.response?.data;
      if (msg is Map && msg['message'] != null) {
        setState(() => _error = msg['message'].toString());
      } else if (e.type == DioExceptionType.connectionError) {
        setState(() => _error = 'Serverə qoşulmaq olmur (CORS və ya API URL)');
      } else {
        setState(() => _error = e.message ?? 'Giriş uğursuz oldu');
      }
    } catch (e) {
      setState(() => _error = ApiClient.messageFromError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final biz = ref.watch(businessConfigProvider.select((a) => a.valueOrNull)) ?? BusinessConfig.fallback;

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BrandColors.navyDark,
                BrandColors.navy,
                Color(0xFF0A3270),
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                      const BusinessLogo(size: 72),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        biz.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: BrandColors.textOnNavy,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        biz.tagline.isNotEmpty ? biz.tagline : 'Point of Sale',
                        style: TextStyle(
                          fontSize: 14,
                          color: BrandColors.textOnNavy.withValues(alpha: 0.75),
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                          border: Border.all(color: BrandColors.skyLight),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Daxil ol',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: BrandColors.navy,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxl),
                              AppTextField(
                                controller: _userCtrl,
                                label: 'İstifadəçi adı',
                                prefixIcon: Icons.person_outline,
                                autofocus: !kIsWeb,
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
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 18),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                              ],
                              FilledButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Daxil ol'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

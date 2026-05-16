import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

const String kAppDisplayName = 'PS Club POS';
const String kAppVersion = '1.0.0';
const String kDeveloperName = 'MirTech';
const String kDeveloperUrl = 'https://mirtech.az';

Future<void> openMirTechWebsite() async {
  final uri = Uri.parse(kDeveloperUrl);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw Exception('Brauzer açıla bilmədi');
  }
}

void showAppAboutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const _AboutDialog(),
  );
}

/// Parametrlər ekranında göstərilən "Program haqqında" bloku.
class AboutAppSection extends StatelessWidget {
  const AboutAppSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Program haqqında', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.lg),
          const AboutAppContent(),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => showAppAboutDialog(context),
            icon: const Icon(Icons.info_outline, size: 18),
            label: const Text('Ətraflı məlumat'),
          ),
        ],
      ),
    );
  }
}

class AboutAppContent extends StatelessWidget {
  const AboutAppContent({super.key, this.centered = false});

  final bool centered;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final align = centered ? TextAlign.center : TextAlign.start;
    final cross = centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: cross,
      children: [
        if (centered)
          Image.asset('assets/icons/app_icon.png', width: 56, height: 56),
        if (centered) const SizedBox(height: AppSpacing.md),
        Text(
          kAppDisplayName,
          textAlign: align,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Versiya $kAppVersion',
          textAlign: align,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'PlayStation klubu üçün kassir və idarəetmə sistemi.',
          textAlign: align,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Bu proqram $kDeveloperName şirkəti tərəfindən hazırlanıb.',
          textAlign: align,
          style: TextStyle(color: p.textSecondary, height: 1.45),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: _MirTechLink(),
        ),
      ],
    );
  }
}

class _MirTechLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        try {
          await openMirTechWebsite();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Link açılmadı: $e')),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'mirtech.az',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.open_in_new, size: 14, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Program haqqında', style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const AboutAppContent(centered: true),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Bağla'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        try {
                          await openMirTechWebsite();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Link açılmadı: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.language, size: 18),
                      label: const Text('Sayt'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '© ${DateTime.now().year} $kDeveloperName',
                style: TextStyle(fontSize: 11, color: p.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

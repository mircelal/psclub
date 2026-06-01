import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/about/app_about.dart';
import '../../core/config/business_config_provider.dart';
import '../../core/config/media_url.dart';
import '../../core/config/venue_labels.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/kiosk_settings_tiles.dart';
import '../../core/settings/ui_settings_sheet.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/multipart_file_helper.dart';
import '../../core/widgets/business_logo.dart';
import '../../services/pos_service.dart';
import 'widgets/admin_page_layout.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Map<String, dynamic>? _data;
  String _billingMode = 'per_minute';
  String _venueType = 'gaming';
  bool _timeBillingEnabled = true;
  final _minOpenCtrl = TextEditingController(text: '60');
  final _extendStepCtrl = TextEditingController(text: '30');
  final _minBillingCtrl = TextEditingController(text: '60');
  final _billingIncCtrl = TextEditingController(text: '30');
  final _billingGraceCtrl = TextEditingController(text: '10');
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _headerCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  String? _logoUrl;
  String? _localLogoPath;
  Uint8List? _localLogoBytes;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    _minOpenCtrl.dispose();
    _extendStepCtrl.dispose();
    _minBillingCtrl.dispose();
    _billingIncCtrl.dispose();
    _billingGraceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _data = await ref.read(posServiceProvider).getSettings();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
      }
      return;
    }
    final biz = _data!['business'] as Map<String, dynamic>;
    _nameCtrl.text = biz['name']?.toString() ?? '';
    _taglineCtrl.text = biz['tagline']?.toString() ?? '';
    _billingMode = biz['billing_mode'] as String? ?? 'per_minute';
    _venueType = biz['venue_type']?.toString() ?? 'gaming';
    final tb = biz['time_billing_enabled'];
    _timeBillingEnabled = tb == null || tb == true || tb == 1 || tb == '1';
    _minOpenCtrl.text = '${biz['min_open_minutes'] ?? 60}';
    _extendStepCtrl.text = '${biz['extend_step_minutes'] ?? 30}';
    _minBillingCtrl.text = '${biz['min_billing_minutes'] ?? 60}';
    _billingIncCtrl.text = '${biz['billing_increment_minutes'] ?? 30}';
    _billingGraceCtrl.text = '${biz['billing_grace_minutes'] ?? 10}';
    _logoUrl = MediaUrl.resolve(biz['logo_url']?.toString());
    _localLogoPath = null;
    _localLogoBytes = null;
    final settings = _data!['settings'] as Map<String, dynamic>? ?? {};
    _headerCtrl.text = settings['receipt_header']?.toString() ?? _nameCtrl.text;
    _footerCtrl.text = settings['receipt_footer']?.toString() ?? '';
    setState(() => _loading = false);
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final multipart = await multipartFromPlatformFile(file, fallbackName: 'logo.png');
    if (multipart == null) {
      if (mounted) {
        showAppSnackBar(context, 'Şəkil oxunmadı — başqa fayl seçin', isError: true);
      }
      return;
    }

    setState(() {
      _localLogoPath = kIsWeb ? null : file.path;
      _localLogoBytes = file.bytes;
    });

    try {
      final url = await ref.read(posServiceProvider).uploadBusinessLogoMultipart(multipart);
      setState(() {
        _logoUrl = MediaUrl.resolve(url);
        _localLogoPath = null;
        _localLogoBytes = null;
      });
      ref.invalidate(businessConfigProvider);
      if (mounted) showAppSnackBar(context, 'Logo yükləndi');
    } catch (e) {
      if (mounted) {
        setState(() {
          _localLogoPath = null;
          _localLogoBytes = null;
        });
        showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
      }
    }
  }

  Widget _logoPreview() {
    if (_localLogoBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Image.memory(_localLogoBytes!, width: 72, height: 72, fit: BoxFit.cover),
      );
    }
    if (_localLogoPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Image.file(File(_localLogoPath!), width: 72, height: 72, fit: BoxFit.cover),
      );
    }
    final url = MediaUrl.resolve(_logoUrl);
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Image.network(
          url,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const BusinessLogo(size: 72),
        ),
      );
    }
    return const BusinessLogo(size: 72);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(posServiceProvider).updateSettings({
      'business': {
        'name': _nameCtrl.text.trim(),
        'tagline': _taglineCtrl.text.trim(),
        'venue_type': _venueType,
        'billing_mode': _billingMode,
        'time_billing_enabled': _timeBillingEnabled,
        'min_open_minutes': int.tryParse(_minOpenCtrl.text.trim()) ?? 60,
        'extend_step_minutes': int.tryParse(_extendStepCtrl.text.trim()) ?? 30,
        'min_billing_minutes': int.tryParse(_minBillingCtrl.text.trim()) ?? 60,
        'billing_increment_minutes': int.tryParse(_billingIncCtrl.text.trim()) ?? 30,
        'billing_grace_minutes': int.tryParse(_billingGraceCtrl.text.trim()) ?? 10,
        if (_logoUrl != null) 'logo_url': _logoUrl,
      },
      'settings': {
        'receipt_header': _headerCtrl.text.trim().isEmpty ? _nameCtrl.text.trim() : _headerCtrl.text.trim(),
        'receipt_footer': _footerCtrl.text.trim(),
      },
      });
      ref.invalidate(businessConfigProvider);
      if (mounted) showAppSnackBar(context, 'Parametrlər saxlanıldı');
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    final labels = VenueLabels.fromType(_venueType);

    return AdminPageLayout(
      title: 'Parametrlər',
      subtitle: _nameCtrl.text.isEmpty ? 'Müəssisə' : _nameCtrl.text,
      action: FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Saxla'),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsSection(
              title: 'Müəssisə brendi',
              subtitle: 'Ad, logo və müəssisə tipi — bütün proqramda görünür',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _logoPreview(),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickLogo,
                          icon: const Icon(Icons.upload, size: 18),
                          label: const Text('Logo yüklə'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Müəssisə adı', hintText: 'PS Club, Cafe Milano...'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _taglineCtrl,
                    decoration: const InputDecoration(labelText: 'Qısa slogan (istəyə bağlı)'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Müəssisə tipi', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: _venueType,
                    decoration: const InputDecoration(hintText: 'Tip seçin'),
                    items: VenueLabels.venueTypes
                        .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                        .toList(),
                    onChanged: (v) => setState(() => _venueType = v ?? 'gaming'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'UI: "${labels.unitPlural}" • ${labels.rateLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SettingsSection(
              title: 'Hesablama',
              subtitle: 'Vaxt və məhsul — restoran üçün yalnız məhsul da mümkündür',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Vaxt üzrə hesablama'),
                    subtitle: const Text('Söndürülərsə yalnız məhsul satışı sayılır (restoran rejimi)'),
                    value: _timeBillingEnabled,
                    onChanged: (v) => setState(() => _timeBillingEnabled = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Tarif rejimi', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      ChoiceChip(
                        label: const Text('Dəqiqəlik'),
                        selected: _billingMode == 'per_minute',
                        onSelected: (_) => setState(() => _billingMode = 'per_minute'),
                      ),
                      ChoiceChip(
                        label: const Text('30 dəq blok'),
                        selected: _billingMode == 'block_30',
                        onSelected: (_) => setState(() => _billingMode = 'block_30'),
                      ),
                      ChoiceChip(
                        label: const Text('1 saat blok'),
                        selected: _billingMode == 'block_60',
                        onSelected: (_) => setState(() => _billingMode = 'block_60'),
                      ),
                      ChoiceChip(
                        label: const Text('Min 1 saat + 30 dəq'),
                        selected: _billingMode == 'min_1h_then_30',
                        onSelected: (_) => setState(() => _billingMode = 'min_1h_then_30'),
                      ),
                    ],
                  ),
                  if (_billingMode == 'min_1h_then_30') ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'İlk ${_minBillingCtrl.text} dəq minimum hesablanır (qısa qalma da daxil). '
                      'Sonra hər ${_billingIncCtrl.text} dəq blok; ilk saatdan sonra ${_billingGraceCtrl.text} dəqə qədər '
                      'əlavə vaxt pulsuz sayılır (məs. 1 saat 9 dəq = 1 saat).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text('Masa açılışı və uzatma', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minOpenCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min. açılış (dəq)',
                            helperText: 'Müddətli açılış minimum; sonra uzatma addımı ilə',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _extendStepCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Uzatma addımı (dəq)',
                            helperText: '1 saat bitəndən sonra',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minBillingCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min. hesab (dəq)',
                            helperText: '«Min 1 saat + 30 dəq» rejimi',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _billingIncCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Sonrakı interval (dəq)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_billingMode == 'min_1h_then_30') ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _billingGraceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Güzəşt (dəq)',
                        helperText: 'İlk saatdan sonra — əlavə vaxt hesablanmır',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SettingsSection(
              title: 'Kiosk və Windows',
              subtitle: 'Kassir terminalı — tam ekran və kompüter açılanda avtomatik işə düşmə',
              child: const KioskSettingsTiles(),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SettingsSection(
              title: 'Tətbiq görünüşü',
              subtitle: 'Tema və ${labels.unitPlural.toLowerCase()} paneli',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final ui = ref.watch(appSettingsProvider).valueOrNull;
                      if (ui == null) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Tema', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: AppSpacing.sm),
                          SegmentedButton<AppThemeMode>(
                            segments: const [
                              ButtonSegment(value: AppThemeMode.dark, label: Text('Qaranlıq')),
                              ButtonSegment(value: AppThemeMode.light, label: Text('Aydınlıq')),
                              ButtonSegment(value: AppThemeMode.system, label: Text('Sistem')),
                            ],
                            selected: {ui.themeMode},
                            onSelectionChanged: (v) {
                              final mode = v.first;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                ref.read(appSettingsProvider.notifier).setTheme(mode);
                              });
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text('${labels.unitPlural} görünüşü', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: AppSpacing.sm),
                          SegmentedButton<TableViewMode>(
                            segments: const [
                              ButtonSegment(value: TableViewMode.grid, label: Text('Grid')),
                              ButtonSegment(value: TableViewMode.card, label: Text('Kart')),
                              ButtonSegment(value: TableViewMode.list, label: Text('Listə')),
                            ],
                            selected: {ui.tableViewMode},
                            onSelectionChanged: (v) {
                              final mode = v.first;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                ref.read(appSettingsProvider.notifier).setTableView(mode);
                              });
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => showUiSettingsSheet(context),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Tam görünüş paneli'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SettingsSection(
              title: 'Qəbz parametrləri',
              subtitle: 'Çap olunacaq mətnlər',
              child: Column(
                children: [
                  TextField(controller: _headerCtrl, decoration: const InputDecoration(labelText: 'Qəbz başlığı')),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(controller: _footerCtrl, decoration: const InputDecoration(labelText: 'Alt yazı')),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const AboutAppSection(),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

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
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

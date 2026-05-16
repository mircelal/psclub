import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/about/app_about.dart';
import '../../core/config/business_config_provider.dart';
import '../../core/config/venue_labels.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/desktop_window_service.dart';
import '../../core/settings/kiosk_settings_tiles.dart';
import '../../core/settings/ui_settings_sheet.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_snackbar.dart';
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
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _headerCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  String? _logoUrl;
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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _data = await ref.read(posServiceProvider).getSettings();
    final biz = _data!['business'] as Map<String, dynamic>;
    _nameCtrl.text = biz['name']?.toString() ?? '';
    _taglineCtrl.text = biz['tagline']?.toString() ?? '';
    _billingMode = biz['billing_mode'] as String? ?? 'per_minute';
    _venueType = biz['venue_type']?.toString() ?? 'gaming';
    final tb = biz['time_billing_enabled'];
    _timeBillingEnabled = tb == null || tb == true || tb == 1 || tb == '1';
    _logoUrl = biz['logo_url']?.toString();
    final settings = _data!['settings'] as Map<String, dynamic>? ?? {};
    _headerCtrl.text = settings['receipt_header']?.toString() ?? _nameCtrl.text;
    _footerCtrl.text = settings['receipt_footer']?.toString() ?? '';
    setState(() => _loading = false);
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: false);
    if (result == null || result.files.single.path == null) return;
    try {
      final url = await ref.read(posServiceProvider).uploadBusinessLogo(result.files.single.path!);
      setState(() => _logoUrl = url);
      ref.invalidate(businessConfigProvider);
      if (mounted) showAppSnackBar(context, 'Logo yükləndi');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(posServiceProvider).updateSettings({
      'business': {
        'name': _nameCtrl.text.trim(),
        'tagline': _taglineCtrl.text.trim(),
        'venue_type': _venueType,
        'billing_mode': _billingMode,
        'time_billing_enabled': _timeBillingEnabled,
        if (_logoUrl != null) 'logo_url': _logoUrl,
      },
      'settings': {
        'receipt_header': _headerCtrl.text.trim().isEmpty ? _nameCtrl.text.trim() : _headerCtrl.text.trim(),
        'receipt_footer': _footerCtrl.text.trim(),
      },
    });
    ref.invalidate(businessConfigProvider);
    setState(() => _saving = false);
    if (mounted) showAppSnackBar(context, 'Parametrlər saxlanıldı');
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
                      if (_logoUrl != null && _logoUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          child: Image.network(_logoUrl!, width: 72, height: 72, fit: BoxFit.cover),
                        )
                      else
                        const BusinessLogo(size: 72),
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
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'per_minute', label: Text('Dəqiqəlik')),
                      ButtonSegment(value: 'block_30', label: Text('30 dəq')),
                      ButtonSegment(value: 'block_60', label: Text('1 saat')),
                    ],
                    selected: {_billingMode},
                    onSelectionChanged: (s) => setState(() => _billingMode = s.first),
                  ),
                ],
              ),
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
            if (DesktopWindowService.isDesktop) ...[
              const SizedBox(height: AppSpacing.xxl),
              _SettingsSection(
                title: 'Kiosk və Windows',
                subtitle: 'Kassir terminalı üçün tam ekran və avtomatik işə düşmə',
                child: const KioskSettingsTiles(),
              ),
            ],
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

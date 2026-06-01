import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/business_config_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/utils/table_tariff_utils.dart';
import '../../../core/widgets/customer_picker.dart';
import '../../../services/pos_service.dart';
import '../../../core/billing/effective_tariff_quote.dart';

enum _OpenMode { open, timed, set }

class OpenTableResult {
  OpenTableResult({
    required this.confirmed,
    this.plannedMinutes,
    this.tariffId,
    this.setId,
    this.customerId,
  });

  final bool confirmed;
  final int? plannedMinutes;
  final int? tariffId;
  final int? setId;
  final int? customerId;
}

Future<OpenTableResult?> showOpenTableDialog(BuildContext context, Map<String, dynamic> table) {
  return showDialog<OpenTableResult>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Masa aç', style: Theme.of(ctx).textTheme.titleLarge),
              Text(table['name'] as String? ?? '', style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              Flexible(child: SingleChildScrollView(child: _OpenTableBody(table: table))),
            ],
          ),
        ),
      ),
    ),
  );
}

class _OpenTableBody extends ConsumerStatefulWidget {
  const _OpenTableBody({required this.table});

  final Map<String, dynamic> table;

  @override
  ConsumerState<_OpenTableBody> createState() => _OpenTableBodyState();
}

class _OpenTableBodyState extends ConsumerState<_OpenTableBody> {
  _OpenMode _mode = _OpenMode.open;
  int _plannedMinutes = 60;
  late final List<TableTariff> _tariffs;
  int? _selectedTariffId;
  int? _selectedSetId;
  int? _customerId;
  Map<String, dynamic>? _selectedCustomer;
  final _manualMinutesCtrl = TextEditingController();
  bool _useManualMinutes = false;

  @override
  void initState() {
    super.initState();
    _tariffs = parseTableTariffs(widget.table);
    if (_tariffs.length == 1) {
      _selectedTariffId = _tariffs.first.id;
    }
    final config = ref.read(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;
    _plannedMinutes = config.minOpenMinutes;
    _manualMinutesCtrl.text = '${config.minOpenMinutes}';
  }

  @override
  void dispose() {
    _manualMinutesCtrl.dispose();
    super.dispose();
  }

  int? _resolvedTimedMinutes(BusinessConfig config) {
    if (!_useManualMinutes) return _plannedMinutes;
    final parsed = int.tryParse(_manualMinutesCtrl.text.trim());
    if (parsed == null) return null;
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;
    final presets = config.timedOpenPresets;
    final setsAsync = ref.watch(sessionSetsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_mode != _OpenMode.set && _tariffs.isNotEmpty) ...[
          Text('Tarif / cihaz', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          if (_tariffs.length > 1)
            ..._tariffs.map((t) => _TariffTile(
                  tariff: t,
                  selected: _selectedTariffId == t.id,
                  onTap: () => setState(() => _selectedTariffId = t.id),
                  selectedCustomer: _selectedCustomer,
                ))
          else
            _TariffTile(
              tariff: _tariffs.first,
              selected: true,
              onTap: () {},
              selectedCustomer: _selectedCustomer,
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
        SegmentedButton<_OpenMode>(
          segments: const [
            ButtonSegment(value: _OpenMode.open, label: Text('Açıq'), icon: Icon(Icons.timer_outlined, size: 18)),
            ButtonSegment(value: _OpenMode.timed, label: Text('Müddət'), icon: Icon(Icons.hourglass_bottom, size: 18)),
            ButtonSegment(value: _OpenMode.set, label: Text('Paket'), icon: Icon(Icons.restaurant, size: 18)),
          ],
          selected: {_mode},
          onSelectionChanged: (v) => setState(() => _mode = v.first),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_mode == _OpenMode.timed) ...[
          Text('Müddət seçin', style: theme.textTheme.titleSmall),
          Text(
            'Min ${config.minOpenMinutes} dəq · addım ${config.extendStepMinutes} dəq · max 3 saat',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Builder(
            builder: (context) {
              final selectedM = _resolvedTimedMinutes(config);
              final valid = selectedM != null && config.isValidTimedOpenMinutes(selectedM);
              if (!valid) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Seçildi: ${_presetLabel(selectedM)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((m) {
              final selected = !_useManualMinutes && _plannedMinutes == m;
              final labelColor = selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface;
              return ChoiceChip(
                label: Text(
                  _presetLabel(m),
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                showCheckmark: false,
                selected: selected,
                selectedColor: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                side: BorderSide(
                  color: selected ? theme.colorScheme.primary : theme.dividerColor,
                  width: selected ? 1.5 : 1,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                onSelected: (_) => setState(() {
                  _useManualMinutes = false;
                  _plannedMinutes = m;
                  _manualMinutesCtrl.text = '$m';
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _manualMinutesCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Əl ilə (dəqiqə)',
              helperText:
                  '${config.minOpenMinutes}–${BusinessConfig.maxTimedOpenMinutes} dəq, addım ${config.extendStepMinutes}',
              errorText: _useManualMinutes &&
                      _resolvedTimedMinutes(config) != null &&
                      !config.isValidTimedOpenMinutes(_resolvedTimedMinutes(config)!)
                  ? '${config.minOpenMinutes}–${BusinessConfig.maxTimedOpenMinutes} dəq, ${config.extendStepMinutes} dəq addım'
                  : null,
            ),
            onChanged: (_) => setState(() => _useManualMinutes = true),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Geri sayım bitəndə masa aktiv qalır; uzatma ${config.extendStepMinutes} dəq addımlarla mümkündür.',
            style: theme.textTheme.bodySmall,
          ),
        ] else if (_mode == _OpenMode.set)
          setsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text('Paketlər yüklənmədi: $e'),
            data: (sets) {
              if (sets.isEmpty) {
                return Text(
                  'Paket yoxdur. Admin panelindən Setlər bölməsində əlavə edin.',
                  style: theme.textTheme.bodySmall,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Paket seçin', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  ...sets.map((raw) {
                    final s = raw as Map<String, dynamic>;
                    final id = jsonToInt(s['id']);
                    final items = (s['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
                    final minutes = jsonToIntOrNull(s['planned_minutes']);
                    final price = jsonToDouble(s['fixed_price']);
                    final itemSummary = items.map((i) {
                      final q = jsonToInt(i['quantity'], 1);
                      final name = i['product_name'] as String? ?? '';
                      return q > 1 ? '$name ×$q' : name;
                    }).join(', ');

                    return _SetTile(
                      name: s['name'] as String? ?? '',
                      subtitle: [
                        if (minutes != null && minutes > 0) _presetLabel(minutes),
                        '${price.toStringAsFixed(2)} ₼',
                        if (itemSummary.isNotEmpty) itemSummary,
                      ].join(' · '),
                      selected: _selectedSetId == id,
                      onTap: () => setState(() => _selectedSetId = id),
                    );
                  }),
                ],
              );
            },
          )
        else
          Text(
            'Müddətsiz — məbləğ seçilmiş tarif rejiminə görə hesablanır.',
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: AppSpacing.lg),
        CustomerPicker(
          pos: ref.read(posServiceProvider),
          selectedId: _customerId,
          onChanged: (id) => setState(() => _customerId = id),
          onCustomerDetailChanged: (c) => setState(() => _selectedCustomer = c),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Ləğv'))),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: _canConfirm ? _confirm : null,
                child: const Text('Masa aç'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _presetLabel(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final rem = minutes % 60;
      if (rem == 0) {
        return h == 1 ? '1 saat' : '$h saat';
      }
      final hourPart = h == 1 ? '1 saat' : '$h saat';
      return '$hourPart $rem dəq';
    }
    return '$minutes dəq';
  }

  bool get _canConfirm {
    if (_mode != _OpenMode.set && _tariffs.length > 1 && _selectedTariffId == null) return false;
    if (_mode == _OpenMode.set && _selectedSetId == null) return false;
    if (_mode == _OpenMode.timed) {
      final config = ref.read(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;
      final m = _resolvedTimedMinutes(config);
      if (m == null || !config.isValidTimedOpenMinutes(m)) return false;
    }
    return true;
  }

  void _confirm() {
    int? minutes;
    int? setId;
    switch (_mode) {
      case _OpenMode.timed:
        final config = ref.read(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;
        minutes = _resolvedTimedMinutes(config);
      case _OpenMode.set:
        setId = _selectedSetId;
      case _OpenMode.open:
        break;
    }

    final tariffId = _mode == _OpenMode.set
        ? null
        : (_tariffs.length <= 1 ? (_tariffs.isNotEmpty ? _tariffs.first.id : null) : _selectedTariffId);

    Navigator.pop(
      context,
      OpenTableResult(
        confirmed: true,
        plannedMinutes: minutes,
        tariffId: tariffId,
        setId: setId,
        customerId: _customerId,
      ),
    );
  }
}

class _TariffTile extends ConsumerWidget {
  const _TariffTile({
    required this.tariff,
    required this.selected,
    required this.onTap,
    this.selectedCustomer,
  });

  final TableTariff tariff;
  final bool selected;
  final VoidCallback onTap;
  final Map<String, dynamic>? selectedCustomer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final promos = ref.watch(activePromotionsProvider).valueOrNull ?? [];
    final quote = quoteHourlyForTariff(
      tariffName: tariff.name,
      hourlyRate: tariff.hourlyRate,
      activePromotions: promos,
      customer: selectedCustomer,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35) : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: selected ? theme.colorScheme.primary : theme.dividerColor, width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tariff.name, style: theme.textTheme.titleSmall),
                      if (quote.hasDiscount) ...[
                        Text(
                          quote.effectiveLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF248A3D),
                          ),
                        ),
                        if (quote.savingsLabel != null)
                          Text(
                            quote.savingsLabel!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        if (quote.discountLabel != null)
                          Text(
                            quote.discountLabel!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                      ] else
                        Text(
                          quote.effectiveLabel,
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({required this.name, required this.subtitle, required this.selected, required this.onTap});

  final String name;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.4) : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: selected ? theme.colorScheme.secondary : theme.dividerColor, width: selected ? 1.5 : 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.restaurant_menu, size: 22, color: selected ? theme.colorScheme.secondary : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: theme.colorScheme.secondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

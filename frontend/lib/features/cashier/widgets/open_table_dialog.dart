import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/utils/table_tariff_utils.dart';
import '../../../core/widgets/customer_picker.dart';
import '../../../services/pos_service.dart';

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

  static const _presets = [30, 60, 120];

  @override
  void initState() {
    super.initState();
    _tariffs = parseTableTariffs(widget.table);
    if (_tariffs.length == 1) {
      _selectedTariffId = _tariffs.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setsAsync = ref.watch(sessionSetsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_tariffs.isNotEmpty) ...[
          Text('Tarif / cihaz', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          if (_tariffs.length > 1)
            ..._tariffs.map((t) => _TariffTile(
                  tariff: t,
                  selected: _selectedTariffId == t.id,
                  onTap: () => setState(() => _selectedTariffId = t.id),
                ))
          else
            _TariffTile(tariff: _tariffs.first, selected: true, onTap: () {}),
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
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((m) {
              final selected = _plannedMinutes == m;
              return ChoiceChip(
                label: Text(_presetLabel(m)),
                selected: selected,
                onSelected: (_) => setState(() => _plannedMinutes = m),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Geri sayım bitəndə masa aktiv qalır — kassir bağlamalıdır.',
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
            'Vaxt limitsiz — məbləğ saatlıq tarifə görə hesablanır.',
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: AppSpacing.lg),
        CustomerPicker(
          pos: ref.read(posServiceProvider),
          selectedId: _customerId,
          onChanged: (id) => setState(() => _customerId = id),
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
    if (minutes >= 60 && minutes % 60 == 0) {
      final h = minutes ~/ 60;
      return h == 1 ? '1 saat' : '$h saat';
    }
    return '$minutes dəq';
  }

  bool get _canConfirm {
    if (_tariffs.length > 1 && _selectedTariffId == null) return false;
    if (_mode == _OpenMode.set && _selectedSetId == null) return false;
    return true;
  }

  void _confirm() {
    int? minutes;
    int? setId;
    switch (_mode) {
      case _OpenMode.timed:
        minutes = _plannedMinutes;
      case _OpenMode.set:
        setId = _selectedSetId;
      case _OpenMode.open:
        break;
    }

    Navigator.pop(
      context,
      OpenTableResult(
        confirmed: true,
        plannedMinutes: minutes,
        tariffId: _tariffs.length <= 1 ? (_tariffs.isNotEmpty ? _tariffs.first.id : null) : _selectedTariffId,
        setId: setId,
        customerId: _customerId,
      ),
    );
  }
}

class _TariffTile extends StatelessWidget {
  const _TariffTile({required this.tariff, required this.selected, required this.onTap});

  final TableTariff tariff;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      Text('${tariff.hourlyRate.toStringAsFixed(2)} ₼ / saat', style: theme.textTheme.bodySmall),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/utils/package_session.dart';
import '../../../core/utils/table_tariff_utils.dart';
import '../../../services/pos_service.dart';
import 'table_session_state.dart';

/// `true` — sessiya uğurla köçürüldü.
Future<bool> showSessionTransferDialog({
  required BuildContext context,
  required WidgetRef ref,
  required int sessionId,
  required Map<String, dynamic> session,
  required List<Map<String, dynamic>> allTables,
}) async {
  final sourceTableId = jsonToInt(session['table_id']);
  if (sourceTableId <= 0) return false;

  final emptyTargets = allTables
      .where((t) => TableSessionState.canOpenSession(t) && jsonToInt(t['id']) != sourceTableId)
      .cast<Map<String, dynamic>>()
      .toList();

  if (emptyTargets.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Boş masa yoxdur — köçürmə mümkün deyil')),
      );
    }
    return false;
  }

  final isPackage = sessionHasPackage(session);
  final sourceName = session['table_name'] as String? ?? 'Masa';
  final billPreview = session['bill_preview'] as Map<String, dynamic>?;
  final currentTotal = jsonToDouble(billPreview?['total_amount']);
  final currentRate = jsonToDouble(session['hourly_rate_snapshot']);

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _SessionTransferDialog(
      sessionId: sessionId,
      sourceName: sourceName,
      currentTotal: currentTotal,
      currentRate: currentRate,
      isPackage: isPackage,
      emptyTargets: emptyTargets,
    ),
  );

  return result == true;
}

class _SessionTransferDialog extends ConsumerStatefulWidget {
  const _SessionTransferDialog({
    required this.sessionId,
    required this.sourceName,
    required this.currentTotal,
    required this.currentRate,
    required this.isPackage,
    required this.emptyTargets,
  });

  final int sessionId;
  final String sourceName;
  final double currentTotal;
  final double currentRate;
  final bool isPackage;
  final List<Map<String, dynamic>> emptyTargets;

  @override
  ConsumerState<_SessionTransferDialog> createState() => _SessionTransferDialogState();
}

class _SessionTransferDialogState extends ConsumerState<_SessionTransferDialog> {
  int? _targetTableId;
  String _tariffMode = 'keep';
  int? _selectedTariffId;
  bool _busy = false;

  Map<String, dynamic>? get _selectedTarget {
    if (_targetTableId == null) return null;
    for (final t in widget.emptyTargets) {
      if (jsonToInt(t['id']) == _targetTableId) return t;
    }
    return null;
  }

  List<TableTariff> get _targetTariffs {
    final target = _selectedTarget;
    if (target == null) return [];
    return parseTableTariffs(target);
  }

  bool get _canConfirm {
    if (_targetTableId == null || _busy) return false;
    if (_tariffMode == 'target' && !widget.isPackage) {
      final tariffs = _targetTariffs;
      if (tariffs.length > 1 && _selectedTariffId == null) return false;
    }
    return true;
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _busy = true);
    try {
      final tariffs = _targetTariffs;
      int? tariffId;
      if (_tariffMode == 'target' && !widget.isPackage) {
        if (tariffs.length == 1) {
          tariffId = tariffs.first.id;
        } else {
          tariffId = _selectedTariffId;
        }
      }

      await ref.read(posServiceProvider).transferSession(
            widget.sessionId,
            targetTableId: _targetTableId!,
            tariffMode: widget.isPackage ? 'keep' : _tariffMode,
            tariffId: tariffId,
          );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = _selectedTarget;
    final tariffs = _targetTariffs;

    return AlertDialog(
      title: const Text('Masa köçür'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Mənbə: ${widget.sourceName}',
                style: theme.textTheme.titleSmall,
              ),
              if (widget.currentTotal > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Cari cəmi: ${widget.currentTotal.toStringAsFixed(2)} ₼',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Hədəf masa', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              ...widget.emptyTargets.map((t) {
                final id = jsonToInt(t['id']);
                final name = t['name'] as String? ?? 'Masa #$id';
                final selected = _targetTableId == id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Material(
                    color: selected
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: InkWell(
                      onTap: () => setState(() {
                        _targetTableId = id;
                        _selectedTariffId = null;
                        final list = parseTableTariffs(t);
                        if (list.length == 1) _selectedTariffId = list.first.id;
                      }),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                            color: selected ? theme.colorScheme.primary : theme.dividerColor,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 20,
                              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: theme.textTheme.titleSmall),
                                  Text(
                                    formatTableTariffSummary(t),
                                    style: theme.textTheme.bodySmall,
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
              }),
              if (target != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Vaxt tarifi', style: theme.textTheme.titleSmall),
                if (widget.isPackage) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Paket sessiyası — yalnız cari tarif saxlanır.',
                    style: theme.textTheme.bodySmall,
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'keep',
                        label: Text('Saxla (${widget.currentRate.toStringAsFixed(2)} ₼/saat)'),
                      ),
                      const ButtonSegment(
                        value: 'target',
                        label: Text('Yeni masa tarifi'),
                      ),
                    ],
                    selected: {_tariffMode},
                    onSelectionChanged: (s) => setState(() => _tariffMode = s.first),
                  ),
                  if (_tariffMode == 'target' && tariffs.length > 1) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text('Hədəf masanın tarifi', style: theme.textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    ...tariffs.map((tariff) {
                      final selected = _selectedTariffId == tariff.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Material(
                          color: selected
                              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          child: InkWell(
                            onTap: () => setState(() => _selectedTariffId = tariff.id),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                border: Border.all(
                                  color: selected ? theme.colorScheme.primary : theme.dividerColor,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    size: 20,
                                    color: selected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      '${tariff.name} — ${tariff.hourlyRate.toStringAsFixed(2)} ₼/saat',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Ləğv'),
        ),
        FilledButton(
          onPressed: _canConfirm ? _confirm : null,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  target != null
                      ? '${widget.sourceName} → ${target['name']}'
                      : 'Köçür',
                ),
        ),
      ],
    );
  }
}

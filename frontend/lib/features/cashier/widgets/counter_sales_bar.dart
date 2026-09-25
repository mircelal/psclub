import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';
import '../../../core/utils/json_parse.dart';
import '../open_counter_sessions_provider.dart';

/// Birbaşa satış — masaüstündə əlavə toolbar (mobil/planşetdə top bar + drawer).
class CounterSaleToolbar extends StatelessWidget {
  const CounterSaleToolbar({
    super.key,
    required this.onNewSale,
    this.openSales = const [],
    this.onOpenSale,
    this.compact = false,
  });

  final VoidCallback onNewSale;
  final List<Map<String, dynamic>> openSales;
  final ValueChanged<int>? onOpenSale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasOpen = openSales.isNotEmpty;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.md : AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: CashierTheme.surfaceSecondary(context),
        border: Border(bottom: BorderSide(color: CashierTheme.border(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: onNewSale,
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: Text(compact ? 'Satış' : 'Birbaşa satış'),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 10, compact ? 10 : 14, 10),
                ),
              ),
              if (hasOpen) ...[
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _showOpenList(context),
                  icon: Icon(
                    Icons.pending_actions_outlined,
                    size: 18,
                    color: openSales.any((s) => s['is_stale_counter'] == true)
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  label: Text('Açıq (${openSales.length})'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.fromLTRB(compact ? 10 : 12, 10, compact ? 10 : 12, 10),
                  ),
                ),
              ],
              if (!compact) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    hasOpen
                        ? 'Ödəniş alınmamış açıq satışlar var — siyahıdan açıb bağlayın'
                        : 'Ödəniş alındıqdan sonra satış tamamlanır',
                    style: CashierTheme.caption(context).copyWith(
                      color: hasOpen
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (hasOpen && !compact) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: openSales.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final s = openSales[i];
                  final id = jsonToInt(s['id']);
                  final items = counterSessionItemCount(s);
                  final total = counterSessionPayable(s);
                  final stale = s['is_stale_counter'] == true;
                  return ActionChip(
                    avatar: Icon(
                      stale ? Icons.warning_amber_rounded : Icons.shopping_bag_outlined,
                      size: 16,
                      color: stale ? Theme.of(context).colorScheme.error : null,
                    ),
                    label: Text(
                      '#$id · $items məhsul · ${total.toStringAsFixed(2)} ₼',
                      style: TextStyle(
                        fontSize: 12,
                        color: stale ? Theme.of(context).colorScheme.error : null,
                      ),
                    ),
                    onPressed: onOpenSale == null ? null : () => onOpenSale!(id),
                    side: stale
                        ? BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5))
                        : null,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showOpenList(BuildContext context) async {
    if (onOpenSale == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                'Açıq birbaşa satışlar',
                style: CashierTheme.stationTitle(context, size: 16),
              ),
              const SizedBox(height: 8),
              ...openSales.map((s) {
                final id = jsonToInt(s['id']);
                final items = counterSessionItemCount(s);
                final total = counterSessionPayable(s);
                final stale = s['is_stale_counter'] == true;
                final opened = s['opened_at']?.toString() ?? '';
                return ListTile(
                  leading: Icon(
                    stale ? Icons.warning_amber_rounded : Icons.shopping_bag_outlined,
                    color: stale ? Theme.of(context).colorScheme.error : CashierTheme.accent(context),
                  ),
                  title: Text('Satış #$id'),
                  subtitle: Text(
                    '$items məhsul · ${total.toStringAsFixed(2)} ₼'
                    '${opened.isNotEmpty ? ' · $opened' : ''}'
                    '${stale ? ' · Köhnə / tərk edilmiş' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    onOpenSale!(id);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

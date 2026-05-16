import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/cashier_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../services/pos_service.dart';
import 'audit_labels.dart';
import 'widgets/admin_page_layout.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  List<dynamic> _logs = [];
  bool _loading = true;
  AuditCategory? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _logs = await ref.read(posServiceProvider).getAuditLogs();
    } catch (_) {
      _logs = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _visibleLogs {
    final list = _logs.cast<Map<String, dynamic>>();
    if (_filter == null) return list;
    return list.where((log) => AuditLabels.describe(log).category == _filter).toList();
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('d MMM yyyy, HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleLogs;

    return AdminPageLayout(
      title: 'Əməliyyat jurnalı',
      subtitle:
          'Kim, nə vaxt və nə etdi — satış, kassa, məhsul və parametrlər üzrə son dəyişikliklər',
      action: IconButton(
        onPressed: _loading ? null : _load,
        icon: const Icon(Icons.refresh_rounded),
        tooltip: 'Siyahını yenilə',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.sm),
            child: Text(
              'Burada sistemdə edilən mühüm addımlar göstərilir: hesab bağlanması, kassa, məhsul və işçi dəyişiklikləri.',
              style: CashierTheme.caption(context),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              children: [
                _FilterChip(
                  label: 'Hamısı',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                ...AuditCategory.values.map(
                  (c) => _FilterChip(
                    label: c.label,
                    selected: _filter == c,
                    onTap: () => setState(() => _filter = c),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : visible.isEmpty
                    ? EmptyState(
                        icon: Icons.history_toggle_off_outlined,
                        title: _filter == null ? 'Hələ qeyd yoxdur' : 'Bu filtrdə qeyd tapılmadı',
                        subtitle: _filter == null
                            ? 'Kassir və ya admin əməliyyat etdikcə burada görünəcək'
                            : 'Başqa kateqoriya seçin və ya Hamısına qayıdın',
                      )
                    : ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          scrollbars: true,
                          overscroll: false,
                        ),
                        child: ListView.builder(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xxl,
                            AppSpacing.sm,
                            AppSpacing.xxl,
                            AppSpacing.xxl,
                          ),
                          itemCount: visible.length,
                          itemExtent: null,
                          cacheExtent: 400,
                          itemBuilder: (_, i) {
                            final log = visible[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _AuditLogTile(
                                log: log,
                                entry: AuditLabels.describe(log),
                                timeLabel: _formatTime(log['created_at'] as String?),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({
    required this.log,
    required this.entry,
    required this.timeLabel,
  });

  final Map<String, dynamic> log;
  final AuditEntry entry;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final actor = log['actor_name'] as String? ?? 'Sistem';
    final accent = CashierTheme.accent(context);

    return Material(
      color: CashierTheme.surfaceRaised(context),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
        side: BorderSide(color: CashierTheme.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(entry.category.icon, size: 20, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: CashierTheme.surfaceSecondary(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.category.label,
                          style: CashierTheme.caption(context).copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.title,
                    style: CashierTheme.stationTitle(context, size: 14),
                  ),
                  if (entry.detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.detail!,
                      style: CashierTheme.caption(context).copyWith(
                        color: CashierTheme.textSecondary(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '$actor · $timeLabel',
                    style: CashierTheme.caption(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

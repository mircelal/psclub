import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/pos_service.dart';
import 'widgets/admin_page_layout.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  List<dynamic> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _logs = await ref.read(posServiceProvider).getAuditLogs();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageLayout(
      title: 'Audit jurnalı',
      subtitle: 'Son əməliyyatların izi',
      action: IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Yenilə'),
      child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              itemCount: _logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final log = _logs[i] as Map<String, dynamic>;
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: const Icon(Icons.history, size: 18, color: AppColors.textMuted),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log['action'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${log['actor_name'] ?? 'Sistem'} • ${log['created_at']}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

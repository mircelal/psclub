import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/business_config_provider.dart';
import '../../../core/feedback/app_feedback.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/utils/package_session.dart';
import '../../../services/pos_service.dart';

/// Sessiya və ya masa sətirindən uzatma mümkündürmü (paket/kassa istisna).
/// Planlaşdırılmış müddət (3 saat və s.) düyməni gizlətmir.
bool sessionCanExtendTime(Map<String, dynamic> data, BusinessConfig config) {
  final sessionType = data['session_type'] as String? ?? 'table';
  if (sessionType == 'counter') return false;
  if (sessionPackagePrice(data) > 0 || tablePackagePrice(data) > 0) return false;
  if (!config.timeBillingEnabled) return false;
  return config.extendTimeOptions.isNotEmpty;
}

String sessionExtendDurationLabel(int minutes) {
  if (minutes >= 60) {
    final h = minutes ~/ 60;
    final rem = minutes % 60;
    if (rem == 0) return h == 1 ? '1 saat' : '$h saat';
    final hourPart = h == 1 ? '1 saat' : '$h saat';
    return '$hourPart $rem dəq';
  }
  return '$minutes dəq';
}

/// `true` — uzatma uğurla tətbiq olundu.
Future<bool> showSessionExtendTimeDialog({
  required BuildContext context,
  required WidgetRef ref,
  required int sessionId,
  required Map<String, dynamic> session,
}) async {
  final config = ref.read(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;
  final planned = jsonToIntOrNull(session['planned_minutes']) ?? 0;
  final isOpenSession = planned <= 0;
  final options = config.extendTimeOptions;

  if (options.isEmpty) return false;

  final billPreview = session['bill_preview'] as Map<String, dynamic>?;
  final remainingSec = jsonToIntOrNull(billPreview?['remaining_seconds']);
  final remainingLabel = !isOpenSession && remainingSec != null && remainingSec > 0
      ? ' · qalıq ${sessionExtendDurationLabel((remainingSec / 60).ceil())}'
      : '';

  final chosen = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Vaxt əlavə et'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isOpenSession
                ? 'Açıq sessiya — seçilən vaxt geri sayım limitinə əlavə olunur · addım ${config.extendStepMinutes} dəq'
                : 'Cari plan: ${sessionExtendDurationLabel(planned)}$remainingLabel · addım ${config.extendStepMinutes} dəq',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((m) {
              return ActionChip(
                label: Text('+${sessionExtendDurationLabel(m)}'),
                onPressed: () => Navigator.pop(ctx, m),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ləğv')),
      ],
    ),
  );

  if (chosen == null) return false;

  try {
    await ref.read(posServiceProvider).extendSession(sessionId, addMinutes: chosen);
    AppFeedback.success();
    return true;
  } catch (e) {
    AppFeedback.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    return false;
  }
}

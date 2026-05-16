import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';

class OpenTableResult {
  OpenTableResult({required this.confirmed, this.plannedMinutes});

  final bool confirmed;
  final int? plannedMinutes;
}

Future<OpenTableResult?> showOpenTableDialog(BuildContext context, String tableName) {
  return showDialog<OpenTableResult>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Masa aç', style: Theme.of(ctx).textTheme.titleLarge),
              Text(tableName, style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              _OpenTableBody(tableName: tableName),
            ],
          ),
        ),
      ),
    ),
  );
}

class _OpenTableBody extends StatefulWidget {
  const _OpenTableBody({required this.tableName});

  final String tableName;

  @override
  State<_OpenTableBody> createState() => _OpenTableBodyState();
}

class _OpenTableBodyState extends State<_OpenTableBody> {
  bool _timed = false;
  final _minutesCtrl = TextEditingController(text: '60');

  @override
  void dispose() {
    _minutesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Açıq vaxt'), icon: Icon(Icons.timer_outlined, size: 18)),
            ButtonSegment(value: true, label: Text('Müddətli'), icon: Icon(Icons.hourglass_bottom, size: 18)),
          ],
          selected: {_timed},
          onSelectionChanged: (v) => setState(() => _timed = v.first),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_timed) ...[
          AppTextField(
            controller: _minutesCtrl,
            label: 'Müddət (dəqiqə)',
            hint: '60',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.schedule,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Geri sayım bitəndə masa hələ aktiv qalır — kassir bağlamalıdır.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else
          Text(
            'Timer yuxarıdan işləyəcək, məbləğ paralel hesablanacaq.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Ləğv'))),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  final minutes = _timed ? int.tryParse(_minutesCtrl.text) : null;
                  Navigator.pop(
                    context,
                    OpenTableResult(
                      confirmed: true,
                      plannedMinutes: minutes != null && minutes > 0 ? minutes : null,
                    ),
                  );
                },
                child: const Text('Masa aç'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

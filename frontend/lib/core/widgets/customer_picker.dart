import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/phone_utils.dart';
import '../widgets/app_dialog.dart';
import 'phone_text_field.dart';
import '../../services/pos_service.dart';

/// Kassir üçün müştəri seçimi: axtarış + yeni müştəri (+).
class CustomerPicker extends StatefulWidget {
  const CustomerPicker({
    super.key,
    required this.pos,
    this.selectedId,
    this.onChanged,
    this.onCustomerDetailChanged,
  });

  final PosService pos;
  final int? selectedId;
  final ValueChanged<int?>? onChanged;
  final ValueChanged<Map<String, dynamic>?>? onCustomerDetailChanged;

  @override
  State<CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<CustomerPicker> {
  final _queryCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selected;
  bool _loading = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedId != null) {
      _loadSelected(widget.selectedId!);
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSelected(int id) async {
    try {
      final list = await widget.pos.searchCustomers('');
      Map<String, dynamic>? found;
      for (final raw in list) {
        final c = raw as Map<String, dynamic>;
        if (c['id'] == id) {
          found = c;
          break;
        }
      }
      if (found != null && mounted) {
        setState(() => _selected = found);
        _notifySelection(found);
      }
    } catch (_) {}
  }

  void _notifySelection(Map<String, dynamic>? customer) {
    widget.onChanged?.call(customer != null ? customer['id'] as int? : null);
    widget.onCustomerDetailChanged?.call(customer);
  }

  Future<void> _runSearch(String q) async {
    setState(() => _loading = true);
    try {
      final list = await widget.pos.searchCustomers(q);
      if (mounted) {
        setState(() {
          _results = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createNew() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: PhoneUtils.fieldValue());
    final created = await showAppDialog<Map<String, dynamic>>(
      context: context,
      title: 'Yeni müştəri',
      maxWidth: 420,
      icon: Icons.person_add_outlined,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(controller: nameCtrl, label: 'Ad soyad', autofocus: true),
          const SizedBox(height: AppSpacing.lg),
          PhoneTextField(controller: phoneCtrl),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ləğv')),
        FilledButton(
          onPressed: () async {
            final phone = PhoneUtils.normalize(phoneCtrl.text);
            if (nameCtrl.text.trim().isEmpty || phone == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    phone == null ? PhoneUtils.validationMessage(phoneCtrl.text) : 'Ad daxil edin',
                  ),
                ),
              );
              return;
            }
            try {
              final c = await widget.pos.createCustomer({'name': nameCtrl.text.trim(), 'phone': phone});
              if (context.mounted) Navigator.pop(context, c);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().contains('409') ? 'Bu nömrə artıq var' : 'Xəta: $e')),
                );
              }
            }
          },
          child: const Text('Yarat'),
        ),
      ],
    );
    if (created != null) {
      setState(() {
        _selected = created;
        _expanded = false;
        _queryCtrl.clear();
      });
      _notifySelection(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _queryCtrl,
                decoration: InputDecoration(
                  labelText: 'Müştəri (ixtiyari)',
                  hintText: 'Ad və ya telefon ilə axtar',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _selected != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() {
                              _selected = null;
                              _queryCtrl.clear();
                            });
                            _notifySelection(null);
                          },
                        )
                      : null,
                  isDense: true,
                ),
                onTap: () {
                  if (!_expanded) {
                    setState(() => _expanded = true);
                    _runSearch('');
                  }
                },
                onChanged: (v) {
                  setState(() => _expanded = true);
                  _searchDebounced(v);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _createNew,
              icon: const Icon(Icons.add, size: 22),
              tooltip: 'Yeni müştəri',
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        if (_selected != null && !_expanded)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _CustomerChip(
              name: _selected!['name'] as String? ?? '',
              phone: _selected!['phone'] as String? ?? '',
            ),
          ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          if (_loading)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: _results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Müştəri tapılmadı', style: TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = _results[i];
                        return ListTile(
                          dense: true,
                          title: Text(c['name'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text([
                            c['phone'] as String? ?? '',
                            if ((c['customer_group_name'] as String?)?.isNotEmpty == true)
                              c['customer_group_name'] as String,
                          ].where((e) => e.isNotEmpty).join(' · ')),
                          onTap: () {
                            setState(() {
                              _selected = c;
                              _expanded = false;
                              _queryCtrl.text = c['name'] as String? ?? '';
                            });
                            _notifySelection(c);
                          },
                        );
                      },
                    ),
            ),
        ],
      ],
    );
  }

  String? _debounce;
  void _searchDebounced(String v) {
    _debounce = v;
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (_debounce != v) return;
      await _runSearch(v);
    });
  }
}

class _CustomerChip extends StatelessWidget {
  const _CustomerChip({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(phone, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

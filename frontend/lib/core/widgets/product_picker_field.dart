import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/json_parse.dart';

/// Axtarışlı məhsul seçici (paket və s. üçün).
class ProductPickerField extends StatefulWidget {
  const ProductPickerField({
    super.key,
    required this.products,
    required this.selectedId,
    required this.onSelected,
    this.label = 'Məhsul',
  });

  final List<Map<String, dynamic>> products;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
  final String label;

  @override
  State<ProductPickerField> createState() => _ProductPickerFieldState();
}

class _ProductPickerFieldState extends State<ProductPickerField> {
  final _search = TextEditingController();
  bool _open = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _selected {
    if (widget.selectedId == null) return null;
    for (final p in widget.products) {
      if (p['id'] == widget.selectedId) return p;
    }
    return null;
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.products;
    return widget.products
        .where((p) => (p['name'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.label,
              suffixIcon: Icon(_open ? Icons.expand_less : Icons.expand_more, size: 20),
            ),
            child: Text(
              sel != null ? '${sel['name']} — ${jsonToDouble(sel['price']).toStringAsFixed(2)} ₼' : 'Məhsul seçin',
              style: TextStyle(
                fontSize: 14,
                color: sel != null ? AppColors.textPrimary : AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Məhsul axtar...',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: Material(
              elevation: 0,
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: _filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Məhsul tapılmadı', style: TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        final id = p['id'] as int;
                        final selected = widget.selectedId == id;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          title: Text(p['name'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${jsonToDouble(p['price']).toStringAsFixed(2)} ₼'),
                          onTap: () {
                            widget.onSelected(id);
                            setState(() {
                              _open = false;
                              _search.clear();
                            });
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/cashier_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/json_parse.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/phone_text_field.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/money_text.dart';
import '../../services/pos_service.dart';
import 'customer_profile_screen.dart';
import 'widgets/admin_page_layout.dart';

enum CustomerListFilter {
  all('all', 'Hamısı'),
  topSpending('top_spending', 'Ən çox xərcləyən'),
  withSpending('with_spending', 'Ödənişi olan'),
  withSessions('with_sessions', 'Sessiyası var'),
  noSessions('no_sessions', 'Sessiyası yox'),
  activeNow('active_now', 'İndi aktiv');

  const CustomerListFilter(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  CustomerListFilter _filter = CustomerListFilter.all;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyLocalSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(posServiceProvider).searchCustomers(
            '',
            filter: _filter.apiValue,
          );
      _all = list.cast<Map<String, dynamic>>();
      _applyLocalSearch();
    } catch (_) {
      _all = [];
      _filtered = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyLocalSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    if (q.isEmpty) {
      _filtered = List.from(_all);
    } else {
      _filtered = _all.where((c) {
        final name = (c['name'] as String? ?? '').toLowerCase();
        final phone = c['phone'] as String? ?? '';
        if (name.contains(q)) return true;
        if (phone.toLowerCase().contains(q)) return true;
        if (digits.isNotEmpty && phone.replaceAll(RegExp(r'\D'), '').contains(digits)) return true;
        return false;
      }).toList();
    }
    if (mounted) setState(() {});
  }

  void _setFilter(CustomerListFilter f) {
    if (_filter == f) return;
    setState(() => _filter = f);
    _load();
  }

  Future<void> _showForm({Map<String, dynamic>? customer}) async {
    final isEdit = customer != null;
    final nameCtrl = TextEditingController(text: customer?['name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: PhoneUtils.fieldValue(stored: customer?['phone'] as String?));
    final emailCtrl = TextEditingController(text: customer?['email'] as String? ?? '');
    final notesCtrl = TextEditingController(text: customer?['notes'] as String? ?? '');

    final ok = await showAppDialog<bool>(
      context: context,
      title: isEdit ? 'Müştərini redaktə et' : 'Yeni müştəri',
      subtitle: 'Telefon: ${PhoneUtils.displayHint()}',
      icon: Icons.person_outline,
      maxWidth: 480,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(controller: nameCtrl, label: 'Ad soyad', prefixIcon: Icons.badge_outlined),
          const SizedBox(height: AppSpacing.lg),
          PhoneTextField(controller: phoneCtrl),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: emailCtrl, label: 'E-poçt (istəyə bağlı)', prefixIcon: Icons.email_outlined),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: notesCtrl, label: 'Qeyd (istəyə bağlı)'),
        ],
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(isEdit ? 'Yadda saxla' : 'Yarat')),
      ],
    );

    if (ok != true) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      emailCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final notes = notesCtrl.text.trim();
    final phone = PhoneUtils.normalize(phoneCtrl.text);

    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    notesCtrl.dispose();

    if (name.isEmpty || phone == null) {
      if (mounted) {
        showAppSnackBar(
          context,
          phone == null ? 'Düzgün telefon daxil edin' : 'Ad daxil edin',
          isError: true,
        );
      }
      return;
    }

    try {
      final service = ref.read(posServiceProvider);
      if (isEdit) {
        await service.updateCustomer(customer['id'] as int, {
          'name': name,
          'phone': phone,
          if (email.isNotEmpty) 'email': email,
          if (notes.isNotEmpty) 'notes': notes,
        });
      } else {
        await service.createCustomer({
          'name': name,
          'phone': phone,
          if (email.isNotEmpty) 'email': email,
          if (notes.isNotEmpty) 'notes': notes,
        });
      }
      await _load();
      if (mounted) showAppSnackBar(context, isEdit ? 'Müştəri yeniləndi' : 'Müştəri yaradıldı');
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('409') ? 'Bu telefon artıq qeydiyyatdadır' : 'Xəta: $e';
        showAppSnackBar(context, msg, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageLayout(
      action: FilledButton.icon(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.person_add, size: 20),
        label: const Text('Müştəri əlavə et'),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.sm),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 720;
                final searchField = TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ad və ya telefon ilə axtar...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                );
                final filterControl = _CustomerFilterChips(
                  selected: _filter,
                  onChanged: _setFilter,
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: AppSpacing.sm),
                      filterControl,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: searchField),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 3, child: filterControl),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        title: 'Müştəri tapılmadı',
                        subtitle: _searchCtrl.text.isNotEmpty
                            ? 'Axtarış və ya filtrə uyğun nəticə yoxdur'
                            : 'İlk müştərini əlavə edin',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final c = _filtered[i];
                          final totalSpent = jsonToDouble(c['total_spent']);
                          final sessionCount = jsonToInt(c['session_count']);
                          final openSessions = jsonToInt(c['open_session_count']);

                          return AdminListTile(
                            leading: CircleAvatar(
                              backgroundColor: CashierTheme.accentSubtle(context),
                              child: Text(
                                (c['name'] as String? ?? '?').isNotEmpty
                                    ? (c['name'] as String)[0].toUpperCase()
                                    : '?',
                                style: TextStyle(color: BrandColors.brightBlue, fontWeight: FontWeight.w600),
                              ),
                            ),
                            title: c['name'] as String? ?? '',
                            subtitle: c['phone'] as String? ?? '',
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    MoneyText(
                                      amount: totalSpent,
                                      size: MoneySize.medium,
                                      color: totalSpent > 0
                                          ? BrandColors.brightBlue
                                          : CashierTheme.textTertiary(context),
                                      suffix: ' ₼',
                                    ),
                                    if (sessionCount > 0 || openSessions > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        openSessions > 0
                                            ? '$sessionCount sessiya · $openSessions aktiv'
                                            : '$sessionCount sessiya',
                                        style: CashierTheme.caption(context),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Redaktə et',
                                  onPressed: () => _showForm(customer: c),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CustomerProfileScreen(
                                    customerId: c['id'] as int,
                                    onUpdated: _load,
                                  ),
                                ),
                              );
                            },
                            onDelete: () async {
                              await ref.read(posServiceProvider).deleteCustomer(c['id'] as int);
                              await _load();
                              if (mounted) showAppSnackBar(context, 'Müştəri silindi');
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _CustomerFilterChips extends StatelessWidget {
  const _CustomerFilterChips({
    required this.selected,
    required this.onChanged,
  });

  final CustomerListFilter selected;
  final ValueChanged<CustomerListFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in CustomerListFilter.values) ...[
            if (f != CustomerListFilter.values.first) const SizedBox(width: 6),
            FilterChip(
              label: Text(f.label),
              selected: selected == f,
              onSelected: (_) => onChanged(f),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: selected == f ? FontWeight.w600 : FontWeight.w500,
                color: selected == f ? BrandColors.brightBlue : CashierTheme.textSecondary(context),
              ),
              side: BorderSide(
                color: selected == f
                    ? BrandColors.brightBlue.withValues(alpha: 0.5)
                    : CashierTheme.border(context),
              ),
              selectedColor: BrandColors.brightBlue.withValues(alpha: 0.12),
              backgroundColor: CashierTheme.surfaceSecondary(context),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

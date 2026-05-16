import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/empty_state.dart';
import '../../services/pos_service.dart';
import 'widgets/admin_page_layout.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(posServiceProvider).searchCustomers('');
      _all = list.cast<Map<String, dynamic>>();
      _applyFilter();
    } catch (_) {
      _all = [];
      _filtered = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    if (q.isEmpty) {
      _filtered = List.from(_all);
    } else {
      _filtered = _all.where((c) {
        final name = (c['name'] as String? ?? '').toLowerCase();
        final phone = (c['phone'] as String? ?? '');
        if (name.contains(q)) return true;
        if (phone.toLowerCase().contains(q)) return true;
        if (digits.isNotEmpty && phone.replaceAll(RegExp(r'\D'), '').contains(digits)) return true;
        return false;
      }).toList();
    }
    if (mounted) setState(() {});
  }

  Future<void> _showForm({Map<String, dynamic>? customer}) async {
    final isEdit = customer != null;
    final nameCtrl = TextEditingController(text: customer?['name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: customer?['phone'] as String? ?? '+994');
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
          AppTextField(
            controller: phoneCtrl,
            label: 'Telefon',
            hint: PhoneUtils.displayHint(),
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
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

    final phone = PhoneUtils.normalize(phoneCtrl.text);
    if (nameCtrl.text.trim().isEmpty || phone == null) {
      if (mounted) showAppSnackBar(context, 'Ad və düzgün telefon daxil edin', isError: true);
      nameCtrl.dispose();
      phoneCtrl.dispose();
      emailCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    final payload = {
      'name': nameCtrl.text.trim(),
      'phone': phone,
      if (emailCtrl.text.trim().isNotEmpty) 'email': emailCtrl.text.trim(),
      if (notesCtrl.text.trim().isNotEmpty) 'notes': notesCtrl.text.trim(),
    };

    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    notesCtrl.dispose();

    try {
      final service = ref.read(posServiceProvider);
      if (isEdit) {
        await service.updateCustomer(customer['id'] as int, payload);
      } else {
        await service.createCustomer(payload);
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Ad və ya telefon ilə axtar...',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'Müştəri yoxdur',
                        subtitle: 'İlk müştərini əlavə edin',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final c = _filtered[i];
                          return AdminListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primarySoft,
                              child: Text(
                                (c['name'] as String? ?? '?').isNotEmpty ? (c['name'] as String)[0].toUpperCase() : '?',
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: c['name'] as String? ?? '',
                            subtitle: c['phone'] as String? ?? '',
                            onTap: () => _showForm(customer: c),
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

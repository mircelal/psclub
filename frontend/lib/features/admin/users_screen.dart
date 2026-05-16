import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../services/pos_service.dart';
import 'widgets/admin_page_layout.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  List<dynamic> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _users = await ref.read(posServiceProvider).getUsers();
    setState(() => _loading = false);
  }

  Future<void> _add() async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var role = 'cashier';
    final ok = await showAppDialog<bool>(
      context: context,
      title: 'Yeni istifadəçi',
      subtitle: 'Admin və ya kassir hesabı',
      icon: Icons.person_add,
      body: StatefulBuilder(
        builder: (ctx, setDlg) => Column(
          children: [
            AppTextField(controller: userCtrl, label: 'İstifadəçi adı', prefixIcon: Icons.person_outline),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(controller: passCtrl, label: 'Şifrə', obscureText: true, prefixIcon: Icons.lock_outline),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Rol'),
              initialValue: role,
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                DropdownMenuItem(value: 'cashier', child: Text('Kassir')),
              ],
              onChanged: (v) => setDlg(() => role = v ?? 'cashier'),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yarat')),
      ],
    );
    if (ok == true) {
      await ref.read(posServiceProvider).createUser({
        'username': userCtrl.text,
        'password': passCtrl.text,
        'role': role,
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageLayout(
      title: 'İstifadəçilər',
      subtitle: 'Komanda və giriş icazələri',
      action: FilledButton.icon(onPressed: _add, icon: const Icon(Icons.person_add, size: 20), label: const Text('Əlavə et')),
      child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              itemCount: _users.length,
              itemBuilder: (_, i) {
                final u = _users[i] as Map<String, dynamic>;
                final isAdmin = u['role'] == 'admin';
                return AdminListTile(
                  leading: CircleAvatar(
                    backgroundColor: isAdmin ? AppColors.primarySoft : AppColors.accentSoft,
                    child: Icon(isAdmin ? Icons.shield_outlined : Icons.point_of_sale, color: isAdmin ? AppColors.primary : AppColors.accent, size: 20),
                  ),
                  title: u['username'] as String,
                  subtitle: u['full_name'] as String? ?? u['role'] as String,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: isAdmin ? AppColors.primarySoft : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(isAdmin ? 'Admin' : 'Kassir', style: TextStyle(fontSize: 11, color: isAdmin ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                );
              },
            ),
    );
  }
}

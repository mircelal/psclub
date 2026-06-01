import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/utils/json_parse.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/api/api_client.dart';
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
    try {
      _users = await ref.read(posServiceProvider).getUsers();
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  int? get _currentUserId => ref.read(authProvider).valueOrNull?.id;

  Future<void> _add() async {
    final userCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
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
            AppTextField(controller: userCtrl, label: 'İstifadəçi adı', prefixIcon: Icons.person_outline, autofocus: true),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(controller: nameCtrl, label: 'Ad soyad (istəyə bağlı)', prefixIcon: Icons.badge_outlined),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(controller: passCtrl, label: 'Şifrə (min. 4 simvol)', obscureText: true, prefixIcon: Icons.lock_outline),
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
    if (ok != true || !mounted) return;

    try {
      await ref.read(posServiceProvider).createUser({
        'username': userCtrl.text.trim(),
        'password': passCtrl.text,
        'role': role,
        if (nameCtrl.text.trim().isNotEmpty) 'full_name': nameCtrl.text.trim(),
      });
      if (mounted) {
        showAppSnackBar(context, 'İstifadəçi yaradıldı');
        _load();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
    }
  }

  Future<void> _edit(Map<String, dynamic> user) async {
    final id = jsonToInt(user['id']);
    final nameCtrl = TextEditingController(text: user['full_name']?.toString() ?? '');
    final passCtrl = TextEditingController();
    var role = user['role']?.toString() ?? 'cashier';
    var isActive = jsonToInt(user['is_active']) == 1;
    final isSelf = _currentUserId == id;

    final ok = await showAppDialog<bool>(
      context: context,
      title: 'İstifadəçini redaktə et',
      subtitle: user['username']?.toString() ?? '',
      icon: Icons.edit_outlined,
      body: StatefulBuilder(
        builder: (ctx, setDlg) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(controller: nameCtrl, label: 'Ad soyad', prefixIcon: Icons.badge_outlined),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: passCtrl,
              label: 'Yeni şifrə (boş buraxın — dəyişməz)',
              obscureText: true,
              prefixIcon: Icons.lock_outline,
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Rol'),
              initialValue: role,
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                DropdownMenuItem(value: 'cashier', child: Text('Kassir')),
              ],
              onChanged: isSelf ? null : (v) => setDlg(() => role = v ?? role),
            ),
            if (isSelf)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Öz rolunuzu dəyişə bilməzsiniz',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktiv'),
              subtitle: Text(isActive ? 'Giriş icazəsi var' : 'Giriş bloklanıb'),
              value: isActive,
              onChanged: isSelf
                  ? null
                  : (v) => setDlg(() => isActive = v),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Saxla')),
      ],
    );
    if (ok != true || !mounted) return;

    try {
      final data = <String, dynamic>{
        'full_name': nameCtrl.text.trim(),
        'role': role,
        'is_active': isActive,
      };
      if (passCtrl.text.isNotEmpty) {
        data['password'] = passCtrl.text;
      }
      await ref.read(posServiceProvider).updateUser(id, data);
      if (mounted) {
        showAppSnackBar(context, 'İstifadəçi yeniləndi');
        _load();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    final id = jsonToInt(user['id']);
    final username = user['username']?.toString() ?? '';

    if (_currentUserId == id) {
      showAppSnackBar(context, 'Öz hesabınızı silə bilməzsiniz', isError: true);
      return;
    }

    final ok = await showAppDialog<bool>(
      context: context,
      title: 'İstifadəçini sil',
      subtitle: '“$username” deaktiv edilsin?',
      icon: Icons.person_off_outlined,
      body: Text(
        'Hesab silinmir — yalnız deaktiv olunur və giriş edə bilməz. Sonradan redaktə ilə yenidən aktiv edə bilərsiniz.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Deaktiv et'),
        ),
      ],
    );
    if (ok != true || !mounted) return;

    try {
      await ref.read(posServiceProvider).deleteUser(id);
      if (mounted) {
        showAppSnackBar(context, 'İstifadəçi deaktiv edildi');
        _load();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageLayout(
      title: 'İstifadəçilər',
      subtitle: 'Komanda və giriş icazələri — redaktə və deaktiv etmə',
      action: FilledButton.icon(
        onPressed: _add,
        icon: const Icon(Icons.person_add, size: 20),
        label: const Text('Əlavə et'),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _users.isEmpty
              ? const Center(child: Text('İstifadəçi yoxdur'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  itemCount: _users.length,
                  itemBuilder: (_, i) {
                    final u = _users[i] as Map<String, dynamic>;
                    final isAdmin = u['role'] == 'admin';
                    final active = jsonToInt(u['is_active']) == 1;
                    final id = jsonToInt(u['id']);
                    final isSelf = _currentUserId == id;

                    return Opacity(
                      opacity: active ? 1 : 0.55,
                      child: AdminListTile(
                        leading: CircleAvatar(
                          backgroundColor: isAdmin ? AppColors.primarySoft : AppColors.accentSoft,
                          child: Icon(
                            isAdmin ? Icons.shield_outlined : Icons.point_of_sale,
                            color: isAdmin ? AppColors.primary : AppColors.accent,
                            size: 20,
                          ),
                        ),
                        title: u['username'] as String? ?? '—',
                        subtitle: _userSubtitle(u, active, isSelf),
                        onTap: () => _edit(u),
                        onDelete: isSelf ? null : () => _delete(u),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!active)
                              Container(
                                margin: const EdgeInsets.only(right: AppSpacing.sm),
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: AdminTheme.danger(context).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: Text(
                                  'Deaktiv',
                                  style: TextStyle(fontSize: 11, color: AdminTheme.danger(context), fontWeight: FontWeight.w600),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: isAdmin ? AppColors.primarySoft : AppColors.surface,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                              child: Text(
                                isAdmin ? 'Admin' : 'Kassir',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isAdmin ? AppColors.primary : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Redaktə et',
                              onPressed: () => _edit(u),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _userSubtitle(Map<String, dynamic> u, bool active, bool isSelf) {
    final parts = <String>[];
    final name = u['full_name']?.toString();
    if (name != null && name.isNotEmpty) parts.add(name);
    parts.add(u['role'] == 'admin' ? 'Administrator' : 'Kassir');
    if (!active) parts.add('deaktiv');
    if (isSelf) parts.add('siz');
    return parts.join(' · ');
  }
}

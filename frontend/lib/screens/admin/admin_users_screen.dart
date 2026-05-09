import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final token = context.read<AuthProvider>().token!;
      final data = await ApiService.getUsers(token);
      setState(() => _users = data.cast<Map<String, dynamic>>());
    } catch (_) {}
    setState(() => _loading = false);
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'super_admin':
        return Colors.purple;
      case 'admin':
        return const Color(0xFF40BFFF);
      default:
        return Colors.grey;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'admin':
        return 'Quản trị';
      default:
        return 'Người dùng';
    }
  }

  Future<void> _showUserDialog({Map<String, dynamic>? user}) async {
    final isEdit = user != null;
    final nameCtrl = TextEditingController(text: user?['name'] ?? '');
    final emailCtrl = TextEditingController(text: user?['email'] ?? '');
    final passCtrl = TextEditingController();
    String role = user?['role'] ?? 'user';
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Sửa tài khoản' : 'Thêm tài khoản'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 400,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Tên *', border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Email *', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: isEdit
                          ? 'Mật khẩu mới (để trống nếu không đổi)'
                          : 'Mật khẩu *',
                      border: const OutlineInputBorder()),
                  validator: isEdit
                      ? null
                      : (v) =>
                          (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(
                      labelText: 'Vai trò', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('Người dùng')),
                    DropdownMenuItem(
                        value: 'admin', child: Text('Quản trị (Admin)')),
                    DropdownMenuItem(
                        value: 'super_admin', child: Text('Super Admin')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v!),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        final token = context.read<AuthProvider>().token!;
                        final data = {
                          'name': nameCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'role': role,
                          if (passCtrl.text.trim().isNotEmpty)
                            'password': passCtrl.text.trim(),
                        };
                        if (isEdit) {
                          await ApiService.updateUser(token, user['id'], data);
                        } else {
                          await ApiService.createUser(token, data);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _fetch();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                        }
                      } finally {
                        setDialogState(() => saving = false);
                      }
                    },
              child: Text(isEdit ? 'Cập nhật' : 'Tạo'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa tài khoản "${user['name']}" (${user['email']})?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        final token = context.read<AuthProvider>().token!;
        await ApiService.deleteUser(token, user['id']);
        _fetch();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin')),
        title: const Text('Quản lý tài khoản'),
        actions: [
          IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Thêm tài khoản',
              onPressed: () => _showUserDialog()),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('Không có tài khoản nào'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _users.length,
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    final isSelf = u['id'] == currentUserId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _roleColor(u['role']).withOpacity(0.15),
                          child: Text(
                            (u['name'] as String).substring(0, 1).toUpperCase(),
                            style: TextStyle(
                                color: _roleColor(u['role']),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Row(children: [
                          Text(u['name'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          if (isSelf) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text('Bạn',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.blue)),
                            ),
                          ]
                        ]),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u['email'],
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _roleColor(u['role']).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(_roleLabel(u['role']),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _roleColor(u['role']),
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.edit,
                                    size: 20, color: Colors.blue),
                                onPressed: () => _showUserDialog(user: u)),
                            IconButton(
                                icon: const Icon(Icons.delete,
                                    size: 20, color: Colors.red),
                                onPressed: isSelf ? null : () => _delete(u)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

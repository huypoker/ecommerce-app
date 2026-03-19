import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    setState(() { _loading = true; _error = null; });
    final err = await context.read<AuthProvider>().register(_name.text, _email.text, _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add, size: 80, color: Theme.of(context).primaryColor),
              const SizedBox(height: 16),
              const Text('Đăng ký', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Họ tên', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()), onSubmitted: (_) => _register()),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Đăng ký', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: () => context.go('/login'), child: const Text('Đã có tài khoản? Đăng nhập')),
            ],
          ),
        ),
      ),
    );
  }
}

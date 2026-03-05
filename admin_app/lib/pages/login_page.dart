import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Login page: email/password only. Backend returns JWT; roles from token drive tab access.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController(text: 'admin@insurance.com');
  final _passwordController = TextEditingController(text: 'Admin@123');
  bool _loading = false;
  String? _error = null;
  bool _obscurePassword = true;

  final List<({String label, String email, String password})> _testUsers = [
    (label: 'Admin', email: 'admin@insurance.com', password: 'Admin@123'),
    (label: 'Agent', email: 'agent@insurance.com', password: 'Agent@123'),
    (label: 'Underwriter', email: 'uw@insurance.com', password: 'UW@123'),
    (
      label: 'Senior UW',
      email: 'senioruw@insurance.com',
      password: 'SeniorUW@123',
    ),
    (
      label: 'Claims Officer',
      email: 'claims@insurance.com',
      password: 'Claims@123',
    ),
    (
      label: 'Finance Officer',
      email: 'finance@insurance.com',
      password: 'Finance@123',
    ),
    (
      label: 'Customer',
      email: 'customer@insurance.com',
      password: 'Customer@123',
    ),
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifier = ref.read(authNotifierProvider);
      await notifier.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      ref.read(authVersionProvider.notifier).state++;
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'InsureAdmin',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    DropdownMenu<int>(
                      initialSelection: 0,
                      expandedInsets: EdgeInsets.zero,
                      label: const Text('Quick Login (Testing)'),
                      dropdownMenuEntries: [
                        for (int i = 0; i < _testUsers.length; i++)
                          DropdownMenuEntry(
                            value: i,
                            label: _testUsers[i].label,
                          ),
                      ],
                      onSelected: (i) {
                        if (i != null) {
                          setState(() {
                            _emailController.text = _testUsers[i].email;
                            _passwordController.text = _testUsers[i].password;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'admin@example.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const AppLoader(size: 20, center: false)
                          : const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

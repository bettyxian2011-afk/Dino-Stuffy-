import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/account_repository.dart';
import '../../data/strata_services.dart';
import '../../models/user_profile.dart';
import '../../theme/strata_theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.accountRepository});

  final AccountRepository? accountRepository;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _creatingAccount = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  AccountRepository get _accounts =>
      widget.accountRepository ?? StrataServices.accountRepository;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      final UserProfile profile = _creatingAccount
          ? await _accounts.createAccount(
              email: email,
              password: _passwordController.text,
            )
          : await _accounts.signIn(
              email: email,
              password: _passwordController.text,
            );

      if (profile.displayName.trim().isEmpty) {
        final name = await _askForDisplayName(email);
        await _accounts.updateDisplayName(name);
      }
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _askForDisplayName(String email) async {
    final controller = TextEditingController(
      text: defaultDisplayNameForEmail(email),
    );
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('What should we call you?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Display name'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    final name = result?.trim();
    final fallback = defaultDisplayNameForEmail(email);
    return name == null || name.isEmpty ? fallback : name;
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('email-already-in-use')) {
      return 'That email already has an account. Sign in instead.';
    }
    if (message.contains('invalid-credential') ||
        message.contains('wrong-password') ||
        message.contains('user-not-found')) {
      return 'Email or password is incorrect.';
    }
    if (message.contains('weak-password')) {
      return 'Choose a password with at least 6 characters.';
    }
    if (message.contains('network-request-failed')) {
      return 'Could not connect. Check your internet and try again.';
    }
    return 'Could not ${_creatingAccount ? 'create account' : 'sign in'}. $message';
  }

  @override
  Widget build(BuildContext context) {
    final title = _creatingAccount ? 'Create your account' : 'Welcome back';
    return Scaffold(
      backgroundColor: StrataColors.cream,
      appBar: AppBar(
        backgroundColor: StrataColors.cream,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _busy ? null : () => context.pop(),
        ),
        title: Text(
          'Strata',
          style: GoogleFonts.libreBaskerville(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.libreBaskerville(
                        color: StrataColors.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _creatingAccount
                          ? 'Create an account to save your Strata profile.'
                          : 'Sign in to continue exploring the fossil record.',
                      style: GoogleFonts.dmSans(color: StrataColors.brown),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (!email.contains('@') || email.endsWith('@')) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: _creatingAccount
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final password = value ?? '';
                        if (password.isEmpty) return 'Enter your password.';
                        if (_creatingAccount && password.length < 6) {
                          return 'Use at least 6 characters.';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: GoogleFonts.dmSans(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: StrataColors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _creatingAccount ? 'Create account' : 'Sign in',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _creatingAccount = !_creatingAccount;
                              _error = null;
                            }),
                      child: Text(
                        _creatingAccount
                            ? 'Already have an account? Sign in'
                            : 'New to Strata? Create an account',
                        style: GoogleFonts.dmSans(color: StrataColors.brown),
                      ),
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

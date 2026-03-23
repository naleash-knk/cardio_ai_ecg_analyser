import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_proj/dashboard/dashboard.dart';
import 'package:go_proj/models/account_creation_data.dart';
import 'package:go_proj/widgets/theme_toggle_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _appName = 'Cardio AI';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form != null && !form.validate()) {
      return;
    }
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final UserCredential credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final String? uid = credential.user?.uid;
      AccountCreationData? accountData;
      if (uid != null) {
        final DocumentSnapshot<Map<String, dynamic>> userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final Map<String, dynamic>? data = userDoc.data();
        if (data != null) {
          accountData = AccountCreationData.fromMap(data);
        }
      }

      accountData ??= AccountCreationData(
        name: '',
        age: '',
        gender: '',
        email: _emailController.text.trim(),
        complaints: const <String, bool>{},
        otherSymptoms: '',
        history: const <String, bool>{},
        otherHistory: '',
        hasMedications: false,
        medications: '',
        hasAnticoagulant: false,
        anticoagulant: '',
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DashBoard(accountData: accountData),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      String message = 'Login failed. Please try again.';
      if (error.code == 'user-not-found') {
        message = 'No account found for this email.';
      } else if (error.code == 'wrong-password' ||
          error.code == 'invalid-credential') {
        message = 'Invalid email or password.';
      } else if (error.code == 'invalid-email') {
        message = 'Invalid email address.';
      } else if (error.message != null && error.message!.trim().isNotEmpty) {
        message = error.message!.trim();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      final String message = error.code == 'permission-denied'
          ? 'Firestore permission denied. Update Firestore Rules for users/{uid}.'
          : 'Login failed. Please check Firebase setup.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed. Please check Firebase setup.'),
        ),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.surface,
              scheme.surfaceContainerHighest.withOpacity(0.5),
              scheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final double height = constraints.maxHeight;
              final bool compactHeight = height < 700;
              final double topSpace = compactHeight ? 10 : 18;
              final double titleGap = compactHeight ? 12 : 16;
              final double outerHorizontal = width < 360 ? 12 : 20;
              final double logoSize = width < 360 ? 44 : 56;

              return Stack(
                children: [
                  Column(
                    children: [
                      SizedBox(height: topSpace),
                      Image.asset(
                        'assets/icons/logo.png',
                        width: logoSize,
                        height: logoSize,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _appName,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Login',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: scheme.onSurface.withOpacity(0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: titleGap),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Container(
                              margin: EdgeInsets.symmetric(horizontal: outerHorizontal),
                              decoration: BoxDecoration(
                                color: scheme.surface,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: scheme.outline.withOpacity(0.2),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.shadow.withOpacity(0.08),
                                    blurRadius: 24,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                                  children: [
                            Text(
                              'Welcome back',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sign in to continue',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildModernTextField(
                              theme: theme,
                              scheme: scheme,
                              label: 'Email',
                              hint: 'name@example.com',
                              icon: Icons.alternate_email,
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                final emailRegex =
                                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                                if (!emailRegex.hasMatch(value.trim())) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildModernPasswordField(
                              theme: theme,
                              scheme: scheme,
                              label: 'Password',
                              hint: 'Enter your password',
                              icon: Icons.lock_outline,
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              onToggle: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Password is required';
                                }
                                if (value.trim().length < 6) {
                                  return 'Use at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : () => _submit(),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 1.5,
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Login'),
                              ),
                            ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                  const Positioned(
                    top: 12,
                    right: 16,
                    child: ThemeToggleButton(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInputShell({
    required ThemeData theme,
    required ColorScheme scheme,
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: scheme.onSurface.withOpacity(0.7),
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withOpacity(0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outline.withOpacity(0.25),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: scheme.outline.withOpacity(0.25),
                  ),
                ),
                child: Icon(
                  icon,
                  color: scheme.primary.withOpacity(0.9),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: child,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required ThemeData theme,
    required ColorScheme scheme,
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputAction? textInputAction,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return _buildInputShell(
      theme: theme,
      scheme: scheme,
      label: label,
      icon: icon,
      child: TextFormField(
        controller: controller,
        textInputAction: textInputAction,
        keyboardType: keyboardType,
        validator: validator,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withOpacity(0.5),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildModernPasswordField({
    required ThemeData theme,
    required ColorScheme scheme,
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return _buildInputShell(
      theme: theme,
      scheme: scheme,
      label: label,
      icon: icon,
      child: TextFormField(
        controller: controller,
        textInputAction: TextInputAction.done,
        obscureText: obscureText,
        validator: validator,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withOpacity(0.5),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          suffixIcon: IconButton(
            onPressed: onToggle,
            icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
            color: scheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

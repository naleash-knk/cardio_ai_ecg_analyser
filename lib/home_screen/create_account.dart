import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_proj/dashboard/dashboard.dart';
import 'package:go_proj/models/account_creation_data.dart';
import 'package:go_proj/widgets/theme_toggle_button.dart';

class CreateAccount extends StatefulWidget {
  const CreateAccount({super.key});

  @override
  State<CreateAccount> createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  static const String _appName = 'Cardio AI';

  final PageController _pageController = PageController();
  final List<GlobalKey<FormState>> _formKeys =
      List.generate(4, (_) => GlobalKey<FormState>());

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _otherSymptomsController =
      TextEditingController();
  final TextEditingController _otherHistoryController =
      TextEditingController();
  final TextEditingController _medicationsController =
      TextEditingController();
  final TextEditingController _anticoagulantController =
      TextEditingController();

  String? _gender;
  int _currentPage = 0;

  bool _complaintChestPain = false;
  bool _complaintRadiatingLeftLimb = false;
  bool _complaintStabbingPain = false;
  bool _complaintRadiatingJaw = false;
  bool _complaintBreathlessness = false;
  bool _complaintPalpitation = false;
  bool _complaintSweating = false;
  bool _complaintCough = false;
  bool _complaintBurningEpigastric = false;
  bool _complaintVomitingAbdominalPain = false;

  bool _historyDiabetes = false;
  bool _historyHypertension = false;
  bool _historyDyslipidemia = false;
  bool _historyHeartDisease = false;
  bool _historyAsthmaCopd = false;
  bool _historySimilarComplaint = false;
  bool _historyHeartAttack = false;
  bool _historyHeartSurgery = false;
  bool _historyOtherSurgery = false;

  bool _hasMedications = false;
  bool _hasAnticoagulant = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otherSymptomsController.dispose();
    _otherHistoryController.dispose();
    _medicationsController.dispose();
    _anticoagulantController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _nextPage() {
    final form = _formKeys[_currentPage].currentState;
    if (form != null && !form.validate()) {
      return;
    }
    if (_currentPage < _formKeys.length - 1) {
      _goToPage(_currentPage + 1);
    }
  }

  Future<void> _submit() async {
    int? firstInvalidPage;
    for (var i = 0; i < _formKeys.length; i++) {
      final form = _formKeys[i].currentState;
      final isValid = form == null || form.validate();
      if (!isValid && firstInvalidPage == null) {
        firstInvalidPage = i;
      }
    }

    if (firstInvalidPage != null) {
      _goToPage(firstInvalidPage);
      return;
    }
    if (_isSubmitting) {
      return;
    }

    final accountData = AccountCreationData(
      name: _nameController.text.trim(),
      age: _ageController.text.trim(),
      gender: (_gender ?? '').trim(),
      email: _emailController.text.trim(),
      complaints: <String, bool>{
        'Chest pain': _complaintChestPain,
        'Radiating to left limb': _complaintRadiatingLeftLimb,
        'Stabbing pain': _complaintStabbingPain,
        'Radiating to jaw': _complaintRadiatingJaw,
        'Breathlessness': _complaintBreathlessness,
        'Palpitation': _complaintPalpitation,
        'Sweating': _complaintSweating,
        'Cough': _complaintCough,
        'Burning sensation in epigastric region': _complaintBurningEpigastric,
        'Vomiting / abdominal pain': _complaintVomitingAbdominalPain,
      },
      otherSymptoms: _otherSymptomsController.text.trim(),
      history: <String, bool>{
        'H/o diabetes': _historyDiabetes,
        'H/o hypertension': _historyHypertension,
        'H/o dyslipidemia': _historyDyslipidemia,
        'H/o heart disease': _historyHeartDisease,
        'H/o asthma / COPD': _historyAsthmaCopd,
        'H/o similar complaint in past': _historySimilarComplaint,
        'H/o any heart attack': _historyHeartAttack,
        'H/o any heart surgery': _historyHeartSurgery,
        'H/o any other surgery': _historyOtherSurgery,
      },
      otherHistory: _otherHistoryController.text.trim(),
      hasMedications: _hasMedications,
      medications: _medicationsController.text.trim(),
      hasAnticoagulant: _hasAnticoagulant,
      anticoagulant: _anticoagulantController.text.trim(),
    );

    setState(() {
      _isSubmitting = true;
    });

    try {
      final UserCredential credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: accountData.email,
        password: _passwordController.text.trim(),
      );
      final String? uid = credential.user?.uid;
      if (uid == null) {
        throw FirebaseAuthException(
          code: 'missing-uid',
          message: 'User ID was not returned after account creation.',
        );
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        ...accountData.toMap(),
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
      String message = 'Unable to create account. Please try again.';
      if (error.code == 'email-already-in-use') {
        message = 'This email is already registered. Please login.';
      } else if (error.code == 'invalid-email') {
        message = 'Invalid email address.';
      } else if (error.code == 'weak-password') {
        message = 'Password is too weak. Use at least 6 characters.';
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
          : 'Unable to create account. Please check Firebase setup.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to create account. Please check Firebase setup.'),
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
              final bool compactHeight = height < 720;
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
                        'Create Account',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: scheme.onSurface.withOpacity(0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: titleGap),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
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
                              child: Column(
                                children: [
                                  const SizedBox(height: 16),
                                  _buildStepIndicator(scheme),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: PageView(
                                      controller: _pageController,
                                      onPageChanged: (page) {
                                        FocusScope.of(context).unfocus();
                                        setState(() {
                                          _currentPage = page;
                                        });
                                      },
                                      children: [
                                        _buildBasicDetailsPage(theme, scheme),
                                        _buildComplaintsPage(theme, scheme),
                                        _buildHistoryPage(theme, scheme),
                                        _buildMedicationsPage(theme, scheme),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                    child: _buildNavigationButtons(),
                                  ),
                                ],
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

  Widget _buildStepIndicator(ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _formKeys.length,
        (index) => GestureDetector(
          onTap: () => _goToPage(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 4,
            width: _currentPage == index ? 28 : 14,
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? scheme.primary
                  : scheme.outline.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final isLastPage = _currentPage == _formKeys.length - 1;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting
            ? null
            : (isLastPage ? () => _submit() : _nextPage),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 1.5,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(isLastPage ? 'Submit' : 'Next'),
      ),
    );
  }

  Widget _buildInputShell({
    required ThemeData theme,
    required ColorScheme scheme,
    required String label,
    required IconData icon,
    required Widget child,
    String? helper,
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
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withOpacity(0.55),
            ),
          ),
        ],
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
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
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
        inputFormatters: inputFormatters,
        validator: validator,
        maxLines: maxLines,
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
        textInputAction: TextInputAction.next,
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

  Widget _buildModernDropdownField({
    required ThemeData theme,
    required ColorScheme scheme,
    required String label,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return _buildInputShell(
      theme: theme,
      scheme: scheme,
      label: label,
      icon: icon,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withOpacity(0.5),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildCheckboxTile({
    required ThemeData theme,
    required ColorScheme scheme,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
    bool dense = false,
    EdgeInsets contentPadding = const EdgeInsets.symmetric(horizontal: 12),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outline.withOpacity(0.2),
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: theme.textTheme.bodyLarge,
        ),
        controlAffinity: ListTileControlAffinity.leading,
        dense: dense,
        contentPadding: contentPadding,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
      ),
    );
  }

  Widget _buildBasicDetailsPage(ThemeData theme, ColorScheme scheme) {
    return Form(
      key: _formKeys[0],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        children: [
          Text(
            'Basic Details',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          _buildModernTextField(
            theme: theme,
            scheme: scheme,
            label: 'Name',
            hint: 'Enter your full name',
            icon: Icons.badge_outlined,
            controller: _nameController,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildModernTextField(
            theme: theme,
            scheme: scheme,
            label: 'Age',
            hint: 'Enter your age',
            icon: Icons.cake_outlined,
            controller: _ageController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Age is required';
              }
              final age = int.tryParse(value);
              if (age == null || age <= 0) {
                return 'Enter a valid age';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildModernDropdownField(
            theme: theme,
            scheme: scheme,
            label: 'Gender',
            hint: 'Select an option',
            icon: Icons.people_outline,
            value: _gender,
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (value) {
              setState(() {
                _gender = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select your gender';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
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
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
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
            hint: 'Create a secure password',
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
          const SizedBox(height: 14),
          _buildModernPasswordField(
            theme: theme,
            scheme: scheme,
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            icon: Icons.lock_reset_outlined,
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            onToggle: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please confirm your password';
              }
              if (value.trim() != _passwordController.text.trim()) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Swipe to continue',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintsPage(ThemeData theme, ColorScheme scheme) {
    return Form(
      key: _formKeys[1],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        children: [
          Text(
            'Complaints',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Tick all that apply.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _complaintChestPain,
            onChanged: (value) {
              setState(() {
                _complaintChestPain = value ?? false;
                if (!_complaintChestPain) {
                  _complaintRadiatingLeftLimb = false;
                  _complaintStabbingPain = false;
                  _complaintRadiatingJaw = false;
                }
              });
            },
            title: 'Chest pain',
          ),
          if (_complaintChestPain)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                children: [
                  _buildCheckboxTile(
                    theme: theme,
                    scheme: scheme,
                    value: _complaintRadiatingLeftLimb,
                    onChanged: (value) {
                      setState(() {
                        _complaintRadiatingLeftLimb = value ?? false;
                      });
                    },
                    title: 'Radiating to left limb',
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  _buildCheckboxTile(
                    theme: theme,
                    scheme: scheme,
                    value: _complaintStabbingPain,
                    onChanged: (value) {
                      setState(() {
                        _complaintStabbingPain = value ?? false;
                      });
                    },
                    title: 'Stabbing pain',
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  _buildCheckboxTile(
                    theme: theme,
                    scheme: scheme,
                    value: _complaintRadiatingJaw,
                    onChanged: (value) {
                      setState(() {
                        _complaintRadiatingJaw = value ?? false;
                      });
                    },
                    title: 'Radiating to jaw',
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ],
              ),
            ),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _complaintBreathlessness,
            onChanged: (value) {
              setState(() {
                _complaintBreathlessness = value ?? false;
              });
            },
            title: 'Breathlessness',
          ),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _complaintPalpitation,
            onChanged: (value) {
              setState(() {
                _complaintPalpitation = value ?? false;
              });
            },
            title: 'Palpitation',
          ),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _complaintSweating,
            onChanged: (value) {
              setState(() {
                _complaintSweating = value ?? false;
              });
            },
            title: 'Sweating',
          ),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _complaintCough,
            onChanged: (value) {
              setState(() {
                _complaintCough = value ?? false;
              });
            },
            title: 'Cough',
          ),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _complaintBurningEpigastric,
            onChanged: (value) {
              setState(() {
                _complaintBurningEpigastric = value ?? false;
              });
            },
            title: 'Burning sensation in epigastric region',
          ),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _complaintVomitingAbdominalPain,
            onChanged: (value) {
              setState(() {
                _complaintVomitingAbdominalPain = value ?? false;
              });
            },
            title: 'Vomiting / abdominal pain',
          ),
          const SizedBox(height: 8),
          _buildModernTextField(
            theme: theme,
            scheme: scheme,
            label: 'Any other symptoms',
            hint: 'Type here if applicable',
            icon: Icons.edit_note_outlined,
            controller: _otherSymptomsController,
            textInputAction: TextInputAction.done,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPage(ThemeData theme, ColorScheme scheme) {
    return Form(
      key: _formKeys[2],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        children: [
          const SizedBox(height: 4),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _historyDiabetes,
            onChanged: (value) {
              setState(() {
                _historyDiabetes = value ?? false;
              });
            },
            title: 'H/o diabetes',
          ),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _historyHypertension,
            onChanged: (value) {
              setState(() {
                _historyHypertension = value ?? false;
              });
            },
            title: 'H/o hypertension',
          ),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _historyDyslipidemia,
            onChanged: (value) {
              setState(() {
                _historyDyslipidemia = value ?? false;
              });
            },
            title: 'H/o dyslipidemia',
          ),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _historyHeartDisease,
            onChanged: (value) {
              setState(() {
                _historyHeartDisease = value ?? false;
              });
            },
            title: 'H/o heart disease',
          ),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _historyAsthmaCopd,
            onChanged: (value) {
              setState(() {
                _historyAsthmaCopd = value ?? false;
              });
            },
            title: 'H/o asthma / COPD',
          ),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _historySimilarComplaint,
            onChanged: (value) {
              setState(() {
                _historySimilarComplaint = value ?? false;
              });
            },
            title: 'H/o similar complaint in past',
          ),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _historyHeartAttack,
            onChanged: (value) {
              setState(() {
                _historyHeartAttack = value ?? false;
              });
            },
            title: 'H/o any heart attack',
          ),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _historyHeartSurgery,
            onChanged: (value) {
              setState(() {
                _historyHeartSurgery = value ?? false;
              });
            },
            title: 'H/o any heart surgery',
          ),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _historyOtherSurgery,
            onChanged: (value) {
              setState(() {
                _historyOtherSurgery = value ?? false;
                if (!_historyOtherSurgery) {
                  _otherHistoryController.clear();
                }
              });
            },
            title: 'H/o any other surgery',
          ),
          if (_historyOtherSurgery) ...[
            const SizedBox(height: 8),
            _buildModernTextField(
              theme: theme,
              scheme: scheme,
              label: 'If any other, mention',
              hint: 'Type the surgery details',
              icon: Icons.medical_information_outlined,
              controller: _otherHistoryController,
              textInputAction: TextInputAction.done,
              maxLines: 2,
              validator: (value) {
                if (_historyOtherSurgery &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Please mention the surgery';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicationsPage(ThemeData theme, ColorScheme scheme) {
    return Form(
      key: _formKeys[3],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        children: [
          const SizedBox(height: 4),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _hasMedications,
            onChanged: (value) {
              setState(() {
                _hasMedications = value ?? false;
                if (!_hasMedications) {
                  _medicationsController.clear();
                }
              });
            },
            title: 'Any medications',
          ),
          if (_hasMedications) ...[
            const SizedBox(height: 8),
            _buildModernTextField(
              theme: theme,
              scheme: scheme,
              label: 'If yes, mention',
              hint: 'List medications',
              icon: Icons.medication_outlined,
              controller: _medicationsController,
              textInputAction: TextInputAction.done,
              maxLines: 2,
              validator: (value) {
                if (_hasMedications && (value == null || value.trim().isEmpty)) {
                  return 'Please list the medications';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 12),
          _buildCheckboxTile(
            theme: theme,
            scheme: scheme,
            value: _hasAnticoagulant,
            onChanged: (value) {
              setState(() {
                _hasAnticoagulant = value ?? false;
                if (!_hasAnticoagulant) {
                  _anticoagulantController.clear();
                }
              });
            },
            title: 'Any anticoagulant',
          ),
          if (_hasAnticoagulant) ...[
            const SizedBox(height: 8),
            _buildModernTextField(
              theme: theme,
              scheme: scheme,
              label: 'If yes, mention',
              hint: 'List anticoagulant',
              icon: Icons.medical_services_outlined,
              controller: _anticoagulantController,
              textInputAction: TextInputAction.done,
              maxLines: 2,
              validator: (value) {
                if (_hasAnticoagulant &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Please mention the anticoagulant';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }
}

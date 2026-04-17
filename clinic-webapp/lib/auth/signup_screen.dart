import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../models/shift.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _departmentController = TextEditingController();
  final _specializationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'doctor';
  String _selectedShift = 'morning';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _employeeIdController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    _specializationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signup(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      fullName: _fullNameController.text.trim(),
      role: _selectedRole,
      department: _departmentController.text.trim(),
      specialization: _specializationController.text.trim(),
      employeeId: _employeeIdController.text.trim(),
      shiftId: _selectedShift,
    );

    if (success && mounted) {
      if (authProvider.needsEmailConfirmation) {
        // Email confirmation is ON — show message, don't navigate yet
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Check your email'),
            content: Text(
              'A confirmation link has been sent to ${_emailController.text.trim()}.\n\nPlease click the link in the email to activate your account, then log in.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        );
      } else {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = AppColors.themed(context);
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.lightOffWhite,
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -80,
            right: -60,
            child: _Blob(size: 280, color1: AppColors.softOrange, color2: AppColors.vibrantOrange, opacity: isDark ? 0.20 : 0.55),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _Blob(size: 200, color1: AppColors.softOrange, color2: AppColors.vibrantOrange, opacity: isDark ? 0.15 : 0.35),
          ),

          // Centered scrollable content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo / Title
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.vibrantOrange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.health_and_safety, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Create your account',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: t.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Join the St. Dominic Health Monitoring System',
                    style: TextStyle(fontSize: 14, color: t.textSecondary),
                  ),
                  const SizedBox(height: 28),

                  // Signup Card
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 520),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withOpacity(0.3) : const Color(0x0F000000),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Error Banner
                          Consumer<AuthProvider>(
                            builder: (context, auth, child) {
                              if (auth.errorMessage == null) return const SizedBox.shrink();
                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_rounded, color: Color(0xFFDC2626), size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        auth.errorMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          // ── Personal Information ──
                          _sectionLabel('Personal Information'),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _field(
                                  label: 'Full Name',
                                  controller: _fullNameController,
                                  hint: 'Dr. Juan Dela Cruz',
                                  icon: Icons.person_outline,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _field(
                                  label: 'Employee ID',
                                  controller: _employeeIdController,
                                  hint: 'EMP-001',
                                  icon: Icons.badge_outlined,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _field(
                            label: 'Email Address',
                            controller: _emailController,
                            hint: 'you@stdominic.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email is required';
                              if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // ── Job Details ──
                          _sectionLabel('Job Details'),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Role', style: _labelStyle),
                                    const SizedBox(height: 8),
                                    _dropdownField<String>(
                                      value: _selectedRole,
                                      items: const [
                                        DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                                        DropdownMenuItem(value: 'nurse', child: Text('Nurse')),
                                      ],
                                      onChanged: (v) => setState(() => _selectedRole = v!),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _field(
                                  label: 'Department',
                                  controller: _departmentController,
                                  hint: 'e.g. Cardiology',
                                  icon: Icons.domain_outlined,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _field(
                            label: _selectedRole == 'doctor' ? 'Specialization' : 'Certification',
                            controller: _specializationController,
                            hint: _selectedRole == 'doctor' ? 'e.g. Pediatrics' : 'e.g. Registered Nurse',
                            icon: Icons.school_outlined,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Shift Schedule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              _dropdownField<String>(
                                value: _selectedShift,
                                items: ShiftSchedule.stDominicShifts
                                    .map((s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Text('${s.name}  •  ${s.description}'),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedShift = v!),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Security ──
                          _sectionLabel('Security'),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _field(
                                  label: 'Password',
                                  controller: _passwordController,
                                  hint: 'Min. 8 characters',
                                  icon: Icons.lock_outline,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 17,
                                      color: AppColors.themed(context).textSecondary,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Required';
                                    if (v.length < 8) return 'Min. 8 characters';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _field(
                                  label: 'Confirm Password',
                                  controller: _confirmPasswordController,
                                  hint: 'Repeat password',
                                  icon: Icons.lock_reset_outlined,
                                  obscureText: _obscureConfirmPassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 17,
                                      color: AppColors.themed(context).textSecondary,
                                    ),
                                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Required';
                                    if (v != _passwordController.text) return "Passwords don't match";
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Create Account Button
                          Consumer<AuthProvider>(
                            builder: (context, auth, child) {
                              return SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: auth.isLoading ? null : _handleSignup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.signinGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    disabledBackgroundColor: const Color(0xFF80C853),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Create Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // Back to login
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                context.read<AuthProvider>().clearError();
                                Navigator.of(context).pop();
                              },
                              child: RichText(
                                text: const TextSpan(
                                  text: 'Already have an account?  ',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  children: [
                                    TextSpan(
                                      text: 'Sign In',
                                      style: TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _labelStyle => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.themed(context).textSecondary,
  );

  Widget _sectionLabel(String label) {
    final t = AppColors.themed(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.vibrantOrange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.textPrimary),
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.themed(context).textHint, fontSize: 13),
            prefixIcon: Icon(icon, size: 17, color: AppColors.themed(context).textSecondary),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.themed(context).inputFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.themed(context).border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.themed(context).border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.vibrantOrange, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDC2626))),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
            errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
          ),
        ),
      ],
    );
  }

  Widget _dropdownField<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final t = AppColors.themed(context);
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          style: TextStyle(fontSize: 14, color: t.textPrimary),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: t.textSecondary),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color1;
  final Color color2;
  final double opacity;

  const _Blob({required this.size, required this.color1, required this.color2, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromRGBO(color1.r.toInt(), color1.g.toInt(), color1.b.toInt(), opacity * 0.6),
            Color.fromRGBO(color2.r.toInt(), color2.g.toInt(), color2.b.toInt(), opacity),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.45),
      ),
    );
  }
}

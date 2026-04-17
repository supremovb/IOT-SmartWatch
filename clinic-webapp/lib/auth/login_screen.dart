import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
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
            bottom: 80,
            left: 40,
            child: _Blob(size: 90, color1: AppColors.softOrange, color2: AppColors.vibrantOrange, opacity: isDark ? 0.15 : 0.4),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
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
                    'Good to see you again',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: t.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue to your dashboard',
                    style: TextStyle(fontSize: 14, color: t.textSecondary),
                  ),
                  const SizedBox(height: 32),

                  // Card
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 420),
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

                          // Email
                          Text('Email Address', style: _labelStyle),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Please enter your email';
                              if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                              return null;
                            },
                            decoration: _buildInputDecoration(
                              hint: 'e.g. nurse@stdominic.com',
                              icon: Icons.email_outlined,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Password
                          Text('Password', style: _labelStyle),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Please enter your password';
                              return null;
                            },
                            decoration: _buildInputDecoration(
                              hint: 'Enter your password',
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 18,
                                  color: t.textSecondary,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Sign In Button
                          Consumer<AuthProvider>(
                            builder: (context, auth, child) {
                              return SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: auth.isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.signinGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    disabledBackgroundColor: const Color(0xFF80C853),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // Links
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  context.read<AuthProvider>().clearError();
                                  Navigator.of(context).pushNamed('/signup');
                                },
                                child: const Text(
                                  "Don't have an account?",
                                  style: TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  context.read<AuthProvider>().clearError();
                                  Navigator.of(context).pushNamed('/forgot-password');
                                },
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Demo hint
                  const SizedBox(height: 24),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: t.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Demo Credentials',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _demoRow('Doctor', 'doctor.smith@stdominic.com', 'Doctor123!'),
                        const SizedBox(height: 4),
                        _demoRow('Nurse ', 'nurse.maria@stdominic.com', 'Nurse1234!'),
                      ],
                    ),
                  ),
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

  Widget _demoRow(String role, String email, String pass) {
    final t = AppColors.themed(context);
    return Row(
      children: [
        Text('$role: ', style: TextStyle(fontSize: 11, color: t.textSecondary, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(
            '$email  /  $pass',
            style: TextStyle(fontSize: 11, color: t.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final t = AppColors.themed(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: t.textHint, fontSize: 14),
      prefixIcon: Icon(icon, size: 18, color: t.textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: t.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.vibrantOrange, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDC2626))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
      errorStyle: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
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

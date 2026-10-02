import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/gradient_button.dart';
import '../widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(
      _emailController.text.trim(),
      _newPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đặt lại mật khẩu thành công! Vui lòng đăng nhập lại.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Đặt lại mật khẩu thất bại'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hp = R.hPad(context);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1130), Color(0xFF0A0E21), Color(0xFF131838)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: hp,
              right: hp,
              bottom: R.bottom(context) + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                ),
                SizedBox(height: R.sp(context, 10)),

                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppTheme.warning, AppTheme.primary],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.warning.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.lock_reset_rounded, size: 36, color: Colors.white),
                      ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

                      SizedBox(height: R.sp(context, 16)),

                      Text(
                        'Đặt Lai Mật Khẩu',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: R.fs(context, 24),
                            ),
                      ).animate(delay: 200.ms).fadeIn(),
                      SizedBox(height: R.sp(context, 6)),
                      Text(
                        'Nhập Email/SĐT đăng ký và tạo mật khẩu mới',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: R.fs(context, 13),
                        ),
                      ).animate(delay: 300.ms).fadeIn(),
                    ],
                  ),
                ),

                SizedBox(height: R.sp(context, 30)),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151B3B).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        CustomTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'example@email.com',
                          prefixIcon: Icons.email_rounded,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập Email';
                            if (!v.contains('@')) return 'Email không hợp lệ';
                            return null;
                          },
                        ),
                        SizedBox(height: R.sp(context, 16)),

                        CustomTextField(
                          controller: _newPasswordController,
                          label: 'Mật khẩu mới',
                          hint: '••••••••',
                          prefixIcon: Icons.key_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppTheme.textMuted,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                            if (v.length < 6) return 'Mật khẩu ít nhất 6 ký tự';
                            return null;
                          },
                        ),
                        SizedBox(height: R.sp(context, 16)),

                        CustomTextField(
                          controller: _confirmPasswordController,
                          label: 'Xác nhận mật khẩu mới',
                          hint: '••••••••',
                          prefixIcon: Icons.lock_clock_rounded,
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppTheme.textMuted,
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu mới';
                            if (v != _newPasswordController.text) return 'Mật khẩu xác nhận không khớp';
                            return null;
                          },
                        ),
                        SizedBox(height: R.sp(context, 24)),

                        Consumer<AuthProvider>(
                          builder: (_, auth, __) => GradientButton(
                            onPressed: auth.status == AuthStatus.loading ? null : _handleResetPassword,
                            isLoading: auth.status == AuthStatus.loading,
                            text: 'Cập Nhật Mật Khẩu',
                            icon: Icons.update_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

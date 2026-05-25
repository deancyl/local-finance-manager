import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:go_router/go_router.dart';

import '../../data/biometric_service.dart';
import '../../../settings/data/security_provider.dart';
import 'package:finance_app/core/router/app_router.dart' show markAppUnlocked;

/// Lock screen page for app unlock
/// Supports biometric authentication with PIN fallback
class LockScreenPage extends ConsumerStatefulWidget {
  final String? redirectUrl;
  
  const LockScreenPage({super.key, this.redirectUrl});

  @override
  ConsumerState<LockScreenPage> createState() => _LockScreenPageState();
}

class _LockScreenPageState extends ConsumerState<LockScreenPage> {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePin = true;
  String? _errorMessage;
  bool _biometricAttempted = false;

  @override
  void initState() {
    super.initState();
    // Try biometric auth first if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricAuth();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometricAuth() async {
    final security = ref.read(securityProvider);
    
    if (!security.isBiometricEnabled || !security.canCheckBiometrics) {
      return;
    }
    
    if (_biometricAttempted) return;
    _biometricAttempted = true;
    
    setState(() {
      _isLoading = true;
    });

    final biometricService = BiometricService();
    final result = await biometricService.authenticate(
      localizedReason: '请验证身份以解锁应用',
      useFallback: true,
    );

    setState(() {
      _isLoading = false;
    });

    if (result == BiometricAuthResult.success) {
      _onUnlockSuccess();
    } else if (result == BiometricAuthResult.fallbackRequested) {
      // User requested PIN fallback
      setState(() {});
    }
  }

  Future<void> _verifyPin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final pin = _pinController.text;
    final success = await ref.read(securityProvider.notifier).verifyPin(pin);

    setState(() {
      _isLoading = false;
    });

    if (success) {
      _onUnlockSuccess();
    } else {
      setState(() {
        _errorMessage = 'PIN码错误，请重试';
      });
      _pinController.clear();
      
      // Haptic feedback
      HapticFeedback.heavyImpact();
    }
  }

  void _onUnlockSuccess() {
    // Mark app as unlocked
    markAppUnlocked();
    // Navigate to the intended destination or home
    final destination = widget.redirectUrl ?? '/home';
    context.go(destination);
  }

  Future<void> _showBiometricPrompt() async {
    setState(() {
      _isLoading = true;
    });

    final biometricService = BiometricService();
    final result = await biometricService.authenticate(
      localizedReason: '请验证身份以解锁应用',
      useFallback: true,
    );

    setState(() {
      _isLoading = false;
    });

    if (result == BiometricAuthResult.success) {
      _onUnlockSuccess();
    } else if (result != BiometricAuthResult.userCancel) {
      // Show error message
      setState(() {
        _errorMessage = _getBiometricErrorMessage(result);
      });
    }
  }

  String _getBiometricErrorMessage(BiometricAuthResult result) {
    return switch (result) {
      BiometricAuthResult.failed => '验证失败，请重试',
      BiometricAuthResult.notAvailable => '生物识别不可用',
      BiometricAuthResult.notEnrolled => '未设置生物识别',
      BiometricAuthResult.lockedOut => '尝试次数过多，请稍后重试',
      BiometricAuthResult.permanentlyLockedOut => '生物识别已锁定，请使用PIN码',
      BiometricAuthResult.error => '发生错误，请重试',
      _ => '验证失败',
    };
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    final biometricService = BiometricService();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  '本地金融管家',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请验证身份以继续',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Biometric button if enabled
                if (security.isBiometricEnabled && security.canCheckBiometrics) ...[
                  FutureBuilder<List<BiometricType>>(
                    future: biometricService.getAvailableBiometrics(),
                    builder: (context, snapshot) {
                      final biometrics = snapshot.data ?? [];
                      final hasFace = biometrics.contains(BiometricType.face);
                      
                      return _isLoading
                          ? const CircularProgressIndicator()
                          : _BiometricButton(
                              biometricType: hasFace 
                                  ? BiometricType.face 
                                  : BiometricType.fingerprint,
                              onPressed: _showBiometricPrompt,
                            );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '或使用PIN码',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // PIN input
                if (security.hasPin) ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _pinController,
                          obscureText: _obscurePin,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: InputDecoration(
                            hintText: '••••••',
                            errorText: _errorMessage,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePin ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () => setState(() => _obscurePin = !_obscurePin),
                            ),
                          ),
                          onFieldSubmitted: (_) => _verifyPin(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入PIN码';
                            }
                            if (value.length < 4) {
                              return 'PIN码至少4位';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _verifyPin,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('解锁'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Password fallback if no PIN
                if (security.hasPassword && !security.hasPin) ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _pinController,
                          obscureText: _obscurePin,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: '密码',
                            hintText: '请输入密码',
                            prefixIcon: const Icon(Icons.lock),
                            errorText: _errorMessage,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePin ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () => setState(() => _obscurePin = !_obscurePin),
                            ),
                          ),
                          onFieldSubmitted: (_) => _verifyPassword(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入密码';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _verifyPassword,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('解锁'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _verifyPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final password = _pinController.text;
    final success = await ref.read(securityProvider.notifier).verifyPassword(password);

    setState(() {
      _isLoading = false;
    });

    if (success) {
      _onUnlockSuccess();
    } else {
      setState(() {
        _errorMessage = '密码错误，请重试';
      });
      _pinController.clear();
      HapticFeedback.heavyImpact();
    }
  }
}

/// Biometric authentication button
class _BiometricButton extends StatelessWidget {
  final BiometricType biometricType;
  final VoidCallback onPressed;

  const _BiometricButton({
    required this.biometricType,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isFace = biometricType == BiometricType.face;
    
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFace ? Icons.face : Icons.fingerprint,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              isFace ? '面容解锁' : '指纹解锁',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

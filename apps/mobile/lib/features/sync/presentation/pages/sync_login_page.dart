// DISABLED: sync package is temporarily disabled
/*
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sync/sync.dart';
import '../../data/auth_provider_impl.dart';

/// Login/Register page for sync service.
/// 
/// Provides forms for server URL, email, and password input.
/// Supports both login and registration modes.
class SyncLoginPage extends ConsumerStatefulWidget {
  const SyncLoginPage({super.key});

  @override
  ConsumerState<SyncLoginPage> createState() => _SyncLoginPageState();
}

class _SyncLoginPageState extends ConsumerState<SyncLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _serverUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegisterMode ? '注册账户' : '登录'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(context),
              
              const SizedBox(height: 32),
              
              // Server URL field
              _buildServerUrlField(context),
              
              const SizedBox(height: 20),
              
              // Email field
              _buildEmailField(context),
              
              const SizedBox(height: 20),
              
              // Password field
              _buildPasswordField(context),
              
              // Confirm password field (register mode only)
              if (_isRegisterMode) ...[
                const SizedBox(height: 20),
                _buildConfirmPasswordField(context),
              ],
              
              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _buildErrorMessage(context),
              ],
              
              const SizedBox(height: 32),
              
              // Submit button
              _buildSubmitButton(context),
              
              const SizedBox(height: 16),
              
              // Toggle mode button
              _buildToggleModeButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.cloud_sync,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '多设备同步',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isRegisterMode
              ? '创建账户以启用跨设备同步'
              : '登录您的同步账户',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildServerUrlField(BuildContext context) {
    return TextFormField(
      controller: _serverUrlController,
      decoration: InputDecoration(
        labelText: '服务器地址',
        hintText: 'https://sync.example.com',
        prefixIcon: const Icon(Icons.dns),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入服务器地址';
        }
        if (!value.startsWith('http://') && !value.startsWith('https://')) {
          return '请输入有效的 URL (http:// 或 https://)';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: '邮箱地址',
        hintText: 'your@email.com',
        prefixIcon: const Icon(Icons.email),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入邮箱地址';
        }
        if (!value.contains('@') || !value.contains('.')) {
          return '请输入有效的邮箱地址';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        labelText: '密码',
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      obscureText: _obscurePassword,
      textInputAction: _isRegisterMode ? TextInputAction.next : TextInputAction.done,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入密码';
        }
        if (value.length < 8) {
          return '密码至少需要8个字符';
        }
        return null;
      },
      onFieldSubmitted: (_) {
        if (!_isRegisterMode) {
          _submit();
        }
      },
    );
  }

  Widget _buildConfirmPasswordField(BuildContext context) {
    return TextFormField(
      controller: _confirmPasswordController,
      decoration: InputDecoration(
        labelText: '确认密码',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      obscureText: _obscureConfirmPassword,
      textInputAction: TextInputAction.done,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请确认密码';
        }
        if (value != _passwordController.text) {
          return '两次输入的密码不一致';
        }
        return null;
      },
      onFieldSubmitted: (_) => _submit(),
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return FilledButton(
      onPressed: _isLoading ? null : _submit,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              _isRegisterMode ? '注册' : '登录',
              style: const TextStyle(fontSize: 16),
            ),
    );
  }

  Widget _buildToggleModeButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        setState(() {
          _isRegisterMode = !_isRegisterMode;
          _errorMessage = null;
        });
      },
      child: Text(
        _isRegisterMode
            ? '已有账户？点击登录'
            : '没有账户？点击注册',
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final serverUrl = _serverUrlController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final authProvider = SyncAuthProviderImpl(serverUrl: serverUrl);
      
      final result = _isRegisterMode
          ? await authProvider.register(email, password)
          : await authProvider.login(email, password);

      if (result.success) {
        // Save sync config
        final config = SyncConfig(
          serverUrl: serverUrl,
          databaseName: 'finance_sync',
          schema: _getDefaultSchema(), // Would need actual schema
          authProvider: authProvider,
        );
        
        await config.save();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isRegisterMode ? '注册成功' : '登录成功'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/settings/sync');
        }
      } else {
        setState(() {
          _errorMessage = result.error ?? '操作失败，请重试';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '网络错误: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Placeholder - would need actual schema from the app
  Schema _getDefaultSchema() {
    // This would be the actual PowerSync schema
    // For now, return an empty schema
    return Schema([]);
  }
}
*/

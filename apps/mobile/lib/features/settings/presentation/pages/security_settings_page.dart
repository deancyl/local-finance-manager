import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../data/security_provider.dart';

class SecuritySettingsPage extends ConsumerWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(securityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('安全设置'),
      ),
      body: ListView(
        children: [
          // Password Protection Section
          _buildSectionHeader(context, '密码保护'),
          _buildPasswordTile(context, ref, security),
          
          const Divider(),
          
          // PIN Section
          _buildSectionHeader(context, 'PIN码'),
          _buildPinTile(context, ref, security),
          
          const Divider(),
          
          // Biometric Section
          if (security.canCheckBiometrics) ...[
            _buildSectionHeader(context, '生物识别'),
            _buildBiometricTile(context, ref, security),
            const Divider(),
          ],
          
          // Auto-lock Section
          _buildSectionHeader(context, '自动锁定'),
          _buildAutoLockTile(context, ref, security),
          
          const Divider(),
          
          // Change Password Section
          if (security.hasPassword) ...[
            _buildSectionHeader(context, '密码管理'),
            _buildChangePasswordTile(context, ref),
            _buildClearPasswordTile(context, ref),
          ],
          
          if (security.hasPin) ...[
            _buildSectionHeader(context, 'PIN管理'),
            _buildClearPinTile(context, ref),
          ],
          
          const SizedBox(height: 24),
          
          // Info section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '安全提示',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 启用密码或PIN后，每次打开应用都需要验证\n'
                      '• 生物识别提供更便捷的解锁方式\n'
                      '• 自动锁定在应用后台运行指定时间后生效',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildPasswordTile(
    BuildContext context,
    WidgetRef ref,
    SecuritySettings security,
  ) {
    return SwitchListTile(
      secondary: const Icon(Icons.lock),
      title: const Text('密码保护'),
      subtitle: Text(
        security.hasPassword
            ? (security.isPasswordEnabled ? '已启用' : '已设置但未启用')
            : '未设置密码',
      ),
      value: security.isPasswordEnabled,
      onChanged: security.hasPassword
          ? (value) async {
              if (value) {
                // Verify password before enabling
                final verified = await _showPasswordDialog(context, ref, '验证密码');
                if (verified == true) {
                  await ref.read(securityProvider.notifier).setPasswordEnabled(true);
                }
              } else {
                await ref.read(securityProvider.notifier).setPasswordEnabled(false);
              }
            }
          : null,
    );
  }

  Widget _buildPinTile(
    BuildContext context,
    WidgetRef ref,
    SecuritySettings security,
  ) {
    return SwitchListTile(
      secondary: const Icon(Icons.pin),
      title: const Text('PIN码'),
      subtitle: Text(
        security.hasPin
            ? (security.isPinEnabled ? '已启用' : '已设置但未启用')
            : '未设置PIN码',
      ),
      value: security.isPinEnabled,
      onChanged: security.hasPin
          ? (value) async {
              if (value) {
                final verified = await _showPinDialog(context, ref, '验证PIN');
                if (verified == true) {
                  await ref.read(securityProvider.notifier).setPinEnabled(true);
                }
              } else {
                await ref.read(securityProvider.notifier).setPinEnabled(false);
              }
            }
          : null,
    );
  }

  Widget _buildBiometricTile(
    BuildContext context,
    WidgetRef ref,
    SecuritySettings security,
  ) {
    return FutureBuilder<List<BiometricType>>(
      future: ref.read(securityProvider.notifier).getAvailableBiometrics(),
      builder: (context, snapshot) {
        final biometrics = snapshot.data ?? [];
        String subtitle = '检测中...';
        
        if (biometrics.isNotEmpty) {
          final types = biometrics.map((type) {
            switch (type) {
              case BiometricType.fingerprint:
                return '指纹';
              case BiometricType.face:
                return '面容';
              case BiometricType.iris:
                return '虹膜';
              case BiometricType.weak:
              case BiometricType.strong:
                return '生物识别';
            }
          }).join('、');
          subtitle = '支持: $types';
        } else if (snapshot.hasData) {
          subtitle = '未检测到生物识别设备';
        }

        return SwitchListTile(
          secondary: Icon(
            biometrics.contains(BiometricType.face)
                ? Icons.face
                : Icons.fingerprint,
          ),
          title: const Text('生物识别解锁'),
          subtitle: Text(subtitle),
          value: security.isBiometricEnabled,
          onChanged: biometrics.isNotEmpty
              ? (value) async {
                  if (value) {
                    // Test biometric auth before enabling
                    final success = await ref
                        .read(securityProvider.notifier)
                        .authenticateWithBiometrics();
                    if (success) {
                      await ref
                          .read(securityProvider.notifier)
                          .setBiometricEnabled(true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('生物识别已启用')),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('验证失败，无法启用')),
                        );
                      }
                    }
                  } else {
                    await ref
                        .read(securityProvider.notifier)
                        .setBiometricEnabled(false);
                  }
                }
              : null,
        );
      },
    );
  }

  Widget _buildAutoLockTile(
    BuildContext context,
    WidgetRef ref,
    SecuritySettings security,
  ) {
    final options = [1, 2, 5, 10, 15, 30];
    
    return ListTile(
      leading: const Icon(Icons.timer),
      title: const Text('自动锁定时间'),
      subtitle: Text('${security.autoLockTimeoutMinutes} 分钟'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showAutoLockDialog(context, ref, security.autoLockTimeoutMinutes, options),
    );
  }

  Widget _buildChangePasswordTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.edit),
      title: const Text('修改密码'),
      subtitle: const Text('更改当前密码'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showChangePasswordDialog(context, ref),
    );
  }

  Widget _buildClearPasswordTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(
        Icons.delete_outline,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(
        '删除密码',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      subtitle: const Text('移除密码保护'),
      onTap: () => _showDeletePasswordDialog(context, ref),
    );
  }

  Widget _buildClearPinTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(
        Icons.delete_outline,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(
        '删除PIN码',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      subtitle: const Text('移除PIN码保护'),
      onTap: () => _showDeletePinDialog(context, ref),
    );
  }

  Future<bool?> _showPasswordDialog(
    BuildContext context,
    WidgetRef ref,
    String title, {
    bool isSetup = false,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  hintText: '请输入密码',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }
                  if (isSetup && value.length < 6) {
                    return '密码至少6位';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                if (isSetup) {
                  final success = await ref
                      .read(securityProvider.notifier)
                      .setPassword(controller.text);
                  Navigator.pop(context, success);
                } else {
                  final verified = await ref
                      .read(securityProvider.notifier)
                      .verifyPassword(controller.text);
                  Navigator.pop(context, verified);
                }
              }
            },
            child: Text(isSetup ? '设置' : '验证'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showPinDialog(
    BuildContext context,
    WidgetRef ref,
    String title, {
    bool isSetup = false,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'PIN码',
                  hintText: '请输入4-6位数字',
                  prefixIcon: Icon(Icons.pin),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入PIN码';
                  }
                  if (value.length < 4 || value.length > 6) {
                    return 'PIN码需要4-6位';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                if (isSetup) {
                  final success = await ref
                      .read(securityProvider.notifier)
                      .setPin(controller.text);
                  Navigator.pop(context, success);
                } else {
                  final verified = await ref
                      .read(securityProvider.notifier)
                      .verifyPin(controller.text);
                  Navigator.pop(context, verified);
                }
              }
            },
            child: Text(isSetup ? '设置' : '验证'),
          ),
        ],
      ),
    );
  }

  void _showAutoLockDialog(
    BuildContext context,
    WidgetRef ref,
    int currentValue,
    List<int> options,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自动锁定时间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((minutes) {
            return RadioListTile<int>(
              title: Text('$minutes 分钟'),
              value: minutes,
              groupValue: currentValue,
              onChanged: (value) async {
                if (value != null) {
                  await ref.read(securityProvider.notifier).setAutoLockTimeout(value);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) async {
    // First verify old password
    final verified = await _showPasswordDialog(context, ref, '输入当前密码');
    if (verified != true || !context.mounted) return;

    // Then set new password
    final success = await _showPasswordDialog(context, ref, '设置新密码', isSetup: true);
    if (success == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码已更改')),
      );
    }
  }

  void _showDeletePasswordDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除密码吗？删除后将无法使用密码保护功能。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Verify password before deleting
      final verified = await _showPasswordDialog(context, ref, '验证密码');
      if (verified == true && context.mounted) {
        await ref.read(securityProvider.notifier).clearPassword();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码已删除')),
        );
      }
    }
  }

  void _showDeletePinDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除PIN码吗？删除后将无法使用PIN码保护功能。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Verify PIN before deleting
      final verified = await _showPinDialog(context, ref, '验证PIN');
      if (verified == true && context.mounted) {
        await ref.read(securityProvider.notifier).clearPin();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN码已删除')),
        );
      }
    }
  }
}

/// Dialog for setting up password/PIN for the first time
class SetupSecurityDialog extends ConsumerStatefulWidget {
  final bool isPin;

  const SetupSecurityDialog({
    super.key,
    this.isPin = false,
  });

  @override
  ConsumerState<SetupSecurityDialog> createState() => _SetupSecurityDialogState();
}

class _SetupSecurityDialogState extends ConsumerState<SetupSecurityDialog> {
  final _controller = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureText = true;
  bool _obscureConfirmText = true;

  @override
  void dispose() {
    _controller.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isPin ? '设置PIN码' : '设置密码'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _controller,
              obscureText: _obscureText,
              keyboardType: widget.isPin ? TextInputType.number : TextInputType.text,
              inputFormatters: widget.isPin
                  ? [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ]
                  : null,
              decoration: InputDecoration(
                labelText: widget.isPin ? 'PIN码' : '密码',
                hintText: widget.isPin ? '请输入4-6位数字' : '请输入密码（至少6位）',
                prefixIcon: Icon(widget.isPin ? Icons.pin : Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return widget.isPin ? '请输入PIN码' : '请输入密码';
                }
                if (widget.isPin) {
                  if (value.length < 4 || value.length > 6) {
                    return 'PIN码需要4-6位';
                  }
                } else {
                  if (value.length < 6) {
                    return '密码至少6位';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirmText,
              keyboardType: widget.isPin ? TextInputType.number : TextInputType.text,
              inputFormatters: widget.isPin
                  ? [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ]
                  : null,
              decoration: InputDecoration(
                labelText: '确认${widget.isPin ? 'PIN码' : '密码'}',
                hintText: '请再次输入',
                prefixIcon: const Icon(Icons.check),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmText ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureConfirmText = !_obscureConfirmText),
                ),
              ),
              validator: (value) {
                if (value != _controller.text) {
                  return '两次输入不一致';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              bool success;
              if (widget.isPin) {
                success = await ref
                    .read(securityProvider.notifier)
                    .setPin(_controller.text);
              } else {
                success = await ref
                    .read(securityProvider.notifier)
                    .setPassword(_controller.text);
              }
              Navigator.pop(context, success);
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

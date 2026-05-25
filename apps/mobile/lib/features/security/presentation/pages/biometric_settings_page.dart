import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/biometric_service.dart';
import '../../../settings/data/security_provider.dart';

/// Biometric authentication settings page
class BiometricSettingsPage extends ConsumerWidget {
  const BiometricSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(securityProvider);
    final biometricService = BiometricService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('生物识别设置'),
      ),
      body: ListView(
        children: [
          // Header card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.fingerprint,
                      size: 48,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '生物识别解锁',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '使用指纹或面容快速解锁应用',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Device status
          _buildDeviceStatusSection(context, biometricService),

          const Divider(),

          // Biometric toggle
          if (security.canCheckBiometrics) ...[
            _buildBiometricToggle(context, ref, security, biometricService),
            const Divider(),
          ],

          // Setup PIN requirement
          if (!security.hasPin && !security.hasPassword) ...[
            _buildSetupPrompt(context, ref),
            const Divider(),
          ],

          // Security options
          _buildSecurityOptions(context, ref, security),

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
                          '关于生物识别',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• 生物识别使用您设备的指纹或面容传感器\n'
                      '• 您的生物特征数据由设备安全存储，应用无法访问\n'
                      '• 启用生物识别前需要先设置PIN码或密码作为备用\n'
                      '• 如果生物识别失败，可使用PIN码/密码解锁',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Troubleshooting
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '故障排除',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• 如果生物识别不可用，请检查设备设置\n'
                      '• 确保已在设备设置中录入指纹或面容\n'
                      '• 某些设备可能需要设置屏幕锁定\n'
                      '• 如果多次验证失败，生物识别可能会被暂时锁定',
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

  Widget _buildDeviceStatusSection(
    BuildContext context,
    BiometricService biometricService,
  ) {
    return FutureBuilder<bool>(
      future: biometricService.isDeviceSupported(),
      builder: (context, supportedSnapshot) {
        final isSupported = supportedSnapshot.data ?? false;
        
        return FutureBuilder<List<BiometricType>>(
          future: biometricService.getAvailableBiometrics(),
          builder: (context, biometricsSnapshot) {
            final biometrics = biometricsSnapshot.data ?? [];
            
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '设备状态',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatusTile(
                    icon: Icons.devices,
                    title: '硬件支持',
                    subtitle: isSupported 
                        ? '设备支持生物识别' 
                        : '设备不支持生物识别',
                    isAvailable: isSupported,
                  ),
                  if (biometrics.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _StatusTile(
                      icon: biometrics.contains(BiometricType.face)
                          ? Icons.face
                          : Icons.fingerprint,
                      title: '可用方式',
                      subtitle: biometrics
                          .map((t) => biometricService.getBiometricTypeName(t))
                          .join('、'),
                      isAvailable: true,
                    ),
                  ],
                  if (biometrics.isEmpty && isSupported) ...[
                    const SizedBox(height: 8),
                    _StatusTile(
                      icon: Icons.warning_amber,
                      title: '未录入生物特征',
                      subtitle: '请在设备设置中添加指纹或面容',
                      isAvailable: false,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBiometricToggle(
    BuildContext context,
    WidgetRef ref,
    SecuritySettings security,
    BiometricService biometricService,
  ) {
    return FutureBuilder<List<BiometricType>>(
      future: biometricService.getAvailableBiometrics(),
      builder: (context, snapshot) {
        final biometrics = snapshot.data ?? [];
        
        if (biometrics.isEmpty) {
          return ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('生物识别解锁'),
            subtitle: const Text('未检测到可用的生物识别'),
            trailing: const Icon(Icons.info_outline),
            enabled: false,
          );
        }

        final primaryType = biometrics.first;
        final typeName = biometricService.getBiometricTypeName(primaryType);

        return SwitchListTile(
          secondary: Icon(
            primaryType == BiometricType.face ? Icons.face : Icons.fingerprint,
          ),
          title: Text('$typeName解锁'),
          subtitle: Text(
            security.isBiometricEnabled 
                ? '已启用' 
                : '使用$typeName快速解锁应用',
          ),
          value: security.isBiometricEnabled,
          onChanged: (value) async {
            if (value) {
              // Require PIN/Password setup first
              if (!security.hasPin && !security.hasPassword) {
                _showSetupRequiredDialog(context, ref);
                return;
              }

              // Test biometric before enabling
              final result = await biometricService.authenticate(
                localizedReason: '请验证以启用生物识别解锁',
                useFallback: true,
              );

              if (result == BiometricAuthResult.success) {
                await ref.read(securityProvider.notifier).setBiometricEnabled(true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$typeName解锁已启用')),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('验证失败: ${_getErrorMessage(result)}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            } else {
              await ref.read(securityProvider.notifier).setBiometricEnabled(false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('生物识别解锁已关闭')),
                );
              }
            }
          },
        );
      },
    );
  }

  Widget _buildSetupPrompt(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '需要设置备用验证方式',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '启用生物识别前，请先设置PIN码或密码作为备用验证方式。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.pin),
                      label: const Text('设置PIN码'),
                      onPressed: () => _showSetupPinDialog(context, ref),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.password),
                      label: const Text('设置密码'),
                      onPressed: () => _showSetupPasswordDialog(context, ref),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityOptions(
    BuildContext context,
    WidgetRef ref,
    SecuritySettings security,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '安全选项',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            secondary: const Icon(Icons.lock_clock),
            title: const Text('应用启动时验证'),
            subtitle: const Text('每次打开应用都需要验证'),
            value: security.isPasswordEnabled || security.isPinEnabled,
            onChanged: (security.hasPin || security.hasPassword)
                ? (value) async {
                    if (value) {
                      // Enable whichever is available
                      if (security.hasPin) {
                        await ref.read(securityProvider.notifier).setPinEnabled(true);
                      } else if (security.hasPassword) {
                        await ref.read(securityProvider.notifier).setPasswordEnabled(true);
                      }
                    } else {
                      await ref.read(securityProvider.notifier).setPinEnabled(false);
                      await ref.read(securityProvider.notifier).setPasswordEnabled(false);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('自动锁定时间'),
            subtitle: Text('${security.autoLockTimeoutMinutes} 分钟后锁定'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAutoLockDialog(context, ref, security.autoLockTimeoutMinutes),
          ),
        ],
      ),
    );
  }

  String _getErrorMessage(BiometricAuthResult result) {
    return switch (result) {
      BiometricAuthResult.failed => '验证失败',
      BiometricAuthResult.notAvailable => '不可用',
      BiometricAuthResult.notEnrolled => '未录入生物特征',
      BiometricAuthResult.lockedOut => '尝试次数过多',
      BiometricAuthResult.permanentlyLockedOut => '已锁定',
      BiometricAuthResult.userCancel => '用户取消',
      BiometricAuthResult.error => '发生错误',
      _ => '未知错误',
    };
  }

  void _showSetupRequiredDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要设置备用验证'),
        content: const Text('启用生物识别前，请先设置PIN码或密码作为备用验证方式。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _showSetupPinDialog(context, ref);
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSetupPinDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置PIN码'),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: '确认PIN码',
                  hintText: '请再次输入',
                  prefixIcon: Icon(Icons.check),
                ),
                validator: (value) {
                  if (value != controller.text) {
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
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final success = await ref
                    .read(securityProvider.notifier)
                    .setPin(controller.text);
                if (success && context.mounted) {
                  await ref.read(securityProvider.notifier).setPinEnabled(true);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN码已设置')),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSetupPasswordDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置密码'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  hintText: '请输入密码（至少6位）',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }
                  if (value.length < 6) {
                    return '密码至少6位';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '确认密码',
                  hintText: '请再次输入',
                  prefixIcon: Icon(Icons.check),
                ),
                validator: (value) {
                  if (value != controller.text) {
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
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final success = await ref
                    .read(securityProvider.notifier)
                    .setPassword(controller.text);
                if (success && context.mounted) {
                  await ref.read(securityProvider.notifier).setPasswordEnabled(true);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('密码已设置')),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAutoLockDialog(BuildContext context, WidgetRef ref, int currentValue) {
    final options = [1, 2, 5, 10, 15, 30];
    
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
}

/// Status tile widget
class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isAvailable;

  const _StatusTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isAvailable
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isAvailable ? Icons.check_circle : Icons.error,
            color: isAvailable
                ? Colors.green
                : Theme.of(context).colorScheme.error,
            size: 20,
          ),
        ],
      ),
    );
  }
}

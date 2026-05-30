import 'package:flutter/material.dart';
import 'onboarding_slide_base.dart';

/// Security slide for password protection setup
class SecuritySlide extends StatelessWidget {
  const SecuritySlide({super.key});
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return OnboardingSlide(
      title: '安全保护',
      subtitle: '设置密码保护您的财务数据\nSecure your data with PIN or biometric',
      icon: Icons.shield_rounded,
      iconColor: Colors.indigo,
      features: [
        FeatureItem(
          icon: Icons.pin_rounded,
          title: 'PIN码',
          description: '快速解锁，安全便捷',
          color: Colors.indigo,
        ),
        FeatureItem(
          icon: Icons.fingerprint_rounded,
          title: '生物识别',
          description: '指纹或面容解锁',
          color: Colors.teal,
        ),
        FeatureItem(
          icon: Icons.lock_rounded,
          title: '自动锁定',
          description: '离开应用自动锁定',
          color: Colors.amber.shade700,
        ),
      ],
    );
  }
}
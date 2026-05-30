import 'package:flutter/material.dart';
import 'onboarding_slide_base.dart';

/// Welcome slide for onboarding flow
class WelcomeSlide extends StatelessWidget {
  const WelcomeSlide({super.key});
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return OnboardingSlide(
      title: '欢迎使用本地金融管家',
      subtitle: 'Your privacy-first finance manager\n本地优先，隐私至上',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: colorScheme.primary,
      features: [
        FeatureItem(
          icon: Icons.security_rounded,
          title: '本地存储',
          description: '所有数据存储在您的设备上',
          color: Colors.green,
        ),
        FeatureItem(
          icon: Icons.lock_rounded,
          title: '端到端加密',
          description: '军事级别的数据保护',
          color: Colors.blue,
        ),
        FeatureItem(
          icon: Icons.sync_rounded,
          title: '可选同步',
          description: '自托管同步服务器',
          color: Colors.purple,
        ),
      ],
    );
  }
}
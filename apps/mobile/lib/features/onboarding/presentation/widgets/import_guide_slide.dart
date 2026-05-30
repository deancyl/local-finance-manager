import 'package:flutter/material.dart';
import 'onboarding_slide_base.dart';

/// Import guide slide showing how to import data
class ImportGuideSlide extends StatelessWidget {
  const ImportGuideSlide({super.key});
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return OnboardingSlide(
      title: '导入账单',
      subtitle: '快速导入支付宝、微信账单\nImport from Alipay, WeChat Pay',
      icon: Icons.upload_file_rounded,
      iconColor: Colors.blue,
      features: [
        FeatureItem(
          icon: Icons.account_balance_wallet_rounded,
          title: '支付宝',
          description: '支持支付宝账单CSV导入',
          color: Colors.blue,
        ),
        FeatureItem(
          icon: Icons.chat_rounded,
          title: '微信支付',
          description: '支持微信账单CSV导入',
          color: Colors.green,
        ),
        FeatureItem(
          icon: Icons.account_balance_rounded,
          title: '银行账单',
          description: '工商、建设、中国银行等',
          color: Colors.red,
        ),
      ],
    );
  }
}
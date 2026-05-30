import 'package:flutter/material.dart';
import 'onboarding_slide_base.dart';

/// Concepts slide explaining basic accounting
class ConceptsSlide extends StatelessWidget {
  const ConceptsSlide({super.key});
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return OnboardingSlide(
      title: '核心概念',
      subtitle: '了解三个基础概念，轻松记账\nAccounts, Transactions, Categories',
      icon: Icons.book_rounded,
      iconColor: Colors.teal,
      features: [
        FeatureItem(
          icon: Icons.account_balance_rounded,
          title: '账户',
          description: '钱包、银行卡、支付宝、微信等',
          color: Colors.indigo,
        ),
        FeatureItem(
          icon: Icons.receipt_long_rounded,
          title: '交易',
          description: '每一笔收入或支出记录',
          color: Colors.orange,
        ),
        FeatureItem(
          icon: Icons.category_rounded,
          title: '分类',
          description: '餐饮、交通、购物等类别',
          color: Colors.pink,
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';

/// WeChat Pay export guide steps widget.
/// 
/// Provides step-by-step instructions for exporting transaction data
/// from WeChat Pay (微信支付) for import into the finance app.
class WechatGuideSteps extends StatelessWidget {
  const WechatGuideSteps({super.key});

  static const List<_GuideStep> _steps = [
    _GuideStep(
      number: 1,
      title: '打开微信 APP',
      description: '在手机上打开微信应用程序',
      icon: Icons.phone_android,
    ),
    _GuideStep(
      number: 2,
      title: '点击"我" → "服务" → "钱包"',
      description: '进入个人中心，找到服务选项，然后点击钱包',
      icon: Icons.person,
    ),
    _GuideStep(
      number: 3,
      title: '点击"账单" → 右上角"常见问题"',
      description: '在钱包页面点击账单，然后点击右上角的常见问题',
      icon: Icons.help_outline,
    ),
    _GuideStep(
      number: 4,
      title: '点击"下载账单"',
      description: '在常见问题页面找到并点击下载账单选项',
      icon: Icons.download,
    ),
    _GuideStep(
      number: 5,
      title: '选择"用于个人对账"',
      description: '选择账单用途为个人对账，这是导出交易记录的标准选项',
      icon: Icons.receipt_long,
    ),
    _GuideStep(
      number: 6,
      title: '选择时间范围，输入邮箱',
      description: '选择需要导出的时间范围，填写接收邮箱地址，确认后等待邮件',
      icon: Icons.email,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with WeChat branding
        _buildHeader(context),
        const SizedBox(height: 16),
        
        // Steps
        ..._steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isLast = index == _steps.length - 1;
          
          return _buildStepItem(
            context: context,
            step: step,
            isLast: isLast,
            accentColor: colorScheme.tertiary,
          );
        }),
        
        const SizedBox(height: 24),
        
        // Tips card
        _buildTipsCard(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.tertiary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.chat,
              size: 32,
              color: colorScheme.tertiary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '微信支付导出指南',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '按以下步骤导出您的交易记录',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required BuildContext context,
    required _GuideStep step,
    required bool isLast,
    required Color accentColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number badge and vertical line
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      '${step.number}',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: accentColor.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        step.icon,
                        size: 24,
                        color: accentColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step.description,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
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
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Card(
      color: colorScheme.secondaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 20,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  '温馨提示',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              context: context,
              icon: Icons.schedule,
              text: '导出文件通常在几分钟内发送到邮箱',
            ),
            const SizedBox(height: 8),
            _buildTipItem(
              context: context,
              icon: Icons.folder_zip,
              text: '收到的文件通常是压缩包，请解压后选择CSV文件导入',
            ),
            const SizedBox(height: 8),
            _buildTipItem(
              context: context,
              icon: Icons.security,
              text: '交易流水证明不包含敏感支付密码信息',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem({
    required BuildContext context,
    required IconData icon,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Data class for guide steps.
class _GuideStep {
  final int number;
  final String title;
  final String description;
  final IconData icon;

  const _GuideStep({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });
}

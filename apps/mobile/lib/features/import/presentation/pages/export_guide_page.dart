import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/alipay_guide_steps.dart';
import '../widgets/wechat_guide_steps.dart';

/// Export guide page with step-by-step instructions for Alipay and WeChat Pay.
/// 
/// Provides detailed instructions on how to export transaction data from
/// popular Chinese payment platforms for import into the finance app.
class ExportGuidePage extends StatefulWidget {
  const ExportGuidePage({super.key});

  @override
  State<ExportGuidePage> createState() => _ExportGuidePageState();
}

class _ExportGuidePageState extends State<ExportGuidePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('如何导出账单'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_wallet), text: '支付宝'),
            Tab(icon: Icon(Icons.chat), text: '微信支付'),
            Tab(icon: Icon(Icons.help_outline), text: '常见问题'),
          ],
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAlipayTab(),
          _buildWechatTab(),
          _buildFAQTab(),
        ],
      ),
    );
  }

  Widget _buildAlipayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: const AlipayGuideSteps(),
    );
  }

  Widget _buildWechatTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: const WechatGuideSteps(),
    );
  }

  Widget _buildFAQTab() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.help_outline,
                  size: 32,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '常见问题解答',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // FAQ Items
          _buildFAQItem(
            question: '导出的文件是什么格式？',
            answer: '支付宝和微信支付导出的文件通常是CSV格式或压缩包（ZIP）。'
                '如果是压缩包，请先解压，然后选择CSV文件导入。'
                '本应用支持CSV、XLS、XLSX格式。',
            icon: Icons.insert_drive_file,
          ),
          _buildFAQItem(
            question: '为什么导入时提示编码错误？',
            answer: '部分银行导出的CSV文件使用GBK编码而非UTF-8。'
                '本应用支持自动检测编码，如果自动检测失败，'
                '可以在导入页面点击"手动选择"编码，尝试GBK或GB2312编码。',
            icon: Icons.code,
          ),
          _buildFAQItem(
            question: '导出的文件包含敏感信息吗？',
            answer: '交易流水证明仅包含交易时间、金额、商户名称等基本信息，'
                '不包含支付密码、银行卡号等敏感信息。'
                '导出的文件在本地加密存储，确保您的隐私安全。',
            icon: Icons.security,
          ),
          _buildFAQItem(
            question: '可以导出多长时间的数据？',
            answer: '支付宝和微信支付通常支持导出最近3个月到1年的数据。'
                '建议分批导出，每次导出3个月的数据，'
                '这样可以避免文件过大导致处理缓慢。',
            icon: Icons.date_range,
          ),
          _buildFAQItem(
            question: '导入后数据可以修改吗？',
            answer: '导入的交易记录可以随时修改、删除或重新分类。'
                '在交易列表中点击任意记录即可编辑。'
                '您也可以为交易添加备注或更改分类。',
            icon: Icons.edit,
          ),
          _buildFAQItem(
            question: '重复导入会怎样？',
            answer: '本应用会自动检测重复交易。如果导入的交易与已有交易'
                '日期、金额、描述相同，系统会自动跳过并提示。'
                '您可以选择是否导入重复记录。',
            icon: Icons.content_copy,
          ),
          _buildFAQItem(
            question: '为什么有些交易没有自动分类？',
            answer: '系统会根据交易描述自动匹配分类，但部分商户名称可能无法识别。'
                '您可以在导入后手动调整分类，'
                '系统会学习您的分类习惯，提高未来的识别准确率。',
            icon: Icons.category,
          ),
          _buildFAQItem(
            question: '导入失败怎么办？',
            answer: '请检查：\n'
                '1. 文件格式是否正确（CSV/XLS/XLSX）\n'
                '2. 文件是否损坏（尝试重新导出）\n'
                '3. 编码是否正确（尝试手动选择编码）\n'
                '如果问题仍然存在，请联系开发者反馈。',
            icon: Icons.error_outline,
          ),

          const SizedBox(height: 24),

          // Support card
          Card(
            color: colorScheme.secondaryContainer.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.support_agent,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '需要更多帮助？',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '如果您在使用过程中遇到任何问题，欢迎通过以下方式获取帮助：',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildContactItem(
                    icon: Icons.book,
                    text: '查看应用内教程',
                  ),
                  const SizedBox(height: 8),
                  _buildContactItem(
                    icon: Icons.feedback,
                    text: '在设置中提交反馈',
                  ),
                  const SizedBox(height: 8),
                  _buildContactItem(
                    icon: Icons.code,
                    text: '访问 GitHub 提交 Issue',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: ExpansionTile(
          leading: Icon(icon, color: colorScheme.primary),
          title: Text(
            question,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              answer,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

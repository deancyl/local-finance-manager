import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:database/database.dart';

import '../widgets/add_transaction_dialog.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  final String? transactionId;

  const AddTransactionPage({super.key, this.transactionId});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  Transaction? _transaction;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    if (widget.transactionId == null) return;

    // TODO: Load transaction from database using transactionId
    // For now, this is a placeholder - the actual implementation
    // would fetch the transaction from the database
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记一笔'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: AddTransactionDialog(transaction: _transaction),
        ),
      ),
    );
  }
}

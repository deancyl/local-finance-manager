import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:database/database.dart';

import '../widgets/add_transaction_dialog.dart';
import '../../data/transaction_provider.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  final String? transactionId;

  const AddTransactionPage({super.key, this.transactionId});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  Transaction? _transaction;
  List<Split> _splits = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    if (widget.transactionId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final db = ref.read(databaseProvider);
      
      // Load transaction from database
      final transaction = await db.transactionsDao.getById(widget.transactionId!);
      
      if (transaction != null) {
        // Load splits for this transaction
        final splits = await db.transactionsDao.getSplits(widget.transactionId!);
        
        setState(() {
          _transaction = transaction;
          _splits = splits;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        
        // Show error if transaction not found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到交易记录')),
          );
          context.go('/home');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载交易失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('记一笔'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_transaction != null ? '编辑交易' : '记一笔'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: AddTransactionDialog(
            transaction: _transaction,
          ),
        ),
      ),
    );
  }
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

    try {
      final db = ref.read(databaseProvider);
      final transaction = await db.transactionsDao.getById(widget.transactionId!);
      if (mounted && transaction != null) {
        setState(() => _transaction = transaction);
      }
    } catch (e) {
      // Log error but don't crash - graceful degradation
      debugPrint('Error loading transaction: $e');
    }
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

import 'package:flutter/material.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账户管理'),
      ),
      body: const Center(
        child: Text('账户管理页面 - 开发中'),
      ),
    );
  }
}
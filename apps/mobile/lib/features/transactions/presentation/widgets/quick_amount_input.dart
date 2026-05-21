import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Calculator-style quick amount input widget.
/// Provides a number pad for quick amount entry on mobile devices.
class QuickAmountInput extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool autoFocus;

  const QuickAmountInput({
    super.key,
    required this.controller,
    this.validator,
    this.autoFocus = false,
  });

  @override
  State<QuickAmountInput> createState() => _QuickAmountInputState();
}

class _QuickAmountInputState extends State<QuickAmountInput> {
  late TextEditingController _internalController;
  bool _showNumpad = false;

  @override
  void initState() {
    super.initState();
    _internalController = TextEditingController(text: widget.controller.text);
  }

  @override
  void dispose() {
    _internalController.dispose();
    super.dispose();
  }

  void _onKeyPressed(String key) {
    final currentText = _internalController.text;
    String newText;

    if (key == 'backspace') {
      if (currentText.isNotEmpty) {
        newText = currentText.substring(0, currentText.length - 1);
      } else {
        return;
      }
    } else if (key == '.') {
      // Only allow one decimal point
      if (currentText.contains('.')) {
        return;
      }
      newText = currentText.isEmpty ? '0.' : '$currentText.';
    } else if (key == '00') {
      newText = currentText.isEmpty ? '0' : '${currentText}00';
    } else {
      // Regular number
      if (currentText == '0' && key != '.') {
        newText = key;
      } else {
        newText = '$currentText$key';
      }
    }

    // Limit decimal places to 2
    if (newText.contains('.')) {
      final parts = newText.split('.');
      if (parts.length == 2 && parts[1].length > 2) {
        return;
      }
    }

    setState(() {
      _internalController.text = newText;
      widget.controller.text = newText;
    });
  }

  void _onClear() {
    setState(() {
      _internalController.clear();
      widget.controller.clear();
    });
  }

  void _toggleNumpad() {
    setState(() {
      _showNumpad = !_showNumpad;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Amount display field
        GestureDetector(
          onTap: _toggleNumpad,
          child: AbsorbPointer(
            absorbing: false,
            child: TextFormField(
              controller: _internalController,
              decoration: InputDecoration(
                labelText: '金额',
                prefixText: '¥ ',
                prefixIcon: const Icon(Icons.attach_money),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_internalController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: _onClear,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    IconButton(
                      icon: Icon(_showNumpad ? Icons.keyboard : Icons.calculate),
                      onPressed: _toggleNumpad,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: widget.validator,
              onChanged: (value) {
                widget.controller.text = value;
              },
            ),
          ),
        ),

        // Calculator numpad
        if (_showNumpad) ...[
          const SizedBox(height: 16),
          _buildNumpad(),
        ],
      ],
    );
  }

  Widget _buildNumpad() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _buildNumpadRow(['7', '8', '9']),
          const SizedBox(height: 8),
          _buildNumpadRow(['4', '5', '6']),
          const SizedBox(height: 8),
          _buildNumpadRow(['1', '2', '3']),
          const SizedBox(height: 8),
          _buildNumpadRow(['.', '0', '00']),
          const SizedBox(height: 8),
          _buildNumpadRow(['backspace', 'clear', 'done']),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildNumpadKey(key),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumpadKey(String key) {
    String label;
    IconData? icon;
    VoidCallback onTap;

    switch (key) {
      case 'backspace':
        icon = Icons.backspace_outlined;
        label = '';
        onTap = () => _onKeyPressed('backspace');
        break;
      case 'clear':
        label = '清除';
        onTap = _onClear;
        break;
      case 'done':
        label = '完成';
        onTap = () {
          setState(() => _showNumpad = false);
        };
        break;
      default:
        label = key;
        onTap = () => _onKeyPressed(key);
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, size: 24)
              : Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
        ),
      ),
    );
  }
}

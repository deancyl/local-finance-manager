import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finance_app/features/voice/presentation/widgets/voice_input_button.dart';

/// Calculator-style quick amount input widget.
/// Provides a number pad for quick amount entry on mobile devices.
/// Supports calculator expressions and quick amount buttons.
class QuickAmountInput extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool autoFocus;
  final bool enableVoiceInput;
  final bool enableQuickAmounts;
  final List<double> quickAmounts;
  final void Function(String)? onChanged;

  const QuickAmountInput({
    super.key,
    required this.controller,
    this.validator,
    this.autoFocus = false,
    this.enableVoiceInput = true,
    this.enableQuickAmounts = true,
    this.quickAmounts = const [10, 50, 100, 500, 1000],
    this.onChanged,
  });

  @override
  State<QuickAmountInput> createState() => _QuickAmountInputState();
}

class _QuickAmountInputState extends State<QuickAmountInput> {
  late TextEditingController _internalController;
  bool _showNumpad = false;
  String _expression = '';
  bool _showExpression = false;

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
    } else if (key == '+' || key == '-' || key == '*' || key == '/') {
      // Calculator expression support
      _expression = '$currentText $key ';
      _showExpression = true;
      setState(() {});
      return;
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
    widget.onChanged?.call(newText);
  }

  /// Evaluate simple calculator expression
  double? _evaluateExpression(String expression) {
    try {
      // Simple expression parser for +, -, *, /
      final tokens = expression.trim().split(' ').where((t) => t.isNotEmpty).toList();
      if (tokens.isEmpty) return null;
      
      double? result = double.tryParse(tokens[0]);
      if (result == null) return null;
      
      for (int i = 1; i < tokens.length - 1; i += 2) {
        final op = tokens[i];
        final operand = double.tryParse(tokens[i + 1]);
        if (operand == null) return null;
        
        switch (op) {
          case '+':
            result += operand;
            break;
          case '-':
            result -= operand;
            break;
          case '*':
            result *= operand;
            break;
          case '/':
            if (operand != 0) result /= operand;
            break;
        }
      }
      return result;
    } catch (e) {
      return null;
    }
  }

  void _calculateExpression() {
    if (_expression.isEmpty) return;
    
    final fullExpression = '$_expression${_internalController.text}';
    final result = _evaluateExpression(fullExpression);
    
    if (result != null && result > 0) {
      final formatted = result.toStringAsFixed(2);
      // Remove trailing zeros
      final trimmed = formatted.replaceAll(RegExp(r'\.?0+$'), '');
      
      setState(() {
        _internalController.text = trimmed;
        widget.controller.text = trimmed;
        _expression = '';
        _showExpression = false;
      });
    }
  }

  void _onClear() {
    setState(() {
      _internalController.clear();
      widget.controller.clear();
      _expression = '';
      _showExpression = false;
    });
  }

  void _toggleNumpad() {
    setState(() {
      _showNumpad = !_showNumpad;
    });
  }

  void _setQuickAmount(double amount) {
    final text = amount.toStringAsFixed(0);
    setState(() {
      _internalController.text = text;
      widget.controller.text = text;
    });
    widget.onChanged?.call(text);
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
                labelText: _showExpression ? '$_expression?' : '金额',
                prefixText: '¥ ',
                prefixIcon: const Icon(Icons.attach_money),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.enableVoiceInput)
                      VoiceInputButton(
                        controller: _internalController,
                        mode: VoiceInputMode.amount,
                        hint: '说出金额',
                        onResult: (text) {
                          // Validate the amount
                          final amount = double.tryParse(text);
                          if (amount != null && amount > 0) {
                            setState(() {
                              widget.controller.text = text;
                            });
                          }
                        },
                      ),
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
                widget.onChanged?.call(value);
              },
            ),
          ),
        ),

        // Quick amount buttons
        if (widget.enableQuickAmounts && !_showNumpad) ...[
          const SizedBox(height: 8),
          _buildQuickAmountButtons(),
        ],

        // Calculator numpad
        if (_showNumpad) ...[
          const SizedBox(height: 16),
          _buildNumpad(),
        ],
      ],
    );
  }

  Widget _buildQuickAmountButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.quickAmounts.map((amount) {
        return ActionChip(
          label: Text('¥${amount.toStringAsFixed(0)}'),
          onPressed: () => _setQuickAmount(amount),
        );
      }).toList(),
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
          // Expression display
          if (_showExpression)
            Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                '$_expression${_internalController.text}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          _buildNumpadRow(['7', '8', '9', '/']),
          const SizedBox(height: 8),
          _buildNumpadRow(['4', '5', '6', '*']),
          const SizedBox(height: 8),
          _buildNumpadRow(['1', '2', '3', '-']),
          const SizedBox(height: 8),
          _buildNumpadRow(['.', '0', '00', '+']),
          const SizedBox(height: 8),
          _buildNumpadRow(['backspace', 'clear', 'calculate', 'done']),
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
    Color? backgroundColor;
    Color? textColor;

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
      case 'calculate':
        label = '=';
        onTap = _calculateExpression;
        backgroundColor = Theme.of(context).colorScheme.primaryContainer;
        textColor = Theme.of(context).colorScheme.onPrimaryContainer;
        break;
      case 'done':
        label = '完成';
        onTap = () {
          if (_showExpression) {
            _calculateExpression();
          }
          setState(() => _showNumpad = false);
        };
        backgroundColor = Theme.of(context).colorScheme.primary;
        textColor = Theme.of(context).colorScheme.onPrimary;
        break;
      case '+':
      case '-':
      case '*':
      case '/':
        label = key;
        onTap = () => _onKeyPressed(key);
        backgroundColor = Theme.of(context).colorScheme.secondaryContainer;
        textColor = Theme.of(context).colorScheme.onSecondaryContainer;
        break;
      default:
        label = key;
        onTap = () => _onKeyPressed(key);
    }

    return Material(
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, size: 24, color: textColor)
              : Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A text field with built-in validation and error display.
class ValidatedTextField extends StatefulWidget {
  /// Controller for the text field.
  final TextEditingController? controller;

  /// Label text for the field.
  final String? labelText;

  /// Hint text for the field.
  final String? hintText;

  /// Icon to show at the start of the field.
  final IconData? prefixIcon;

  /// Icon to show at the end of the field.
  final IconData? suffixIcon;

  /// Callback when suffix icon is pressed.
  final VoidCallback? onSuffixIconPressed;

  /// Validator function that returns an error message or null.
  final String? Function(String? value)? validator;

  /// List of validators to apply in order.
  final List<String? Function(String? value)>? validators;

  /// Whether to validate on every change.
  final bool validateOnChange;

  /// Whether to validate when the field loses focus.
  final bool validateOnUnfocus;

  /// Input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// Keyboard type.
  final TextInputType? keyboardType;

  /// Whether the field is obscured (for passwords).
  final bool obscureText;

  /// Whether the field is enabled.
  final bool enabled;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Maximum lines for the field.
  final int? maxLines;

  /// Minimum lines for the field.
  final int? minLines;

  /// Maximum length of text.
  final int? maxLength;

  /// Callback when text changes.
  final ValueChanged<String>? onChanged;

  /// Callback when submit is pressed.
  final VoidCallback? onSubmitted;

  /// Callback when the field is tapped.
  final VoidCallback? onTap;

  /// Focus node for the field.
  final FocusNode? focusNode;

  /// Text capitalization.
  final TextCapitalization textCapitalization;

  /// Text input action.
  final TextInputAction? textInputAction;

  /// Initial value for the field.
  final String? initialValue;

  /// Autovalidate mode.
  final AutovalidateMode autovalidateMode;

  /// Custom error text to display (overrides validation).
  final String? errorText;

  /// Helper text to display below the field.
  final String? helperText;

  /// Whether to show the error icon.
  final bool showErrorIcon;

  /// Custom error icon.
  final IconData? errorIcon;

  /// Custom error text style.
  final TextStyle? errorStyle;

  /// Custom border decoration.
  final InputBorder? border;

  /// Custom enabled border decoration.
  final InputBorder? enabledBorder;

  /// Custom focused border decoration.
  final InputBorder? focusedBorder;

  /// Custom error border decoration.
  final InputBorder? errorBorder;

  /// Custom focused error border decoration.
  final InputBorder? focusedErrorBorder;

  /// Content padding.
  final EdgeInsetsGeometry? contentPadding;

  /// Fill color.
  final Color? fillColor;

  /// Whether the field is filled.
  final bool? filled;

  const ValidatedTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.validator,
    this.validators,
    this.validateOnChange = false,
    this.validateOnUnfocus = true,
    this.inputFormatters,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.initialValue,
    this.autovalidateMode = AutovalidateMode.onUnfocus,
    this.errorText,
    this.helperText,
    this.showErrorIcon = true,
    this.errorIcon,
    this.errorStyle,
    this.border,
    this.enabledBorder,
    this.focusedBorder,
    this.errorBorder,
    this.focusedErrorBorder,
    this.contentPadding,
    this.fillColor,
    this.filled,
  });

  @override
  State<ValidatedTextField> createState() => _ValidatedTextFieldState();
}

class _ValidatedTextFieldState extends State<ValidatedTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  String? _errorText;
  bool _hasBeenFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(ValidatedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _hasBeenFocused && widget.validateOnUnfocus) {
      _validate();
    }
    if (_focusNode.hasFocus) {
      _hasBeenFocused = true;
    }
  }

  String? _runValidators(String? value) {
    // Use custom error text if provided
    if (widget.errorText != null) {
      return widget.errorText;
    }

    // Run single validator
    if (widget.validator != null) {
      final result = widget.validator!(value);
      if (result != null) return result;
    }

    // Run list of validators
    if (widget.validators != null) {
      for (final validator in widget.validators!) {
        final result = validator(value);
        if (result != null) return result;
      }
    }

    return null;
  }

  void _validate() {
    final error = _runValidators(_controller.text);
    if (mounted) {
      setState(() {
        _errorText = error;
      });
    }
  }

  void _onChanged(String value) {
    if (widget.validateOnChange) {
      _validate();
    } else if (_errorText != null) {
      // Clear error when user starts typing
      setState(() {
        _errorText = null;
      });
    }
    widget.onChanged?.call(value);
  }

  /// Public method to trigger validation.
  bool validate() {
    _validate();
    return _errorText == null;
  }

  /// Public method to clear the error.
  void clearError() {
    setState(() {
      _errorText = null;
    });
  }

  /// Public method to set a custom error.
  void setError(String? error) {
    setState(() {
      _errorText = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasError = _errorText != null || widget.errorText != null;
    final displayError = widget.errorText ?? _errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          onChanged: _onChanged,
          onFieldSubmitted: (_) => widget.onSubmitted?.call(),
          onTap: widget.onTap,
          autovalidateMode: widget.autovalidateMode,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            errorText: displayError,
            helperText: displayError == null ? widget.helperText : null,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon)
                : null,
            suffixIcon: _buildSuffixIcon(hasError),
            border: widget.border,
            enabledBorder: widget.enabledBorder,
            focusedBorder: widget.focusedBorder,
            errorBorder: widget.errorBorder,
            focusedErrorBorder: widget.focusedErrorBorder,
            contentPadding: widget.contentPadding,
            fillColor: widget.fillColor,
            filled: widget.filled,
            errorStyle: widget.errorStyle,
          ),
        ),
      ],
    );
  }

  Widget? _buildSuffixIcon(bool hasError) {
    // Priority: custom suffix icon > error icon > nothing
    if (widget.suffixIcon != null) {
      return IconButton(
        icon: Icon(widget.suffixIcon),
        onPressed: widget.onSuffixIconPressed,
      );
    }

    if (hasError && widget.showErrorIcon) {
      return Icon(
        widget.errorIcon ?? Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
      );
    }

    return null;
  }
}

/// A validated text field specifically for amounts.
class AmountTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? Function(String? value)? validator;
  final bool allowNegative;
  final bool allowZero;
  final double? minValue;
  final double? maxValue;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final FocusNode? focusNode;
  final bool enabled;
  final String? initialValue;
  final String? currencySymbol;

  const AmountTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText = '0.00',
    this.validator,
    this.allowNegative = false,
    this.allowZero = true,
    this.minValue,
    this.maxValue,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.enabled = true,
    this.initialValue,
    this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return ValidatedTextField(
      controller: controller,
      labelText: labelText ?? 'Amount',
      hintText: hintText,
      prefixIcon: currencySymbol != null
          ? null
          : Icons.attach_money,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: allowNegative,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(allowNegative ? r'^-?\d*\.?\d*' : r'^\d*\.?\d*'),
        ),
      ],
      validator: validator,
      enabled: enabled,
      focusNode: focusNode,
      initialValue: initialValue,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

/// A validated text field specifically for dates.
class DateTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? Function(String? value)? validator;
  final bool allowPast;
  final bool allowFuture;
  final DateTime? minDate;
  final DateTime? maxDate;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool enabled;
  final String? initialValue;
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool showDatePickerButton;

  const DateTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText = 'YYYY-MM-DD',
    this.validator,
    this.allowPast = true,
    this.allowFuture = true,
    this.minDate,
    this.maxDate,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.enabled = true,
    this.initialValue,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.showDatePickerButton = true,
  });

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate ?? (allowPast ? DateTime(1900) : now),
      lastDate: lastDate ?? (allowFuture ? DateTime(2100) : now),
    );

    if (picked != null) {
      final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      controller?.text = formatted;
      onChanged?.call(formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValidatedTextField(
      controller: controller,
      labelText: labelText ?? 'Date',
      hintText: hintText,
      prefixIcon: Icons.calendar_today,
      suffixIcon: showDatePickerButton ? Icons.edit_calendar : null,
      onSuffixIconPressed: showDatePickerButton && enabled
          ? () => _selectDate(context)
          : null,
      keyboardType: TextInputType.datetime,
      validator: validator,
      enabled: enabled,
      focusNode: focusNode,
      initialValue: initialValue,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: showDatePickerButton && enabled
          ? () => _selectDate(context)
          : onTap,
      readOnly: showDatePickerButton,
    );
  }
}

/// A validated text field specifically for descriptions.
class DescriptionTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? Function(String? value)? validator;
  final int minLength;
  final int maxLength;
  final bool required;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final FocusNode? focusNode;
  final bool enabled;
  final String? initialValue;
  final int? maxLines;
  final int? minLines;

  const DescriptionTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText = 'Enter description...',
    this.validator,
    this.minLength = 0,
    this.maxLength = 500,
    this.required = false,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.enabled = true,
    this.initialValue,
    this.maxLines = 3,
    this.minLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return ValidatedTextField(
      controller: controller,
      labelText: labelText ?? 'Description',
      hintText: hintText,
      prefixIcon: Icons.description,
      validator: validator,
      enabled: enabled,
      focusNode: focusNode,
      initialValue: initialValue,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      textCapitalization: TextCapitalization.sentences,
    );
  }
}

/// A validated text field specifically for passwords.
class PasswordTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? Function(String? value)? validator;
  final int minLength;
  final bool requireUppercase;
  final bool requireLowercase;
  final bool requireDigit;
  final bool requireSpecialChar;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final FocusNode? focusNode;
  final bool enabled;
  final String? initialValue;

  const PasswordTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText = 'Enter password...',
    this.validator,
    this.minLength = 8,
    this.requireUppercase = true,
    this.requireLowercase = true,
    this.requireDigit = true,
    this.requireSpecialChar = false,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.enabled = true,
    this.initialValue,
  });

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return ValidatedTextField(
      controller: widget.controller,
      labelText: widget.labelText ?? 'Password',
      hintText: widget.hintText,
      prefixIcon: Icons.lock,
      suffixIcon: _obscureText ? Icons.visibility : Icons.visibility_off,
      onSuffixIconPressed: () {
        setState(() {
          _obscureText = !_obscureText;
        });
      },
      obscureText: _obscureText,
      validator: widget.validator,
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      initialValue: widget.initialValue,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      keyboardType: TextInputType.visiblePassword,
    );
  }
}

/// A form that handles validation for all its child ValidatedTextField widgets.
class ValidatedForm extends StatefulWidget {
  final Widget child;
  final GlobalKey<FormState>? formKey;
  final VoidCallback? onSubmitted;

  const ValidatedForm({
    super.key,
    required this.child,
    this.formKey,
    this.onSubmitted,
  });

  @override
  State<ValidatedForm> createState() => ValidatedFormState();
}

class ValidatedFormState extends State<ValidatedForm> {
  final List<GlobalKey<_ValidatedTextFieldState>> _fieldKeys = [];

  void registerField(GlobalKey<_ValidatedTextFieldState> key) {
    if (!_fieldKeys.contains(key)) {
      _fieldKeys.add(key);
    }
  }

  void unregisterField(GlobalKey<_ValidatedTextFieldState> key) {
    _fieldKeys.remove(key);
  }

  /// Validates all fields in the form.
  /// Returns true if all fields are valid.
  bool validate() {
    bool allValid = true;
    for (final key in _fieldKeys) {
      if (key.currentState != null) {
        final isValid = key.currentState!.validate();
        if (!isValid) {
          allValid = false;
        }
      }
    }
    return allValid;
  }

  /// Clears all errors in the form.
  void clearErrors() {
    for (final key in _fieldKeys) {
      key.currentState?.clearError();
    }
  }

  /// Saves the form by calling onSubmitted if all fields are valid.
  void save() {
    if (validate()) {
      widget.onSubmitted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: widget.child,
    );
  }
}

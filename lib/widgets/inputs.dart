import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

InputDecoration _decoration({
  String? hint,
  Widget? suffix,
  Widget? prefix,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  double radius = 12,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.hint,
    filled: true,
    fillColor: AppColors.surface,
    isDense: true,
    contentPadding: padding,
    suffixIcon: suffix,
    prefixIcon: prefix,
    counterText: '',
    errorMaxLines: 2,
    errorStyle: const TextStyle(
        fontFamily: AppTextStyles.sans, fontSize: 12, color: AppColors.error),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.primary, 1.3),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error, 1.3),
    border: border(AppColors.border),
  );
}

/// Поле ввода с подписью над ним («ЭЛЕКТРОННАЯ ПОЧТА» + поле),
/// поддерживает скрытие пароля по иконке «глаз».
class LabeledTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? maxLength;
  final double? height;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onSubmitted;
  final TextCapitalization textCapitalization;

  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.maxLength,
    this.height,
    this.inputFormatters,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<LabeledTextField> createState() => _LabeledTextFieldState();
}

class _LabeledTextFieldState extends State<LabeledTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label.toUpperCase(), style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          obscureText: widget.isPassword && _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          minLines: widget.maxLines > 1 ? widget.maxLines : null,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          onFieldSubmitted: widget.onSubmitted,
          textCapitalization: widget.textCapitalization,
          style: AppTextStyles.body,
          decoration: _decoration(
            hint: widget.hint,
            suffix: widget.isPassword
                ? IconButton(
                    tooltip: _obscured ? 'Показать пароль' : 'Скрыть пароль',
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                      size: 21,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Белое поле поиска с иконкой лупы (Discover, Friends, Search Users).
class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        style: AppTextStyles.body,
        maxLength: 60,
        decoration: _decoration(
          hint: hint,
          radius: 12,
          padding: const EdgeInsets.symmetric(vertical: 10),
          prefix: const Icon(Icons.search, color: AppColors.textSecondary, size: 22),
          suffix: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Очистить',
                    icon: const Icon(Icons.close,
                        size: 18, color: AppColors.textSecondary),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// Простое поле без подписи (диалоги, поле названия комнаты).
class PlainTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const PlainTextField({
    super.key,
    required this.controller,
    this.hint,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      minLines: maxLines > 1 ? maxLines : null,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: AppTextStyles.body,
      decoration: _decoration(hint: hint),
    );
  }
}

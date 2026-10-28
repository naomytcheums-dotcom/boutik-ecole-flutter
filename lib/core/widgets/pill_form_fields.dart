import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// Champ texte « pilule » blanc sans bordure (formulaires des sections H et J), libellé au-dessus.
class PillTextField extends StatelessWidget {
  const PillTextField({
    super.key,
    required this.label,
    this.hint,
    this.icon,
    this.initialValue,
    this.controller,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.minHeight = 46,
    this.suffix,
  });

  final String label;
  final String? hint;
  final String? icon;
  final String? initialValue;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  final double minHeight;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final multi = maxLines > 1;
    final radius = BorderRadius.circular(multi ? 24 : minHeight / 2);
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: c == Colors.transparent ? BorderSide.none : BorderSide(color: c, width: w),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          validator: validator,
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLines: maxLines,
          minLines: multi ? maxLines : 1,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: AppText.body.copyWith(color: AppColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.secondary.copyWith(fontSize: 13.5, color: const Color(0xFF7A7782)),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            constraints: BoxConstraints(minHeight: minHeight),
            contentPadding: multi
                ? EdgeInsets.fromLTRB(16, 16, 16, minHeight - 16 - 18.0 * maxLines)
                : EdgeInsets.fromLTRB(icon == null ? 18 : 0, (minHeight - 18) / 2, 16, (minHeight - 18) / 2),
            prefixIcon: icon == null
                ? null
                : Padding(padding: const EdgeInsets.only(left: 16, right: 8), child: AppIcon(icon!, size: 20)),
            prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 44),
            suffixIcon: suffix,
            border: border(Colors.transparent),
            enabledBorder: border(Colors.transparent),
            focusedBorder: border(AppColors.accent, 1.5),
            errorBorder: border(AppColors.error, 1.5),
            focusedErrorBorder: border(AppColors.error, 1.5),
            errorStyle: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
            errorMaxLines: 3,
          ),
        ),
      ],
    );
  }
}

/// Liste déroulante « pilule » blanche ouvrant une feuille de choix.
class PillSelectField extends StatelessWidget {
  const PillSelectField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.icon,
    this.hint = 'Sélectionnez',
    this.height = 46,
  });

  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String> onChanged;
  final String? icon;
  final String hint;
  final double height;

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(label, style: AppText.h3),
            ),
            for (final o in options)
              ListTile(
                title: Text(o, style: AppText.body),
                trailing: o == value ? const AppIcon('assets/icons/check.svg', size: 18) : null,
                onTap: () => Navigator.pop(c, o),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Semantics(
          button: true,
          label: '$label : ${value ?? hint}',
          excludeSemantics: true,
          child: Material(
            color: Colors.white,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => _pick(context),
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (icon != null) ...[AppIcon(icon!, size: 20), const SizedBox(width: 12)],
                      Expanded(
                        child: Text(
                          value ?? hint,
                          style: value == null ? AppText.secondary : AppText.body.copyWith(color: AppColors.ink),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const AppIcon('assets/icons/chevron-down.svg', size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

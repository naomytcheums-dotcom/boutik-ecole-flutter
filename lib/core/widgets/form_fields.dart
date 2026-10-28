import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// Champ de formulaire avec libellé au-dessus et message d'erreur dessous (écran 275).
class TextFieldWithError extends StatelessWidget {
  const TextFieldWithError({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.errorText,
    this.helperText,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.obscure = false,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final String? errorText;
  final String? helperText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscure;
  final String? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          validator: validator,
          onChanged: onChanged,
          keyboardType: keyboardType,
          obscureText: obscure,
          maxLines: obscure ? 1 : maxLines,
          readOnly: readOnly,
          onTap: onTap,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: AppText.body,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            helperText: helperText,
            helperStyle: AppText.small,
            errorStyle: AppText.small.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
            errorMaxLines: 3,
            prefixIcon: prefixIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: AppIcon(prefixIcon!, size: 20, color: AppColors.textSecondary),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Barre de recherche arrondie (écran 03).
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.hint = 'Rechercher un produit, service, talent…',
    this.onTap,
    this.onChanged,
    this.showFilter = true,
    this.onFilter,
    this.controller,
    this.autofocus = false,
  });

  final String hint;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final bool showFilter;
  final VoidCallback? onFilter;
  final TextEditingController? controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        shape: const StadiumBorder(side: BorderSide(color: AppColors.cardBorder)),
      ),
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: Row(
        children: [
          const AppIcon('assets/icons/search.svg', size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              readOnly: onTap != null,
              onTap: onTap,
              onChanged: onChanged,
              style: AppText.body,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.body.copyWith(color: AppColors.textSecondary),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (showFilter)
            RoundIconButton(
              icon: 'assets/icons/sliders-horizontal.svg',
              label: 'Filtres',
              bordered: false,
              background: Colors.transparent,
              onTap: onFilter,
            ),
        ],
      ),
    );
  }
}

/// Interrupteur Boutik-École (encre quand actif).
class Toggle extends StatelessWidget {
  const Toggle({super.key, required this.value, required this.onChanged, this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 56,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 50,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: ShapeDecoration(
                color: value ? AppColors.ink : const Color(0xFFD9D6D0),
                shape: const StadiumBorder(),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne « libellé + interrupteur » des paramètres.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyStrong),
                if (subtitle != null) Text(subtitle!, style: AppText.small),
              ],
            ),
          ),
          Toggle(value: value, onChanged: onChanged, label: title),
        ],
      ),
    );
  }
}

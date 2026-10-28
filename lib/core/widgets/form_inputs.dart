import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'form_fields.dart';

/// Champ mot de passe avec bouton « afficher / masquer ».
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.errorText,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final String? errorText;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextFieldWithError(
      label: widget.label,
      hint: widget.hint,
      controller: widget.controller,
      validator: widget.validator,
      onChanged: widget.onChanged,
      errorText: widget.errorText,
      obscure: !_visible,
      prefixIcon: 'assets/icons/lock.svg',
      suffix: RoundIconButton(
        icon: _visible ? 'assets/icons/eye-off.svg' : 'assets/icons/eye.svg',
        label: _visible ? 'Masquer le mot de passe' : 'Afficher le mot de passe',
        bordered: false,
        background: Colors.transparent,
        onTap: () => setState(() => _visible = !_visible),
      ),
    );
  }
}

/// Champ de sélection (ouvre une liste en feuille modale).
class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint = 'Sélectionnez',
    this.icon,
    this.errorText,
  });

  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String> onChanged;
  final String hint;
  final String? icon;
  final String? errorText;

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(label, style: AppText.h3)),
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
        Text(label, style: AppText.label),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: '$label : ${value ?? hint}',
          excludeSemantics: true,
          child: Material(
            color: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusField),
              side: BorderSide(color: errorText != null ? AppColors.error : AppColors.cardBorder, width: errorText != null ? 1.5 : 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSizes.radiusField),
              onTap: () => _pick(context),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (icon != null) ...[AppIcon(icon!, size: 20, color: AppColors.textSecondary), const SizedBox(width: 12)],
                    Expanded(
                      child: Text(
                        value ?? hint,
                        style: value == null ? AppText.secondary : AppText.body,
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
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(errorText!, style: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

/// Choix segmenté arrondi (« Téléphone | E-mail »).
class SegmentedChoice extends StatelessWidget {
  const SegmentedChoice({super.key, required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(color: const Color(0xFFECEAF0), shape: const StadiumBorder()),
      child: Row(
        children: [
          for (final (i, l) in labels.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: GestureDetector(
                  onTap: () => onSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: ShapeDecoration(color: i == selected ? AppColors.ink : Colors.transparent, shape: const StadiumBorder()),
                    alignment: Alignment.center,
                    child: Text(l, style: AppText.label.copyWith(color: i == selected ? Colors.white : AppColors.ink, fontSize: 14)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Saisie de code à N chiffres (cases séparées, champ réel invisible).
class OtpInput extends StatefulWidget {
  const OtpInput({super.key, required this.controller, this.length = 6, this.hasError = false, this.onChanged});

  final TextEditingController controller;
  final int length;
  final bool hasError;
  final ValueChanged<String>? onChanged;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Code de vérification à ${widget.length} chiffres',
      textField: true,
      child: GestureDetector(
        onTap: _focus.requestFocus,
        child: Stack(
          children: [
            Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                maxLength: widget.length,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: widget.onChanged,
              ),
            ),
            ValueListenableBuilder(
              valueListenable: widget.controller,
              builder: (context, v, _) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < widget.length; i++)
                    Container(
                      width: 46,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: widget.hasError
                              ? AppColors.error
                              : (i == v.text.length
                                    ? const Color(0xFFF2B33D)
                                    : (i < v.text.length ? AppColors.ink : AppColors.cardBorder)),
                          width: i <= v.text.length ? 1.6 : 1,
                        ),
                      ),
                      child: Text(i < v.text.length ? v.text[i] : '', style: AppText.h1.copyWith(fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne de critère validé / non validé (force du mot de passe…).
class CriterionRow extends StatelessWidget {
  const CriterionRow(this.label, this.ok, {super.key});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label : ${ok ? 'respecté' : 'non respecté'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ok ? AppColors.success : Colors.transparent,
                border: ok ? null : Border.all(color: const Color(0xFFCFCBD6)),
              ),
              alignment: Alignment.center,
              child: ok ? const AppIcon('assets/icons/check.svg', size: 12, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Text(label, style: (ok ? AppText.body : AppText.secondary).copyWith(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

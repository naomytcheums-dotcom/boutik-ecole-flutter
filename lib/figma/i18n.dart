import 'dart:convert';

import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// Langue de l'application : français (par défaut) ou anglais. Les textes anglais viennent du fichier embarqué `assets/i18n/en.json`
/// (traduction faite une fois, gardée dans l'application) : aucune connexion n'est nécessaire pour passer en anglais.
class I18n {
  static String lang = 'fr';
  static Map<String, String> _en = const {};
  static final List<(RegExp, String)> _tpl = [];
  static final Map<String, String> _cache = {};
  static final notifier = m.ValueNotifier<String>('fr');

  /// Vrai si le fichier de traduction anglaise est présent et rempli.
  static Future<bool> available() async {
    if (_en.isEmpty) {
      try {
        _load(await rootBundle.loadString('assets/i18n/en.json'));
      } catch (_) {}
    }
    return _en.length > 100;
  }

  /// Lit le fichier de traduction : les textes fixes, et les modèles (clés « § ») pour les textes composés avec des valeurs.
  static void _load(String raw) {
    final all = Map<String, String>.from(jsonDecode(raw) as Map);
    _tpl.clear();
    _cache.clear();
    final fixed = <String, String>{};
    all.forEach((k, v) {
      if (!k.startsWith('§')) {
        fixed[k] = v;
        return;
      }
      final src = k.substring(1);
      final esc = RegExp.escape(src).replaceAllMapped(RegExp(r'\\\{(\d)\\\}'), (m) => '(?<g${m.group(1)}>.+?)');
      try {
        _tpl.add((RegExp('^$esc\$', dotAll: true), v));
      } catch (_) {}
    });
    _en = fixed;
  }

  /// Texte composé (« Bonjour Marie ») : retrouve son modèle, traduit le modèle et remet les valeurs (elles-mêmes traduites si possible).
  static String? _fromTemplate(String s) {
    final hit = _cache[s];
    if (hit != null) return hit;
    for (final (re, en) in _tpl) {
      final m = re.firstMatch(s);
      if (m == null) continue;
      var out = en;
      for (var i = 0; i < 4; i++) {
        if (!out.contains('{$i}')) continue;
        String? g;
        try {
          g = m.namedGroup('g$i');
        } catch (_) {}
        out = out.replaceAll('{$i}', tr(g ?? ''));
      }
      if (_cache.length > 3000) _cache.clear();
      _cache[s] = out;
      return out;
    }
    return null;
  }

  /// Lit la langue enregistrée sur l'appareil (au démarrage).
  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getString('app_lang');
      if (saved == 'en') await setLang('en', save: false);
    } catch (_) {}
  }

  static Future<void> setLang(String code, {bool save = true}) async {
    if (code == 'en' && _en.isEmpty) {
      try {
        _load(await rootBundle.loadString('assets/i18n/en.json'));
      } catch (_) {}
    }
    lang = code;
    notifier.value = code;
    if (save) {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('app_lang', code);
      } catch (_) {}
    }
  }

  /// Texte dans la langue courante ; un texte sans traduction reste en français.
  static String tr(String s) {
    if (lang != 'en') return s;
    final hit = _en[s];
    if (hit != null) return hit;
    // texte avec espaces de bord ou retours : on traduit le cœur et on conserve la forme
    final t = s.trim();
    if (t != s && t.isNotEmpty) {
      final h2 = _en[t];
      if (h2 != null) return s.replaceFirst(t, h2);
    }
    return _fromTemplate(s) ?? s;
  }
}

/// Fait reconstruire les textes quand la langue change.
class I18nScope extends m.InheritedWidget {
  const I18nScope({super.key, required this.lang, required super.child});
  final String lang;

  static String of(m.BuildContext context) => context.dependOnInheritedWidgetOfExactType<I18nScope>()?.lang ?? I18n.lang;

  @override
  bool updateShouldNotify(I18nScope old) => old.lang != lang;
}

/// `Text` de l'application : identique à celui de Flutter, mais le texte passe par la traduction.
class Text extends m.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final m.InlineSpan? textSpan;
  final m.TextStyle? style;
  final m.StrutStyle? strutStyle;
  final m.TextAlign? textAlign;
  final m.TextDirection? textDirection;
  final m.Locale? locale;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final m.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final m.TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;
  final m.Color? selectionColor;

  @override
  m.Widget build(m.BuildContext context) {
    I18nScope.of(context); // dépendance : le texte est recalculé au changement de langue
    if (data != null) {
      return m.Text(I18n.tr(data!), style: style, strutStyle: strutStyle, textAlign: textAlign, textDirection: textDirection, locale: locale, softWrap: softWrap, overflow: overflow, textScaler: textScaler, maxLines: maxLines, semanticsLabel: semanticsLabel == null ? null : I18n.tr(semanticsLabel!), textWidthBasis: textWidthBasis, textHeightBehavior: textHeightBehavior, selectionColor: selectionColor);
    }
    return m.Text.rich(_span(textSpan!), style: style, strutStyle: strutStyle, textAlign: textAlign, textDirection: textDirection, locale: locale, softWrap: softWrap, overflow: overflow, textScaler: textScaler, maxLines: maxLines, semanticsLabel: semanticsLabel, textWidthBasis: textWidthBasis, textHeightBehavior: textHeightBehavior, selectionColor: selectionColor);
  }

  static m.InlineSpan _span(m.InlineSpan s) {
    if (I18n.lang != 'en' || s is! m.TextSpan) return s;
    return m.TextSpan(text: s.text == null ? null : I18n.tr(s.text!), children: s.children?.map(_span).toList(), style: s.style, recognizer: s.recognizer, semanticsLabel: s.semanticsLabel, mouseCursor: s.mouseCursor, onEnter: s.onEnter, onExit: s.onExit, locale: s.locale, spellOut: s.spellOut);
  }
}

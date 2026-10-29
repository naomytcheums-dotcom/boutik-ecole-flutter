import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gen.dart';

/// Partage réel (feuille de partage du système, ou copie du lien si indisponible).
Future<void> shareText(BuildContext context, String text, {String? subject}) async {
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) gToast(context, 'Lien copié dans le presse-papiers');
  }
}

/// Ouvre un lien externe (réseaux sociaux, portfolio…).
Future<void> openUrl(BuildContext context, String url) async {
  try {
    if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  if (context.mounted) gToast(context, 'Impossible d’ouvrir ce lien');
}

const siteUrl = 'https://boutik-ecole.vercel.app';

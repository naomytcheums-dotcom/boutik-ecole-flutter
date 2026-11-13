import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gdata.dart' show gNetImage;
import '../gen.dart' show gP;
import '../i18n.dart' show Text;
import 'backend.dart';
import 'company_home.dart' show companyDashboardProvider;
import 'company_screens.dart' show companyProvider, companyStatusLabel;
import 'marche/marche_data.dart' show mst, kGrey, kViolet, kInk;

/// Contenu de l'écran 10 (page Profil du Figma) quand la personne connectée est une entreprise : même dessin que le profil de tout le
/// monde, seul le contenu change (nom, secteur, ville, présentation, chiffres, vérification). Aucun écran supplémentaire.
class CompanyProfileInfo {
  const CompanyProfileInfo({required this.name, required this.sector, required this.city, required this.description, required this.logo, required this.website, required this.status, required this.offers, required this.contests, required this.needs, required this.recruits});
  final String name, sector, city, description, logo, website, status;
  final int offers, contests, needs, recruits;
  bool get verified => status == 'approved';

  List<String> get tags => [for (final t in [sector, city]) if (t.trim().isNotEmpty) '#${t.trim().replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9]+'), '')}'];
}

CompanyProfileInfo companyProfileInfo(WidgetRef ref) {
  final c = ref.watch(companyProvider).asData?.value;
  final d = ref.watch(companyDashboardProvider).asData?.value;
  int n(String k) => (d?[k] as num?)?.toInt() ?? 0;
  return CompanyProfileInfo(
    name: '${c?['company_name'] ?? ''}'.trim(),
    sector: '${c?['sector'] ?? ''}'.trim(),
    city: '${c?['city'] ?? ''}'.trim(),
    description: '${c?['description'] ?? ''}'.trim(),
    logo: '${c?['logo_path'] ?? ''}',
    website: '${c?['website'] ?? ''}'.trim(),
    status: '${c?['status'] ?? 'draft'}',
    offers: n('offers_active'),
    contests: n('contests_active'),
    needs: n('needs_open'),
    recruits: n('recruits'),
  );
}

Widget companyAvatarLayer(CompanyProfileInfo i, double x, double y, double size) => gP(
      x,
      y,
      size,
      size,
      ClipOval(
        child: i.logo.isEmpty
            ? Container(color: const Color(0xFFEDE9F6), alignment: Alignment.center, child: Icon(Icons.business, size: size * .42, color: kViolet))
            : gNetImage(Backend.postMediaUrl(i.logo), fit: BoxFit.cover, width: size, height: size, errorBuilder: (_, _, _) => Container(color: const Color(0xFFEDE9F6), alignment: Alignment.center, child: Icon(Icons.business, size: size * .42, color: kViolet))),
      ),
    );

Widget companyNameLayer(CompanyProfileInfo i, double y) => gP(
      0,
      y,
      390,
      29,
      Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(i.name.isEmpty ? 'Votre entreprise' : i.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(22, w: FontWeight.w600, c: kInk))),
          if (i.verified) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, size: 18, color: Color(0xFF2F7DF6))),
        ]),
      ),
    );

Widget companyLineLayer(String text, double y, {double size = 11.5, Color? color, double h = 14}) => gP(0, y, 390, h, Center(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(size, c: color ?? kGrey))));

Widget companyBioLayer(CompanyProfileInfo i, double y) => gP(
      28.5,
      y,
      333,
      34,
      Text(i.description.isEmpty ? 'Ajoutez la présentation de votre entreprise : les étudiants la voient ici.' : i.description, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(11.5, c: const Color(0xFF6F6D77)).copyWith(height: 1.45)),
    );

Widget companyStatLayer(double x, String label, int count) => gP(x, 519, 104, 14, Center(child: Text('$count $label', style: mst(11.5, w: FontWeight.w500, c: kInk))));

String companyPassportLabel(CompanyProfileInfo i) => i.verified ? 'Entreprise vérifiée · ${i.recruits} recruté${i.recruits > 1 ? 's' : ''}' : companyStatusLabel(i.status);

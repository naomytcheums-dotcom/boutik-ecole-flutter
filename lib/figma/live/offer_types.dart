import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n.dart' show Text;
import 'auth.dart' show formProvider;

/// Les 4 types d'offres de la marketplace. Le type se déduit de la catégorie de l'annonce (voir la fonction SQL offer_type_of).
const offerTypeLabels = {
  'product': 'Produit physique',
  'tech': 'Solution technique ou numérique',
  'service': 'Service ou expertise',
  'project': 'Projet à vendre ou licence',
};

/// Libellé court affiché sur la photo d'une offre qui n'est pas un produit physique.
const offerTypeBadges = {'tech': 'Solution', 'service': 'Service', 'project': 'Projet'};

/// Catégories proposées à la publication : celles des produits physiques, puis une catégorie par autre type d'offre.
const publishCategories = [
  'Maison et déco',
  'Mode',
  'Tech',
  'Art',
  'Alimentation',
  'Solutions numériques',
  'Services',
  'Projets et licences',
];

String offerTypeOfCategory(String category) => switch (category.toLowerCase()) {
      'services' => 'service',
      'solutions numériques' => 'tech',
      'projets et licences' => 'project',
      _ => 'product',
    };

/// Sélecteur du formulaire « Nouveau produit » : type d'offre et catégorie en une seule liste déroulante.
class OfferCategoryPicker extends ConsumerWidget {
  const OfferCategoryPicker({super.key, this.padL = 48});
  final double padL;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(formProvider)['np_cat'] ?? publishCategories.first;
    final value = publishCategories.contains(current) ? current : publishCategories.first;
    const st = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFF111015));
    return Container(
      padding: EdgeInsets.only(left: padL, right: 40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE8F2), width: 1.5)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          icon: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(8),
          dropdownColor: Colors.white,
          style: st,
          items: [
            for (final c in publishCategories)
              DropdownMenuItem(value: c, child: Text(offerTypeOfCategory(c) == 'product' ? c : '$c · ${offerTypeLabels[offerTypeOfCategory(c)]}', maxLines: 1, overflow: TextOverflow.ellipsis, style: st)),
          ],
          onChanged: (v) {
            if (v != null) ref.read(formProvider.notifier).put('np_cat', v);
          },
        ),
      ),
    );
  }
}

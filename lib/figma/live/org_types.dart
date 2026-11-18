/// Types d'organisation (acteur « Organisation » : ancienne Entreprise élargie). Miroir du référentiel serveur (`org_types` / `org_type_docs`,
/// migration 20261120010000) : sert au choix du type à l'inscription (avant toute connexion) et de repli quand le serveur ne répond pas.
/// Le serveur reste l'autorité : `company_get`, `company_org_type` et `org_types_list` renvoient la même configuration.
class OrgDoc {
  const OrgDoc(this.kind, this.label, {this.hint = '', this.group});
  final String kind, label, hint;

  /// Groupe d'exigence : une pièce de ce groupe suffit à le satisfaire ; null = pièce facultative.
  final int? group;
  bool get required => group != null;
}

class OrgType {
  const OrgType({
    required this.code,
    required this.label,
    required this.description,
    required this.docs,
    this.commercial = false,
    this.sectorLabel = 'Secteur d’activité',
    this.registrationLabel = 'Numéro d’immatriculation',
    this.registrationRequired = false,
    this.taxRequired = false,
    this.missionRequired = false,
  });
  final String code, label, description, sectorLabel, registrationLabel;
  final bool commercial, registrationRequired, taxRequired, missionRequired;
  final List<OrgDoc> docs;

  /// Groupes de pièces obligatoires : numéro du groupe -> pièces alternatives.
  Map<int, List<OrgDoc>> get requirementGroups {
    final m = <int, List<OrgDoc>>{};
    for (final d in docs) {
      if (d.group != null) (m[d.group!] ??= []).add(d);
    }
    return m;
  }

  /// Libellé d'un groupe : « Récépissé de déclaration ou Statuts ».
  String groupLabel(int g) => (requirementGroups[g] ?? const []).map((d) => d.label).join(' ou ');

  /// Groupes encore non satisfaits par les pièces déposées ([kinds] = natures des pièces de la fiche).
  List<int> unmetGroups(Iterable<String> kinds) {
    final have = kinds.toSet();
    return [for (final e in requirementGroups.entries) if (!e.value.any((d) => have.contains(d.kind))) e.key]..sort();
  }

  bool allows(String kind) => kind == 'other' || docs.any((d) => d.kind == kind);

  static OrgType? fromJson(Object? j) {
    if (j is! Map) return null;
    final code = '${j['code'] ?? ''}';
    if (code.isEmpty) return null;
    final fallback = orgTypeByCode[code];
    final docs = <OrgDoc>[
      for (final d in (j['docs'] as List? ?? const []))
        if (d is Map) OrgDoc('${d['kind']}', '${d['label']}', hint: '${d['hint'] ?? ''}', group: d['group'] is int ? d['group'] as int : (d['group'] is num ? (d['group'] as num).toInt() : null)),
    ];
    return OrgType(
      code: code,
      label: '${j['label'] ?? fallback?.label ?? code}',
      description: '${j['description'] ?? fallback?.description ?? ''}',
      commercial: j['commercial'] == true,
      sectorLabel: '${j['sector_label'] ?? fallback?.sectorLabel ?? 'Secteur d’activité'}',
      registrationLabel: '${j['registration_label'] ?? fallback?.registrationLabel ?? 'Numéro d’immatriculation'}',
      registrationRequired: j['registration_required'] == true,
      taxRequired: j['tax_required'] == true,
      missionRequired: j['mission_required'] == true,
      docs: docs.isEmpty ? (fallback?.docs ?? const []) : docs,
    );
  }
}

const _autre = OrgDoc('other', 'Autre pièce');
const _mandat = OrgDoc('mandate', 'Mandat du représentant');
const _identite = OrgDoc('identity', 'Pièce d’identité du responsable');
const _attestation = OrgDoc('attestation', 'Attestation officielle');

const orgTypes = <OrgType>[
  OrgType(
    code: 'entreprise_commerciale',
    label: 'Entreprise commerciale',
    description: 'Société ou entreprise individuelle qui vend des biens ou des services.',
    commercial: true,
    registrationLabel: 'RCCM / numéro d’immatriculation',
    docs: [OrgDoc('registration', 'RCCM', hint: 'Registre du commerce et du crédit mobilier', group: 1), OrgDoc('tax', 'NIU', hint: 'Attestation du numéro d’identifiant unique', group: 1), _mandat, _attestation, _autre],
  ),
  OrgType(
    code: 'association',
    label: 'Association',
    description: 'Association déclarée (culturelle, sportive, étudiante, de développement…).',
    sectorLabel: 'Domaine d’action',
    registrationLabel: 'Numéro du récépissé de déclaration',
    registrationRequired: true,
    missionRequired: true,
    docs: [OrgDoc('receipt', 'Récépissé de déclaration', hint: 'Récépissé ou arrêté de déclaration de l’association', group: 1), OrgDoc('statutes', 'Statuts', hint: 'Statuts signés de l’association', group: 2), _mandat, _identite, _attestation, _autre],
  ),
  OrgType(
    code: 'ong',
    label: 'ONG',
    description: 'Organisation non gouvernementale ou organisation internationale agréée.',
    sectorLabel: 'Domaine d’action',
    registrationLabel: 'Numéro d’agrément ou d’autorisation',
    registrationRequired: true,
    missionRequired: true,
    docs: [OrgDoc('authorization', 'Agrément ou autorisation d’exercer', hint: 'Agrément, autorisation ou accord-cadre', group: 1), OrgDoc('statutes', 'Statuts', hint: 'Statuts ou charte de l’organisation', group: 2), OrgDoc('receipt', 'Récépissé de déclaration'), _mandat, _identite, _attestation, _autre],
  ),
  OrgType(
    code: 'cooperative',
    label: 'Coopérative',
    description: 'Coopérative ou groupement d’initiative commune.',
    sectorLabel: 'Domaine d’activité',
    registrationLabel: 'Numéro d’immatriculation de la coopérative',
    registrationRequired: true,
    missionRequired: true,
    docs: [OrgDoc('registration', 'Immatriculation de la coopérative', hint: 'Certificat ou récépissé d’immatriculation', group: 1), OrgDoc('statutes', 'Statuts', hint: 'Statuts de la coopérative', group: 2), OrgDoc('receipt', 'Récépissé de déclaration'), _mandat, _identite, _attestation, _autre],
  ),
  OrgType(
    code: 'fondation',
    label: 'Fondation',
    description: 'Fondation ou structure de mécénat reconnue.',
    sectorLabel: 'Domaine d’action',
    registrationLabel: 'Numéro de l’acte de constitution ou d’autorisation',
    missionRequired: true,
    docs: [
      OrgDoc('statutes', 'Acte de constitution ou statuts', hint: 'Acte constitutif de la fondation', group: 1),
      OrgDoc('authorization', 'Autorisation ou reconnaissance', hint: 'Arrêté, décret ou décision d’autorisation', group: 2),
      OrgDoc('decree', 'Acte officiel de création', group: 2),
      OrgDoc('receipt', 'Récépissé de déclaration', group: 2),
      _mandat,
      _identite,
      _attestation,
      _autre,
    ],
  ),
  OrgType(
    code: 'institution',
    label: 'Institution',
    description: 'Administration, établissement public, université ou organisme officiel.',
    sectorLabel: 'Domaine de compétence',
    registrationLabel: 'Référence de l’acte de création',
    docs: [OrgDoc('decree', 'Acte de création', hint: 'Décret, arrêté, loi ou texte instituant la structure', group: 1), OrgDoc('mandate', 'Mandat du représentant', hint: 'Décision ou lettre qui habilite la personne à agir', group: 2), _identite, _attestation, _autre],
  ),
  OrgType(
    code: 'structure_partenaire',
    label: 'Structure partenaire',
    description: 'Structure liée à l’IUT par un partenariat (incubateur, centre, réseau…).',
    sectorLabel: 'Domaine d’activité',
    registrationLabel: 'Numéro d’enregistrement (si applicable)',
    docs: [
      OrgDoc('convention', 'Convention ou lettre de partenariat', hint: 'Convention signée ou lettre d’engagement avec l’IUT', group: 1),
      OrgDoc('attestation', 'Attestation officielle', group: 1),
      OrgDoc('registration', 'Immatriculation', group: 2),
      OrgDoc('receipt', 'Récépissé de déclaration', group: 2),
      OrgDoc('statutes', 'Statuts', group: 2),
      OrgDoc('decree', 'Acte de création', group: 2),
      OrgDoc('authorization', 'Agrément ou autorisation', group: 2),
      OrgDoc('tax', 'NIU'),
      _mandat,
      _identite,
      _autre,
    ],
  ),
  OrgType(
    code: 'autre_reconnue',
    label: 'Autre organisation reconnue',
    description: 'Toute autre organisation reconnue qui ne rentre pas dans les types ci-dessus.',
    sectorLabel: 'Domaine d’activité',
    registrationLabel: 'Numéro d’enregistrement (si applicable)',
    docs: [
      OrgDoc('registration', 'Immatriculation', group: 1),
      OrgDoc('receipt', 'Récépissé de déclaration', group: 1),
      OrgDoc('statutes', 'Statuts', group: 1),
      OrgDoc('decree', 'Acte de création', group: 1),
      OrgDoc('authorization', 'Agrément ou autorisation', group: 1),
      OrgDoc('attestation', 'Attestation officielle', group: 1),
      OrgDoc('tax', 'NIU'),
      _mandat,
      _identite,
      _autre,
    ],
  ),
];

const kDefaultOrgType = 'entreprise_commerciale';

final Map<String, OrgType> orgTypeByCode = {for (final t in orgTypes) t.code: t};

/// Type d'organisation d'un code (la fiche historique sans type est une entreprise commerciale).
OrgType orgTypeOf(String? code) => orgTypeByCode[code] ?? orgTypeByCode[kDefaultOrgType]!;

/// Nature des pièces justificatives (tous types confondus) : libellés affichés dans les listes de pièces.
const orgDocKindLabels = {
  'registration': 'Immatriculation (RCCM)',
  'tax': 'Numéro fiscal (NIU)',
  'mandate': 'Mandat du représentant',
  'attestation': 'Attestation officielle',
  'other': 'Autre pièce',
  'statutes': 'Statuts',
  'receipt': 'Récépissé de déclaration',
  'authorization': 'Agrément ou autorisation',
  'decree': 'Acte de création',
  'identity': 'Pièce d’identité du responsable',
  'convention': 'Convention de partenariat',
};

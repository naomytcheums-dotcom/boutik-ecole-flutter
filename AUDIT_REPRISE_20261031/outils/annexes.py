import csv, os, sys
from collections import Counter
sys.stdout.reconfigure(encoding='utf-8')
D = r'C:\Users\NITROV15\Downloads\boutik_ecole_flutter\AUDIT_REPRISE_20261031\donnees'
rows = list(csv.DictReader(open(os.path.join(D, 'inventaire_ecrans.csv'), encoding='utf-8-sig')))
fix = {
 '150-2': ('3 · conditionnel (état système : session expirée, ouvert par lib/figma/live/system_states.dart:99)', 'system_states.dart'),
 '150-3': ('3 · conditionnel (état système : hors connexion, system_states.dart:28/75)', 'system_states.dart'),
 '182':   ('3 · conditionnel (état système : chargement hors connexion, system_states.dart:28 ; lien depuis 150-3)', 'system_states.dart, g_150_3'),
 '183':   ('3 · conditionnel (état système : commandes hors connexion, system_states.dart:75/89)', 'system_states.dart'),
 '150-1': ('4 · route sans point d\'entrée actif (seul lien : widget mort lib/features/q_parametres/s150_connexion_impossible)', ''),
 '275':   ('4 · route sans point d\'entrée actif (seuls liens : widgets morts s287/s288 de lib/features)', ''),
 '176':   ('5 · réellement orphelin (aucune référence ; accueil « client » de l\'onboarding, 177 « entreprise » est relié)', ''),
 '150-4': ('5 · réellement orphelin (aucune référence ; état « Mes commandes vide »)', ''),
 'S1':    ('5 · réellement orphelin (écran de démarrage animé ; seul lien sortant dans un widget mort)', ''),
 'A2':    ('6 · doublon potentiel de 231 « Accueil Kéla » (même classe AccueilKelaScreen, section « échantillons de référence »)', ''),
 'P4':    ('6 · doublon potentiel de 250b « Nouvelle publication » (même classe NouvellePublicationScreen)', ''),
 '250b':  ('6 · variante/doublon potentiel de 250 et P4 « Nouvelle publication »', ''),
}
for r in rows:
    if r['ecran'] in fix:
        r['categorie'], extra = fix[r['ecran']]
        if extra: r['exemples_entrants'] = (r['exemples_entrants'] + ' ' + extra).strip()
with open(os.path.join(D, 'inventaire_ecrans.csv'), 'w', encoding='utf-8-sig', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
c = Counter(r['categorie'][0] for r in rows); print(sorted(c.items()))
# annexe markdown 02
lines = ['| Écran | Titre | Module (lib/features) | Format | Route | Rôles autorisés (client) | Profondeur depuis 01 | Liens entrants | Exemples d\'écrans appelants | Catégorie |', '|---|---|---|---|---|---|---|---|---|---|']
for r in rows:
    lines.append('| {ecran} | {titre} | `{module}` | {format} | `{route}` | {roles} | {profondeur} | {liens_entrants} | {exemples_entrants} | {categorie} |'.format(**{k: (v or '—').replace('|', '/') for k, v in r.items()}))
open(os.path.join(D, 'annexe_02_ecrans.md'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
# annexe markdown 03
d = list(csv.DictReader(open(os.path.join(D, 'devenir_192_demonstrations.csv'), encoding='utf-8-sig')))
for r in d:
    if r['fonctions'] == 'advanceCurrentOrder': r['persistance'] = 'serveur (Supabase) via sellerStatusProvider.advance → Backend.setSellerOrderStatus (seller.dart:306)'
L = ['| # | Écran | Libellé historique « Démonstration : … » | Devenir actuel | Persistance | Fonction(s) | Message actuel |', '|---|---|---|---|---|---|---|']
for i, r in enumerate(d, 1):
    L.append(f"| {i} | {r['ecran']} | {r['libelle_historique'][:90].replace('|','/').replace(chr(10),' ')} | {r['statut_actuel']} | {r['persistance'] or '—'} | {r['fonctions'] or '—'} | {r['message_actuel'][:80] or '—'} |")
open(os.path.join(D, 'annexe_03_192_actions.md'), 'w', encoding='utf-8').write('\n'.join(L) + '\n')
with open(os.path.join(D, 'devenir_192_demonstrations.csv'), 'w', encoding='utf-8-sig', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(d[0].keys())); w.writeheader(); w.writerows(d)
print(Counter((r['statut_actuel'][:12], r['persistance'][:7]) for r in d))

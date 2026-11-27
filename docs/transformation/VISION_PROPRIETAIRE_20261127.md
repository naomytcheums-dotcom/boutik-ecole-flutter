# Vision et demandes du propriétaire (27 novembre 2026)

Document à lire par toute personne ou assistant qui travaille sur le projet. Il note ce que le propriétaire a transmis dans la conversation. Rien ici n'est construit ou vérifié du seul fait d'y figurer.

## Positionnement

L'ancien slogan (IUT de Douala) est abandonné. Présentation retenue : « Une plateforme intégrée de valorisation des talents, de commercialisation des productions, de collaboration professionnelle et de développement de l'innovation. »

- Un étudiant part d'une simple compétence et peut devenir un professionnel reconnu, évalué, recruté et financé : carrière internationale, entreprise, ventes, équipe, financements, sans quitter l'écosystème.
- Une entreprise internationale peut y recruter, évaluer des candidats avec l'IA (service externe par API), mener des entretiens vidéo, trouver des talents, confier des missions, acheter des productions, financer des innovations, organiser des événements et formations en direct, développer une communauté et suivre les résultats de ses collaborations.

## Acteurs

- Visiteur et Client : un seul acteur « Client », état non connecté (regarde) ou connecté (achète). Le rôle serveur `visitor` peut rester en interne ; l'interface (navigation, inscription, messages) ne doit jamais présenter deux acteurs.
- L'administrateur (le propriétaire) gère tout : pas d'accès Finance ou Support séparés pour l'instant ; plus tard, des membres d'équipe avec des droits.
- Établissements : aucune liste préremplie. Plus tard, un portail web par établissement (la direction voit toute son école, chaque département le sien).

## Innovations validées par le propriétaire

1. **Agent IA vendeur (payant)** : répond, négocie entre prix plancher et prix cible, relance les paniers, met à jour les stocks, prépare la commande (l'étudiant valide). Publicité contextuelle déclenchée par le comportement (offre courte, proposée au vendeur ou automatique si budget pub activé), plafonnée et marquée « Sponsorisé ». Avatar IA du vendeur (visage et voix) : consentement explicite, droit à l'image, mention « avatar IA ». Abonnement mensuel + budget pub séparé.
2. **Indice de réputation globale** : ventes livrées et notes, missions et jalons, concours et duels, mentions dans des projets, évaluations de pairs et de responsables. Certificat vérifiable, alimente le CV public.
3. **Marché inversé** : le talent publie son profil, les organisations enchérissent (mission, stage, alternance), l'étudiant choisit.
4. **Contrat de campus (payant)** : au-delà d'un montant, le responsable de département arbitre le litige ; une part des frais d'arbitrage revient à l'école (prélevée sur la part administrateur).
5. **Borne** : lit le passeport par QR (ventes du mois, indice, compétences vérifiées) ; au scan d'un produit, l'avatar du vendeur parle, négocie, et la commande se passe à la borne.

## Propositions transmises, NON validées (ne pas construire)

6. Duel de talents payant comme recrutement (brief réel, 48 h, badge « finaliste »). 7. Passeport Organisation (missions, paiements, délais, litiges). 8. Fonds de projets public et votable. 9. Agent veilleur de réputation (payant).

## Diplômes et attestations

Visibles des entreprises, pas de tout le monde ; il faut limiter la copie et la réutilisation frauduleuse. État au 27/11 : compartiment privé `profile-documents`, lu par le propriétaire du document, le personnel de la plateforme et le département vérificateur ; **les entreprises n'y ont pas accès**. Piste à valider : badge « vérifié » visible ; original consultable seulement sur accord de l'étudiant, par organisation, limité dans le temps, filigrané à son nom, journalisé (une capture d'écran reste impossible à empêcher).

## Exigences de qualité

Aucun faux chiffre dans les tableaux de bord ; aucun compte ne voit les données d'un autre ; aucune commande en double après répétition d'un paiement ; chaque paiement a une preuve vérifiable ; chaque fonctionnalité a un parcours complet ; interfaces cohérentes sur mobile, tablette et web ; intégrations testées avec les vrais fournisseurs ; performances mesurées sur appareils modestes et réseau instable ; données personnelles et financières protégées ; permissions strictes par acteur.

## Décisions financières

Prix, parts, frais d'arbitrage, abonnements : décision du propriétaire uniquement. Aucun montant n'est fixé ici.

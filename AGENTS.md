# Boutik-École (Flutter + Supabase + Vercel)

Avant toute chose, lis `docs/transformation/REPRISE_OPENCODE.md` : règles du propriétaire, procédures (tests, migrations de production, déploiement) et liste ordonnée de ce qui reste à faire.

Résumé des règles :
- Mobile d'abord. Ne jamais supprimer de contenu existant sans le dire.
- Aucune clé ni secret poussé ; ne jamais lire ni modifier les clés Notch Pay ; aucun paiement réel.
- Chaque correction terminée : tests, commit, push, build (`flutter build web --release --pwa-strategy=none`), déploiement Vercel, vérification de la version servie. Un push GitHub seul ne met pas le site à jour.

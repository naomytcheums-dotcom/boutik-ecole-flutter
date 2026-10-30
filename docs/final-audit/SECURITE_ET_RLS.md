# Sécurité, RLS et isolation des comptes

## Règles en vigueur (vérifiées sur la base réelle)
- Un utilisateur ne lit que son profil ; il ne peut ni créer un profil pour un autre identifiant, ni changer son `id`.
- Il ne peut pas modifier `role`, `suspended`, ni aucun champ de certification (déclencheur `protect_profile_authority`). Insertion avec `certification='approved'` : forcée à `none`.
- Certification : `request_certification()` (titulaire : none/rejected → pending) ; `decide_certification(user, statut)` réservée à `dept`/`admin`, jamais sur son propre compte, transitions contrôlées (pending → review → approved/rejected, approved → revoked), journalisée dans `audit_log`. Exécution refusée aux anonymes.
- `favorites` : politique `user_id = auth.uid()` (lecture, écriture, suppression) ; écrire au nom d'un autre : refusé (403).
- `orders`/`order_lines` : plus d'insertion directe ; `create_order` recalcule les montants côté serveur. `audit_log` : écriture uniquement via `log_audit`. `listings.status` : modifiable seulement par le département/admin.
- `payment_events` : RLS activée sans politique, droits retirés à `anon` et `authenticated` (seul le rôle service y accède).
- Comptes de démonstration : suspendus, bannis, mots de passe invalidés.

## Côté application
- Le profil affiché est celui de la session (`auth.uid()`), jamais un profil par défaut quand le serveur est joint ; avatar neutre, description vide, 0 produit.
- La déconnexion recrée toute l'arborescence d'état (`AppRoot`) : rien du compte précédent ne survit.
- Les droits par rôle (`allowedRoles`) restent appliqués aussi côté client (AccessGuard) ; les ressources sensibles sont protégées par RLS.

## Limites connues
- Aucune politique Storage : pas de téléversement de photo (non implémenté).
- Les annonces, commandes reçues, missions, équipes, messages et notifications ne sont pas encore en base : leurs droits serveur ne sont donc pas applicables.
- « Confirm email » est désactivé dans Supabase (à réactiver par le propriétaire) ; aucun code e-mail ou SMS réel.

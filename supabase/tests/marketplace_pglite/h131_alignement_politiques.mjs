// H13.1 · Migration 20261129900000 (alignement des politiques RLS de la production) : on reproduit l'ETAT DE PRODUCTION (politiques ASCII en doublon ou sous l'ancien nom)
// puis on rejoue la migration. Prouve : doublons supprimes, renommages sans perte de definition, politiques de borne fermees, rejeu sans effet, definitions du depot conservees.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h131_alignement_politiques.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
let ok = 0, ko = 0;
export async function run(db) {
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const sqlFile = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'migrations', '20261129900000_h131_alignement_politiques_production.sql');
  const mig = fs.readFileSync(sqlFile, 'utf8');
  const pol = async (t, n) => (await db.query(`select qual q, with_check w from pg_policies where schemaname = 'public' and tablename = '${t}' and policyname = '${n.replace(/'/g, "''")}'`)).rows[0];
  const has = async (t, n) => !!(await pol(t, n));
  await db.exec('reset role');

  // ---- etat de production : doublons ASCII a l'ancienne definition + politiques de borne + noms ASCII sans homologue
  await db.exec(`
    create policy "annonces approuvees visibles par tous" on listings for select using (status = 'approved' or seller_id = auth.uid() or current_role_name() in ('dept', 'admin'));
    create policy "profil cree a l inscription" on profiles for insert with check (id = auth.uid() and role = any (array['client', 'student', 'company', 'other']::app_role[]));
    create policy "sessions borne lisibles par les connectes" on kiosk_sessions for select using (auth.uid() is not null);
    create policy "sessions borne creees par les connectes" on kiosk_sessions for insert with check (auth.uid() is not null);
    alter policy "journal lisible par l'administration" on audit_log rename to "journal lisible par l administration";
    alter policy "équipes visibles par tous" on hackathon_teams rename to "equipes visibles par tous";
    alter policy "un étudiant crée son équipe" on hackathon_teams rename to "un etudiant cree son equipe";
    alter policy "un vendeur crée ses annonces" on listings rename to "un vendeur cree ses annonces";
    alter policy "commandes de l'acheteur ou de l'administration" on orders rename to "commandes de l acheteur ou de l administration";
    alter policy "profil visible par soi et l'administration" on profiles rename to "profil visible par soi et l administration";`);
  const defBefore = { audit: (await pol('audit_log', 'journal lisible par l administration')).q, orders: (await pol('orders', 'commandes de l acheteur ou de l administration')).q };
  check('A1 etat de production reproduit : doublon listings (ancienne definition sans _dept_sees) et inscription avec le role other', !/_dept_sees/.test((await pol('listings', 'annonces approuvees visibles par tous')).q) && /other/.test((await pol('profiles', 'profil cree a l inscription')).w));
  check('A2 politiques de borne presentes avant la migration', (await has('kiosk_sessions', 'sessions borne lisibles par les connectes')) && (await has('kiosk_sessions', 'sessions borne creees par les connectes')));

  // ---- migration
  await db.exec(mig);
  check('B1 politiques de borne supprimees', !(await has('kiosk_sessions', 'sessions borne lisibles par les connectes')) && !(await has('kiosk_sessions', 'sessions borne creees par les connectes')));
  check('B2 doublons ASCII listings/profiles supprimes', !(await has('listings', 'annonces approuvees visibles par tous')) && !(await has('profiles', 'profil cree a l inscription')));
  check('B3 la politique du depot (cloisonnement departement) reste la seule : _dept_sees present', /_dept_sees/.test((await pol('listings', 'annonces approuvées visibles par tous')).q));
  check('B4 inscription : le role « other » n\'est plus accepte', !/other/.test((await pol('profiles', 'profil créé à l\'inscription')).w));
  const renamed = [['audit_log', 'journal lisible par l\'administration'], ['hackathon_teams', 'équipes visibles par tous'], ['hackathon_teams', 'un étudiant crée son équipe'], ['listings', 'un vendeur crée ses annonces'],
    ['orders', 'commandes de l\'acheteur ou de l\'administration'], ['profiles', 'profil visible par soi et l\'administration']];
  for (const [t, n] of renamed) check(`B5 renommee au nom du depot : ${t} / ${n}`, await has(t, n));
  check('B6 aucun nom ASCII restant', (await db.query(`select count(*)::int n from pg_policies where schemaname = 'public' and policyname in ('journal lisible par l administration','equipes visibles par tous','un etudiant cree son equipe','un vendeur cree ses annonces','annonces approuvees visibles par tous','commandes de l acheteur ou de l administration','profil cree a l inscription','profil visible par soi et l administration','sessions borne lisibles par les connectes','sessions borne creees par les connectes')`)).rows[0].n === 0);
  check('B7 les definitions renommees sont inchangees', (await pol('audit_log', 'journal lisible par l\'administration')).q === defBefore.audit && (await pol('orders', 'commandes de l\'acheteur ou de l\'administration')).q === defBefore.orders);

  // ---- rejeu
  const total = (await db.query(`select count(*)::int n from pg_policies where schemaname in ('public','storage')`)).rows[0].n;
  await db.exec(mig);
  check('C1 rejeu sans effet (meme nombre de politiques)', (await db.query(`select count(*)::int n from pg_policies where schemaname in ('public','storage')`)).rows[0].n === total);

  // ---- effet : un compte Departement ne lit plus les annonces non approuvees d'un autre etablissement (lecture reelle, role authenticated)
  await db.exec(`insert into auth.users(id,email) values ('00000000-0000-0000-0000-000000009901','d1@t.cm'), ('00000000-0000-0000-0000-000000009902','s1@t.cm');
    insert into profiles(id,name,role,email) values ('00000000-0000-0000-0000-000000009901','Dept Un','dept','d1@t.cm'), ('00000000-0000-0000-0000-000000009902','Etu Un','student','s1@t.cm')`);
  await db.exec(`insert into listings (id, seller_id, title, department, price, status) values ('00000000-0000-0000-0000-00000000a901', '00000000-0000-0000-0000-000000009902', 'Annonce en attente', 'Departement Autre', 1000, 'pending')`);
  await db.exec(`reset role; select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000009901', false), set_config('request.jwt.claims', '{}', false); set role authenticated`);
  const seen = (await db.query(`select count(*)::int n from listings where id = '00000000-0000-0000-0000-00000000a901'`)).rows[0].n;
  check('D1 un compte Departement non rattache a l\'etablissement ne lit plus l\'annonce en attente d\'un autre etudiant', seen === 0, `vu=${seen}`);
  await db.exec('reset role');
  console.log(`h131_alignement_politiques : ${ok} OK, ${ko} ECHEC`);
}

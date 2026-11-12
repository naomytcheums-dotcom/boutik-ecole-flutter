// Edge Function « admin-test-accounts » : comptes de test de l'administrateur.
//   POST {action: "ensure"}                -> crée les comptes de test manquants (un par profil) ; renvoie ceux qui existent
//   POST {action: "login", target_id: ...} -> lien à usage unique pour ouvrir un compte de test : { token_hash, email, role }
// Sécurité : l'appelant doit être un administrateur actif (profil role = admin, non suspendu). Seuls les comptes marqués « test » (profiles.is_test)
// peuvent être ouverts : jamais un vrai compte. Les mots de passe des comptes de test sont aléatoires, jamais renvoyés ni conservés.
// Chaque ouverture est journalisée (test_login_log).
import { adminClient, callerOf, cors, jsonResponse } from "../_shared/core.ts";

export const TEST_ROLES: { role: string; name: string; department?: string }[] = [
  { role: "client", name: "Test Client" },
  { role: "student", name: "Test Étudiant-vendeur", department: "Génie informatique" },
  { role: "company", name: "Test Entreprise" },
  { role: "other", name: "Test Autre rôle" },
  { role: "dept", name: "Test Responsable de département", department: "Génie informatique" },
  { role: "direction", name: "Test Direction" },
  { role: "finance", name: "Test Finance" },
  { role: "support", name: "Test Support" },
];

export const testEmail = (role: string) => `test-${role}@boutik-ecole.test`;

export function randomPassword(): string {
  const b = crypto.getRandomValues(new Uint8Array(24));
  let s = "";
  for (const x of b) s += String.fromCharCode(x);
  return btoa(s).replace(/[+/=]/g, "x") + "Aa1!";
}

if (import.meta.main) {
  Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
    if (req.method !== "POST") return jsonResponse(req, { error: "method" }, 405);
    const uid = await callerOf(req);
    if (!uid) return jsonResponse(req, { error: "unauthorized", message: "Connexion requise." }, 401);
    const admin = adminClient();
    const { data: me } = await admin.from("profiles").select("role,suspended").eq("id", uid).maybeSingle();
    if (!me || me.role !== "admin" || me.suspended) return jsonResponse(req, { error: "forbidden", message: "Réservé à l'administrateur." }, 403);
    let body: Record<string, unknown>;
    try { body = await req.json(); } catch { return jsonResponse(req, { error: "bad_request" }, 400); }

    if (body.action === "ensure") {
      const created: string[] = [], failed: { role: string; message: string }[] = [];
      for (const t of TEST_ROLES) {
        const { data: have } = await admin.from("profiles").select("id").eq("is_test", true).eq("role", t.role).limit(1);
        if (have && have.length > 0) continue;
        const email = testEmail(t.role);
        let id: string | null = null;
        const made = await admin.auth.admin.createUser({ email, password: randomPassword(), email_confirm: true, user_metadata: { name: t.name, test_account: true } });
        if (made.error) {
          // le compte d'authentification existe déjà (essai précédent interrompu) : on le retrouve
          const list = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
          id = list.data?.users?.find((u) => u.email === email)?.id ?? null;
          if (!id) { failed.push({ role: t.role, message: made.error.message }); continue; }
        } else {
          id = made.data.user.id;
        }
        const up = await admin.from("profiles").upsert({ id, name: t.name, email, role: t.role, is_test: true, department: t.department ?? null }, { onConflict: "id" });
        if (up.error) { failed.push({ role: t.role, message: up.error.message }); continue; }
        created.push(t.role);
      }
      return jsonResponse(req, { created, failed });
    }

    if (body.action === "login") {
      const target = String(body.target_id ?? "");
      if (!/^[0-9a-f-]{36}$/i.test(target)) return jsonResponse(req, { error: "bad_request", message: "Compte invalide." }, 400);
      const { data: t } = await admin.from("profiles").select("id,email,role,is_test,suspended").eq("id", target).maybeSingle();
      if (!t || !t.is_test) return jsonResponse(req, { error: "not_test", message: "Seuls les comptes de test peuvent être ouverts ainsi." }, 403);
      if (t.suspended || !t.email) return jsonResponse(req, { error: "unavailable", message: "Compte de test indisponible." }, 409);
      const link = await admin.auth.admin.generateLink({ type: "magiclink", email: t.email });
      const hash = link.data?.properties?.hashed_token;
      if (link.error || !hash) return jsonResponse(req, { error: "link_failed", message: "Le lien de connexion n'a pas pu être créé." }, 502);
      await admin.from("test_login_log").insert({ admin_id: uid, target_id: t.id });
      return jsonResponse(req, { token_hash: hash, email: t.email, role: t.role });
    }

    return jsonResponse(req, { error: "bad_request", message: "Action inconnue." }, 400);
  });
}

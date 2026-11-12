import { randomPassword, TEST_ROLES, testEmail } from "./index.ts";

Deno.test("un compte de test par profil, courriels distincts et reconnaissables", () => {
  const roles = TEST_ROLES.map((t) => t.role);
  const expected = ["client", "student", "company", "other", "dept", "direction", "finance", "support"];
  if (JSON.stringify(roles) !== JSON.stringify(expected)) throw new Error("rôles inattendus : " + roles);
  const mails = new Set(roles.map(testEmail));
  if (mails.size !== roles.length) throw new Error("courriels en double");
  if (!roles.every((r) => testEmail(r) === `test-${r}@boutik-ecole.test`)) throw new Error("format de courriel");
  if (roles.includes("admin")) throw new Error("jamais de compte de test administrateur");
});

Deno.test("mot de passe aléatoire : long, différent à chaque appel", () => {
  const a = randomPassword(), b = randomPassword();
  if (a === b || a.length < 30) throw new Error("mot de passe trop faible");
});

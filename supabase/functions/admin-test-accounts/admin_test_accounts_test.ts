import { TEST_ROLES, testEmail, validPassword } from "./index.ts";

Deno.test("un compte de test par profil, courriels distincts et reconnaissables", () => {
  const roles = TEST_ROLES.map((t) => t.role);
  const expected = ["visitor", "client", "student", "company", "other", "dept", "direction", "finance", "support", "admin"];
  if (JSON.stringify(roles) !== JSON.stringify(expected)) throw new Error("rôles inattendus : " + roles);
  const mails = new Set(roles.map(testEmail));
  if (mails.size !== roles.length) throw new Error("courriels en double");
  if (!roles.every((r) => testEmail(r) === `test-${r}@boutik-ecole.test`)) throw new Error("format de courriel");
});

Deno.test("mot de passe : 10 caractères, une lettre et un chiffre", () => {
  if (!validPassword("Test12345678")) throw new Error("mot de passe valide refusé");
  for (const bad of ["court1A", "sansChiffreAAAA", "12345678901234", "", null, 42, "a1".repeat(40)]) {
    if (validPassword(bad)) throw new Error("mot de passe invalide accepté : " + bad);
  }
});

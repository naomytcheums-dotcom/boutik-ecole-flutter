import { Provider } from "./types.ts";
import { facebook } from "./facebook.ts";
import { instagram } from "./instagram.ts";
import { linkedin } from "./linkedin.ts";
import { tiktok } from "./tiktok.ts";
import { gmail, googleCalendar, googleDocs, googleDrive, googleSheets, youtube } from "./google.ts";
import { onedrive, teams } from "./microsoft.ts";
import { dropbox } from "./dropbox.ts";
import { slack } from "./slack.ts";
import { discord } from "./discord.ts";
import { github } from "./github.ts";
import { notion } from "./notion.ts";
import { trello } from "./trello.ts";

/** Fournisseurs OAuth. Behance (aucune API ouverte) et les opérateurs Mobile Money ont leurs propres circuits. */
export const PROVIDERS: Record<string, Provider> = Object.fromEntries(
  [facebook, instagram, linkedin, tiktok, youtube, googleDrive, googleDocs, googleSheets, gmail, googleCalendar, onedrive, dropbox,
    slack, discord, github, notion, trello, teams].map((p) => [p.id, p]),
);

export const creds = (p: Provider) => ({
  id: Deno.env.get(`${p.env}_CLIENT_ID`) ?? "",
  secret: Deno.env.get(`${p.env}_CLIENT_SECRET`) ?? "",
});

/** Un fournisseur est « prêt » quand l'application développeur est enregistrée (identifiants dans les secrets Supabase). */
export const configured = (p: Provider) => {
  const c = creds(p);
  return c.id.length > 0 && c.secret.length > 0;
};

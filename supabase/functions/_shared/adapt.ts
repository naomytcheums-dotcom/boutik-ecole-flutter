// Adaptation du texte d'une publication Boutik-École à chaque plateforme (limites officielles, usage des liens).
// Miroir exact de lib/figma/live/integrations_model.dart (adaptForPlatform) : l'aperçu de l'application et le texte envoyé sont identiques.

export const TEXT_LIMITS: Record<string, number> = {
  facebook: 5000, instagram: 2200, linkedin: 3000, discord: 2000, slack: 3000, teams: 4000,
  notion: 1900, google_docs: 20000, google_sheets: 5000,
};

export interface Adapted { text: string; link?: string; note?: string }

function clip(text: string, max: number): string {
  if (text.length <= max) return text;
  const cut = text.slice(0, max - 1);
  const sp = cut.lastIndexOf(" ");
  return (sp > max * 0.6 ? cut.slice(0, sp) : cut).trimEnd() + "…";
}

export function adaptText(provider: string, content: string, link?: string): Adapted {
  let t = content.replace(/\r\n/g, "\n").replace(/[ \t]+\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim();
  const max = TEXT_LIMITS[provider] ?? 3000;
  const url = (link ?? "").trim();
  switch (provider) {
    case "instagram": {
      // Les liens d'une légende Instagram ne sont pas cliquables : on renvoie vers la bio.
      const suffix = url ? "\n\nLien dans la bio." : "";
      const tags = t.match(/#[\p{L}\p{N}_]+/gu) ?? [];
      if (tags.length > 30) { for (const x of tags.slice(30)) t = t.replace(x, ""); t = t.replace(/[ \t]{2,}/g, " ").trim(); }
      return { text: clip(t, max - suffix.length) + suffix, note: url ? "Lien non cliquable sur Instagram : « Lien dans la bio »." : undefined };
    }
    case "facebook":
      // Le lien est transmis comme aperçu séparé de la Page, pas collé dans le texte.
      return { text: clip(t, max), link: url || undefined };
    case "slack": {
      t = t.replace(/\*\*(.+?)\*\*/g, "*$1*");
      const suffix = url ? `\n${url}` : "";
      return { text: clip(t, max - suffix.length) + suffix };
    }
    default: {
      const suffix = url ? `\n\n${url}` : "";
      return { text: clip(t, max - suffix.length) + suffix };
    }
  }
}

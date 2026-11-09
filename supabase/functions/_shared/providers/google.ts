// Connecteurs Google : un connecteur indépendant par produit (Drive, Docs, Sheets, Gmail, Agenda, YouTube),
// une même application OAuth Google, des portées distinctes (aucune autorisation partagée entre produits).
import { fetchJson } from "../core.ts";
import { arr, get, Provider, str } from "./types.ts";

const base = {
  kind: "oauth2" as const, env: "GOOGLE", pkce: true,
  authorizeUrl: "https://accounts.google.com/o/oauth2/v2/auth",
  tokenUrl: "https://oauth2.googleapis.com/token",
  // offline : jeton de rafraîchissement ; include_granted_scopes=false : chaque produit garde ses propres autorisations.
  extraAuthParams: { access_type: "offline", prompt: "consent", include_granted_scopes: "false" },
  tokenAuth: "body" as const,
  revokeUrl: (t: string) => ({ url: `https://oauth2.googleapis.com/revoke?token=${encodeURIComponent(t)}`, init: { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" } } as RequestInit }),
};
const SC = "https://www.googleapis.com/auth/";

const profile: Provider["profile"] = async (t) => {
  const u = await get("https://www.googleapis.com/oauth2/v3/userinfo", t.access);
  return { externalId: str(u.sub), displayName: str(u.email || u.name) || "Compte Google" };
};

/** Fichiers visibles avec la portée « drive.file » (créés ou ouverts avec l'application), filtrés par type. */
async function files(token: string, mime: string | null, kind: string) {
  const q = mime ? `mimeType='${mime}' and trashed=false` : "trashed=false";
  const d = await get(`https://www.googleapis.com/drive/v3/files?pageSize=50&orderBy=${encodeURIComponent("modifiedTime desc")}&fields=${encodeURIComponent("files(id,name,webViewLink,modifiedTime,thumbnailLink)")}&q=${encodeURIComponent(q)}`, token);
  return arr(d.files).map((f) => ({ externalId: str(f.id), kind, title: str(f.name), url: str(f.webViewLink) || undefined, mediaUrl: str(f.thumbnailLink) || undefined, publishedAt: str(f.modifiedTime) || undefined }));
}

const authJson = (t: string) => ({ Authorization: `Bearer ${t}`, "Content-Type": "application/json" });

export const googleDrive: Provider = {
  ...base, id: "google_drive", scopes: [SC + "drive.file", SC + "userinfo.profile"], minIntervalSec: 900, profile,
  importItems: async (c) => ({ items: await files(c.token, null, "file") }),
};

export const googleDocs: Provider = {
  ...base, id: "google_docs", scopes: [SC + "drive.file", SC + "userinfo.profile"], minIntervalSec: 900, profile,
  importItems: async (c) => ({ items: await files(c.token, "application/vnd.google-apps.document", "document") }),
  // « Publier » = exporter le texte vers un nouveau Google Doc créé par l'application.
  publish: async (c) => {
    const doc = await fetchJson("https://docs.googleapis.com/v1/documents", { method: "POST", headers: authJson(c.token), body: JSON.stringify({ title: c.title || "Boutik-École" }) });
    const id = str(doc.documentId);
    await fetchJson(`https://docs.googleapis.com/v1/documents/${id}:batchUpdate`, { method: "POST", headers: authJson(c.token), body: JSON.stringify({ requests: [{ insertText: { location: { index: 1 }, text: c.text } }] }) });
    return { externalId: id, url: `https://docs.google.com/document/d/${id}/edit` };
  },
};

export const googleSheets: Provider = {
  ...base, id: "google_sheets", scopes: [SC + "drive.file", SC + "userinfo.profile"], minIntervalSec: 900, profile,
  importItems: async (c) => ({ items: await files(c.token, "application/vnd.google-apps.spreadsheet", "spreadsheet") }),
  // « Publier » = exporter le texte vers un nouveau classeur (cellule A1).
  publish: async (c) => {
    const s = await fetchJson("https://sheets.googleapis.com/v4/spreadsheets", { method: "POST", headers: authJson(c.token), body: JSON.stringify({ properties: { title: c.title || "Boutik-École" } }) });
    const id = str(s.spreadsheetId);
    await fetchJson(`https://sheets.googleapis.com/v4/spreadsheets/${id}/values/A1?valueInputOption=RAW`, { method: "PUT", headers: authJson(c.token), body: JSON.stringify({ values: [[c.text]] }) });
    return { externalId: id, url: str(s.spreadsheetUrl) || `https://docs.google.com/spreadsheets/d/${id}/edit` };
  },
};

// Gmail : « gmail.send » seul. La lecture de la boîte de réception est une portée restreinte soumise à un audit annuel : jamais demandée.
export const gmail: Provider = {
  ...base, id: "gmail", scopes: [SC + "gmail.send", SC + "userinfo.profile", SC + "userinfo.email"], profile,
};

export const googleCalendar: Provider = {
  ...base, id: "google_calendar", scopes: [SC + "calendar.events", SC + "userinfo.profile", SC + "userinfo.email"], minIntervalSec: 900, profile,
  importItems: async (c) => {
    const d = await get(`https://www.googleapis.com/calendar/v3/calendars/primary/events?singleEvents=true&orderBy=startTime&maxResults=25&timeMin=${encodeURIComponent(new Date().toISOString())}`, c.token);
    return {
      items: arr(d.items).map((e) => {
        const s = (e.start ?? {}) as Record<string, unknown>;
        return { externalId: str(e.id), kind: "event", title: str(e.summary) || "Événement", body: str(e.description) || undefined, url: str(e.htmlLink) || undefined, publishedAt: str(s.dateTime || s.date) || undefined };
      }),
    };
  },
};

// YouTube (Data API v3, lecture seule). Aucune API de « publication communauté » ; l'envoi de vidéos relève d'un audit Google.
export const youtube: Provider = {
  ...base, id: "youtube", scopes: [SC + "youtube.readonly"],
  minIntervalSec: 1800, // quota par défaut 10 000 unités / jour ; une lecture de liste coûte 1 unité
  profile: async (t) => {
    const d = await get("https://www.googleapis.com/youtube/v3/channels?part=snippet,contentDetails&mine=true", t.access);
    const ch = arr(d.items)[0];
    if (!ch) throw new Error("Aucune chaîne YouTube sur ce compte Google.");
    const sn = (ch.snippet ?? {}) as Record<string, unknown>;
    const uploads = str(((ch.contentDetails ?? {}) as Record<string, Record<string, unknown>>).relatedPlaylists?.uploads);
    const url = `https://www.youtube.com/channel/${str(ch.id)}`;
    return { externalId: str(ch.id), displayName: str(sn.title), profileUrl: url, accounts: [{ externalId: str(ch.id), kind: "channel", name: str(sn.title), url }], extra: { uploads } };
  },
  importItems: async (c) => {
    const pl = str(c.extra.uploads);
    if (!pl) return { items: [] };
    const d = await get(`https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&maxResults=25&playlistId=${encodeURIComponent(pl)}`, c.token);
    return {
      items: arr(d.items).map((v) => {
        const sn = (v.snippet ?? {}) as Record<string, unknown>;
        const id = str((v.contentDetails as Record<string, unknown>)?.videoId);
        const th = ((sn.thumbnails ?? {}) as Record<string, Record<string, unknown>>).medium;
        return { externalId: id, kind: "video", title: str(sn.title), body: str(sn.description).slice(0, 2000) || undefined, url: `https://www.youtube.com/watch?v=${id}`, mediaUrl: str(th?.url) || undefined, publishedAt: str(sn.publishedAt) || undefined };
      }),
    };
  },
};

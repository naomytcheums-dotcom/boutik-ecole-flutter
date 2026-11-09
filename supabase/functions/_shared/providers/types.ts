// Contrat d'un connecteur. Chaque fournisseur a son propre fichier : aucun ne dépend d'un autre.
import { fetchJson } from "../core.ts";

export interface TokenSet {
  access: string;
  refresh?: string;
  expiresIn?: number;            // secondes
  scopes?: string[];
  raw: Record<string, unknown>;  // réponse brute (jamais journalisée) : identifiants d'équipe, webhook…
}

export interface AccountInfo {
  externalId: string;
  kind: string;
  name: string;
  url?: string;
  publish?: boolean;
}

export interface Profile {
  externalId: string;
  displayName: string;
  profileUrl?: string;
  accounts?: AccountInfo[];
  /** Données secrètes propres au fournisseur (jetons de page, webhook) : chiffrées puis fusionnées avec les précédentes. */
  extra?: Record<string, unknown>;
}

export interface ImportedItem {
  externalId: string;
  kind: string;
  title: string;
  body?: string;
  url?: string;
  mediaUrl?: string;
  publishedAt?: string;
}

export interface SyncContext {
  token: string;
  cursor?: string;
  extra: Record<string, unknown>;
  externalId: string;
  accounts: { id: string; externalId: string; name: string }[];
}

export interface PublishContext {
  token: string;
  extra: Record<string, unknown>;
  externalId: string;
  account?: { externalId: string; name: string };
  text: string;       // déjà adapté à la plateforme
  linkUrl?: string;
  mediaUrl?: string;
  title?: string;
}

export interface Provider {
  id: string;
  kind: "oauth2" | "oauth1a";
  /** Préfixe des variables d'environnement : <ENV>_CLIENT_ID et <ENV>_CLIENT_SECRET (clé d'application chez le fournisseur). */
  env: string;
  authorizeUrl: string;
  tokenUrl: string;
  pkce: boolean;
  scopes: string[];
  scopeSeparator?: string;
  /** Nom du paramètre d'identifiant client (TikTok : client_key). */
  clientIdParam?: string;
  extraAuthParams?: Record<string, string>;
  tokenAuth?: "body" | "basic";
  tokenBody?: "form" | "json";
  revokeUrl?: (token: string, creds: { id: string; secret: string }) => { url: string; init: RequestInit } | null;
  /** Étapes propres au fournisseur après l'échange du code (jeton longue durée Facebook/Instagram). */
  afterToken?: (t: TokenSet, creds: { id: string; secret: string }) => Promise<TokenSet>;
  refresh?: (t: { access: string; refresh?: string }, creds: { id: string; secret: string }) => Promise<TokenSet | null>;
  profile: (t: TokenSet) => Promise<Profile>;
  importItems?: (c: SyncContext) => Promise<{ items: ImportedItem[]; cursor?: string }>;
  publish?: (c: PublishContext) => Promise<{ externalId?: string; url?: string }>;
  /** Intervalle minimal entre deux synchronisations (quotas), en secondes. */
  minIntervalSec?: number;
  maxText?: number;
}

export const GRAPH = Deno.env.get("META_GRAPH_VERSION") ?? "v24.0";

export const bearer = (t: string, extra: Record<string, string> = {}) => ({ headers: { Authorization: `Bearer ${t}`, ...extra } });

export const get = (url: string, token: string, extra: Record<string, string> = {}) => fetchJson(url, bearer(token, extra));

export const arr = (v: unknown): Record<string, unknown>[] => (Array.isArray(v) ? v as Record<string, unknown>[] : []);
export const str = (v: unknown): string => (v == null ? "" : String(v));

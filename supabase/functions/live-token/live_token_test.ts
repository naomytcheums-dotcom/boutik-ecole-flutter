import { livekitToken } from "./index.ts";

Deno.test("jeton LiveKit : structure, droits et signature HS256", async () => {
  const t = await livekitToken("APIkey", "secret-de-test", "user-1", "Awa", "live-abc", true, 600);
  const [h, p, s] = t.split(".");
  const dec = (x: string) => JSON.parse(atob(x.replace(/-/g, "+").replace(/_/g, "/")));
  const header = dec(h), payload = dec(p);
  if (header.alg !== "HS256") throw new Error("alg");
  if (payload.iss !== "APIkey" || payload.sub !== "user-1") throw new Error("claims");
  if (payload.video.room !== "live-abc" || payload.video.canPublish !== true || payload.video.roomJoin !== true) throw new Error("video");
  if (payload.exp - payload.iat !== 600) throw new Error("exp");
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode("secret-de-test"), { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
  const sig = Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - s.length % 4) % 4)), (c) => c.charCodeAt(0));
  if (!(await crypto.subtle.verify("HMAC", key, sig, new TextEncoder().encode(`${h}.${p}`)))) throw new Error("signature");
  const v = await livekitToken("APIkey", "secret-de-test", "user-2", "Paul", "live-abc", false);
  if (dec(v.split(".")[1]).video.canPublish !== false) throw new Error("spectateur ne doit pas publier");
});

"""Double authentification TOTP (écran 272) : inscription d'un facteur, code faux refusé, code exact accepté, session élevée en AAL2.
Utilisable en production (compte jetable zz-test-mfa-*) comme sur la base isolée.
Usage : [BE_URL=… BE_KEY=…] python supabase/tests/mfa_rest.py
"""
import base64, hashlib, hmac, json, os, struct, time, urllib.error, urllib.request, uuid

U = os.environ.get("BE_URL", "https://zxqcnmgwhtbxkdpjqtlr.supabase.co")
K = os.environ.get("BE_KEY", "sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01")
res = []


def call(path, body=None, token=None, method="POST"):
    h = {"apikey": K, "Content-Type": "application/json"}
    if token:
        h["Authorization"] = "Bearer " + token
    req = urllib.request.Request(U + path, data=json.dumps(body).encode() if body is not None else None, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            b = r.read()
            return r.status, (json.loads(b) if b else None)
    except urllib.error.HTTPError as e:
        b = e.read()
        try:
            return e.code, json.loads(b)
        except Exception:
            return e.code, b.decode(errors="replace")


def check(name, cond, detail=""):
    res.append(bool(cond))
    print("OK    " if cond else "ECHEC ", name, "|", str(detail)[:140])


def totp(secret, t=None):
    key = base64.b32decode(secret.upper() + "=" * (-len(secret) % 8))
    msg = struct.pack(">Q", int((t or time.time()) // 30))
    h = hmac.new(key, msg, hashlib.sha1).digest()
    o = h[-1] & 0x0F
    return "%06d" % ((struct.unpack(">I", h[o:o + 4])[0] & 0x7FFFFFFF) % 1000000)


def claims(tok):
    p = tok.split(".")[1]
    return json.loads(base64.urlsafe_b64decode(p + "=" * (-len(p) % 4)))


email = f"zz-test-mfa-{uuid.uuid4().hex[:8]}@example.com"
s, d = call("/auth/v1/signup", {"email": email, "password": "Zz-test-" + uuid.uuid4().hex[:8] + "!"})
tok = d["access_token"]
check("session initiale en AAL1", claims(tok).get("aal") == "aal1", claims(tok).get("aal"))
s, d = call("/auth/v1/factors", {"factor_type": "totp", "issuer": "Boutik-École", "friendly_name": "test"}, None)
check("visiteur : inscription d'un facteur refusée", s >= 400, s)
s, f = call("/auth/v1/factors", {"factor_type": "totp", "issuer": "Boutik-École", "friendly_name": "test"}, tok)
check("inscription du facteur TOTP (QR code et clé fournis)", s == 200 and f.get("totp", {}).get("secret") and "<svg" in f["totp"].get("qr_code", ""), s)
fid, secret = f["id"], f["totp"]["secret"]
s, ch = call(f"/auth/v1/factors/{fid}/challenge", {}, tok)
check("défi créé", s == 200 and ch.get("id"), s)
bad = "000000" if totp(secret) != "000000" else "111111"
s, d = call(f"/auth/v1/factors/{fid}/verify", {"challenge_id": ch["id"], "code": bad}, tok)
check("code faux refusé", s >= 400, d)
s, ch = call(f"/auth/v1/factors/{fid}/challenge", {}, tok)
s, v = call(f"/auth/v1/factors/{fid}/verify", {"challenge_id": ch["id"], "code": totp(secret)}, tok)
check("code exact accepté", s == 200 and v.get("access_token"), s)
check("session élevée en AAL2 (méthode totp)", claims(v["access_token"]).get("aal") == "aal2" and any(m.get("method") == "totp" for m in claims(v["access_token"]).get("amr", [])), claims(v["access_token"]).get("aal"))
s, d = call("/auth/v1/user", None, v["access_token"], "GET")
check("facteur vérifié enregistré sur le compte", any(x.get("status") == "verified" and x.get("factor_type") == "totp" for x in d.get("factors", [])), [x.get("status") for x in d.get("factors", [])])
print(f"\n{sum(res)}/{len(res)}")

import json, urllib.request, urllib.error, uuid

U = "https://zxqcnmgwhtbxkdpjqtlr.supabase.co"
K = "sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01"


def call(path, body=None, token=None, method="POST"):
    h = {"apikey": K, "Content-Type": "application/json", "Prefer": "return=representation"}
    if token:
        h["Authorization"] = "Bearer " + token
    req = urllib.request.Request(U + path, data=json.dumps(body).encode() if body is not None else None, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, raw.decode()


res = []


def check(name, cond, detail=""):
    res.append(bool(cond))
    print("OK    " if cond else "ECHEC ", name, "|", str(detail)[:140])


def mk(tag):
    email = f"zz-test-{tag}-{uuid.uuid4().hex[:8]}@example.com"
    pw = uuid.uuid4().hex + "Aa1!"
    s, d = call("/auth/v1/signup", {"email": email, "password": pw})
    uid = d["user"]["id"]
    call("/rest/v1/profiles", {"id": uid, "name": tag, "email": email, "role": "client"}, d["access_token"])
    return email, pw, d["access_token"], uid


ea, pa, ta, ia = mk("fa")
eb, pb, tb, ib = mk("fb")

s, L = call("/rest/v1/listings?select=id,title&seller_id=is.null&limit=2", None, ta, "GET")
l1, l2 = L[0]["id"], L[1]["id"]

s, d = call("/rest/v1/favorites", {"user_id": ia, "listing_id": l1}, ta)
check("A ajoute un favori", s in (200, 201), d)
s, d = call("/rest/v1/favorites", {"user_id": ib, "listing_id": l1}, ta)
check("A ne peut pas écrire un favori au nom de B", s >= 400, f"{s} {d}")
s, d = call("/rest/v1/favorites?select=listing_id,listings(title)", None, tb, "GET")
check("B ne voit aucun favori de A", s == 200 and d == [], d)
s, d = call("/rest/v1/favorites", {"user_id": ib, "listing_id": l2}, tb)
check("B ajoute son propre favori", s in (200, 201), d)

# reconnexion de A : session neuve
s, d = call("/auth/v1/token?grant_type=password", {"email": ea, "password": pa})
ta2 = d["access_token"]
s, d = call("/rest/v1/favorites?select=listing_id,listings(title)", None, ta2, "GET")
check("A retrouve son favori après reconnexion (et seulement le sien)", s == 200 and len(d) == 1 and d[0]["listing_id"] == l1, d)
s, d = call(f"/rest/v1/favorites?user_id=eq.{ib}", None, ta2, "DELETE")
check("A ne peut pas supprimer les favoris de B", s == 200 and d == [], d)
s, d = call("/rest/v1/favorites?select=listing_id", None, tb, "GET")
check("B garde son favori", d == [{"listing_id": l2}], d)
s, d = call(f"/rest/v1/favorites?listing_id=eq.{l1}", None, ta2, "DELETE")
check("A retire son favori", s == 200 and len(d) == 1, d)
s, d = call("/rest/v1/favorites?select=listing_id", None, ta2, "GET")
check("A n'a plus de favori", d == [], d)

print("EMAILS", ea, eb)
print(f"{sum(res)}/{len(res)} réussis")

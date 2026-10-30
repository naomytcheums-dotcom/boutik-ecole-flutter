"""Tests REST de my_conversations() et listing_contact() sur la base réelle (comptes jetables zz-test-*).
Phase 1 : crée A (vendeur, nom « Alice Vendeuse »), B (acheteur, « Bruno Acheteur »), C (tiers) et l'annonce de A -> un valideur approuve (SQL).
Phase 2 : démarre la conversation et contrôle les listes."""
import json, os, sys, urllib.request, urllib.error, uuid

U = "https://zxqcnmgwhtbxkdpjqtlr.supabase.co"
K = "sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01"
STATE = os.environ.get("STATE", "conv_state.json")
res = []


def call(path, body=None, token=None, method="POST"):
    h = {"apikey": K, "Content-Type": "application/json", "Prefer": "return=representation"}
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
    print("OK    " if cond else "ECHEC ", name, "|", str(detail)[:150])


def mk(tag, name, role):
    email = f"zz-test-{tag}-{uuid.uuid4().hex[:8]}@example.com"
    s, d = call("/auth/v1/signup", {"email": email, "password": uuid.uuid4().hex + "Aa1!"})
    uid, tok = d["user"]["id"], d["access_token"]
    call("/rest/v1/profiles", {"id": uid, "name": name, "email": email, "role": role}, tok)
    return {"id": uid, "tok": tok}


def phase1():
    A, B, C = mk("vend", "Alice Vendeuse", "student"), mk("ach", "Bruno Acheteur", "client"), mk("tiers", "Chloé Tierce", "client")
    title = "zz-test-conv-" + uuid.uuid4().hex[:6]
    s, d = call("/rest/v1/listings", {"title": title, "department": "T", "category": "Art", "price": 10000, "stock": 10, "status": "pending"}, A["tok"])
    check("A crée une annonce", s in (200, 201), d)
    json.dump({"A": A, "B": B, "C": C, "title": title, "lid": d[0]["id"]}, open(STATE, "w"))


def phase2():
    S = json.load(open(STATE)); A, B, C, title, lid = S["A"], S["B"], S["C"], S["title"], S["lid"]
    s, d = call("/rest/v1/rpc/listing_contact", {"p_title": title}, B["tok"])
    check("listing_contact : annonce d'un vendeur -> identifiant et vendeur présent", s == 200 and d[0]["listing_id"] == lid and d[0]["has_seller"] is True, d)
    s, L = call("/rest/v1/listings?select=title&seller_id=is.null&limit=1", None, B["tok"], "GET")
    s, d = call("/rest/v1/rpc/listing_contact", {"p_title": L[0]["title"]}, B["tok"])
    check("listing_contact : produit de la plateforme -> pas de vendeur", d[0]["has_seller"] is False, d)
    s, d = call("/rest/v1/rpc/listing_contact", {"p_title": "titre qui n'existe pas"}, B["tok"])
    check("listing_contact : titre inconnu -> rien", d == [], d)

    s, cid = call("/rest/v1/rpc/start_conversation", {"p_listing": lid, "p_body": "Bonjour Alice"}, B["tok"])
    s, d = call("/rest/v1/rpc/my_conversations", {}, B["tok"])
    check("B voit la conversation avec le NOM de la vendeuse, le titre de l'annonce et le dernier message", len(d) == 1 and d[0]["other_name"] == "Alice Vendeuse" and d[0]["listing_title"] == title and d[0]["last_body"] == "Bonjour Alice" and d[0]["unread"] == 0, d)
    s, d = call("/rest/v1/rpc/my_conversations", {}, A["tok"])
    check("A voit la conversation avec le nom de l'acheteur et 1 message non lu", len(d) == 1 and d[0]["other_name"] == "Bruno Acheteur" and d[0]["unread"] == 1, d)
    s, d = call("/rest/v1/rpc/my_conversations", {}, C["tok"])
    check("C (tiers) ne voit aucune conversation ni aucun nom", d == [], d)
    s, d = call("/rest/v1/rpc/my_conversations", {})
    check("un anonyme ne peut pas lister", s >= 400, f"{s}")
    call("/rest/v1/rpc/mark_conversation_read", {"cid": cid}, A["tok"])
    s, d = call("/rest/v1/rpc/my_conversations", {}, A["tok"])
    check("après lecture, A n'a plus de message non lu", d[0]["unread"] == 0, d)
    print(f"\n{sum(res)}/{len(res)}")


if __name__ == "__main__":
    phase1() if sys.argv[1] == "1" else phase2()

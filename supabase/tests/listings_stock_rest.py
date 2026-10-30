"""Tests REST des annonces et du stock sur la base réelle (comptes jetables zz-test-*, à supprimer ensuite).

Phase 1 : python listings_stock_rest.py 1   -> crée A (vendeur), B (acheteur), C (client sans droit de vente), annonce de A, contrôles d'isolation
           (puis un valideur approuve l'annonce : mise en place faite en SQL par le propriétaire de la base)
Phase 2 : python listings_stock_rest.py 2   -> commandes, stock, concurrence, annulation, historique, images
L'état est conservé dans STATE (JSON).
"""
import json, os, sys, threading, urllib.request, urllib.error, uuid

U = os.environ.get("BE_URL", "https://zxqcnmgwhtbxkdpjqtlr.supabase.co")
K = os.environ.get("BE_KEY", "sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01")
STATE = os.environ.get("STATE", "listings_state.json")
res = []


def call(path, body=None, token=None, method="POST", raw=None, headers=None):
    h = {"apikey": K, "Content-Type": "application/json", "Prefer": "return=representation"}
    if token:
        h["Authorization"] = "Bearer " + token
    h.update(headers or {})
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(U + path, data=data, headers=h, method=method)
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


def mk(tag, role):
    email = f"zz-test-{tag}-{uuid.uuid4().hex[:8]}@example.com"
    pw = uuid.uuid4().hex + "Aa1!"
    s, d = call("/auth/v1/signup", {"email": email, "password": pw})
    uid, tok = d["user"]["id"], d["access_token"]
    call("/rest/v1/profiles", {"id": uid, "name": tag, "email": email, "role": role}, tok)
    return {"email": email, "pw": pw, "id": uid, "tok": tok}


def phase1():
    A, B, C = mk("vendeur", "student"), mk("acheteur", "client"), mk("client2", "client")
    title = "zz-test-lampe-" + uuid.uuid4().hex[:6]
    s, d = call("/rest/v1/listings", {"seller_id": B["id"], "title": title, "department": "Test", "category": "Maison", "price": 12000, "stock": 5, "status": "approved"}, A["tok"])
    check("A crée une annonce : propriétaire forcé à A (même si seller_id=B) et statut forcé à 'pending'", s in (200, 201) and d[0]["seller_id"] == A["id"] and d[0]["status"] == "pending", d)
    lid = d[0]["id"] if isinstance(d, list) else None
    s, d2 = call("/rest/v1/listings", {"title": "zz-test-brouillon-" + uuid.uuid4().hex[:6], "department": "Test", "category": "Art", "price": 5000, "stock": 3, "status": "draft", "seller_id": A["id"]}, A["tok"])
    check("A crée un brouillon", s in (200, 201) and d2[0]["status"] == "draft", d2)
    draft = d2[0]["id"]
    s, d = call("/rest/v1/listings", {"title": "zz-test-b-" + uuid.uuid4().hex[:6], "department": "T", "category": "Art", "price": 5000, "stock": 1, "seller_id": B["id"]}, B["tok"])
    check("B (client) ne peut pas créer d'annonce", s >= 400, f"{s} {d}")
    s, d = call(f"/rest/v1/listings?id=eq.{draft}&select=id", None, B["tok"], "GET")
    check("B ne voit pas le brouillon de A", d == [], d)
    s, d = call(f"/rest/v1/listings?id=eq.{lid}&select=id", None, B["tok"], "GET")
    check("B ne voit pas l'annonce en attente de A", d == [], d)
    s, d = call(f"/rest/v1/listings?id=eq.{lid}", {"price": 1}, B["tok"], "PATCH")
    check("B ne peut pas modifier l'annonce de A", s == 200 and d == [], d)
    s, d = call(f"/rest/v1/listings?id=eq.{lid}", {"status": "approved"}, A["tok"], "PATCH")
    check("A ne peut pas approuver sa propre annonce", s >= 400, f"{s} {d}")
    s, d = call(f"/rest/v1/listings?id=eq.{draft}", {"status": "approved"}, A["tok"], "PATCH")
    check("A ne peut pas passer un brouillon en 'approved'", s >= 400, f"{s} {d}")
    s, d = call(f"/rest/v1/listings?id=eq.{draft}", {"status": "pending", "price": 6000, "stock": 10}, A["tok"], "PATCH")
    check("A modifie son brouillon et le soumet (draft -> pending)", s == 200 and d[0]["status"] == "pending" and d[0]["price"] == 6000, d)
    s, d = call(f"/rest/v1/listings?id=eq.{draft}", {"status": "draft"}, A["tok"], "PATCH")
    check("A retire sa soumission (pending -> draft)", s == 200 and d[0]["status"] == "draft", d)
    s, d = call(f"/rest/v1/listings?id=eq.{draft}", {"seller_id": B["id"]}, A["tok"], "PATCH")
    check("A ne peut pas céder son annonce à B (propriétaire immuable)", s == 200 and d[0]["seller_id"] == A["id"], d)
    for name, body in [("stock négatif", {"stock": -1}), ("prix < 500", {"price": 100}), ("titre trop court", {"title": "ab"}), ("description > 2000", {"description": "x" * 2001})]:
        s, d = call(f"/rest/v1/listings?id=eq.{draft}", body, A["tok"], "PATCH")
        check(f"validation serveur : {name} refusé", s >= 400, f"{s} {str(d)[:70]}")
    s, d = call("/rest/v1/listings", {"title": title.upper(), "department": "T", "category": "Art", "price": 5000, "stock": 1, "status": "draft"}, A["tok"])
    check("titre en double (casse différente) refusé", s >= 400, f"{s} {str(d)[:70]}")
    s, d = call(f"/rest/v1/listings?id=eq.{lid}&select=id", None, A["tok"], "GET")
    check("A voit ses annonces", len(d) == 1, d)
    json.dump({"A": A, "B": B, "C": C, "title": title, "lid": lid, "draft": draft}, open(STATE, "w"))
    print("\nPHASE 1 :", sum(res), "/", len(res), "| titre =", title)


def phase2():
    S = json.load(open(STATE))
    A, B, C, title, lid = S["A"], S["B"], S["C"], S["title"], S["lid"]
    s, d = call(f"/rest/v1/listings?id=eq.{lid}&select=status,stock", None, B["tok"], "GET")
    check("l'annonce approuvée (par un valideur) est visible de B", d == [{"status": "approved", "stock": 5}], d)

    def order(tok, q):
        return call("/rest/v1/rpc/create_order", {"p_items": [{"title": title, "qty": q}], "p_home": False, "p_method": "Mobile Money"}, tok)

    s, o1 = order(B["tok"], 3)
    check("B commande 3 (stock 5 -> 2)", s == 200 and o1.get("subtotal") == 36000, o1)
    s, d = call(f"/rest/v1/listings?id=eq.{lid}&select=stock", None, A["tok"], "GET")
    check("le stock a été décrémenté côté serveur", d == [{"stock": 2}], d)
    s, d = order(B["tok"], 3)
    check("vente au-delà du stock refusée (3 > 2)", s >= 400 and "Stock insuffisant" in str(d), d)
    results = []
    ts = [threading.Thread(target=lambda: results.append(order(B["tok"], 2))) for _ in range(2)]
    [t.start() for t in ts]; [t.join() for t in ts]
    ok = [r for r in results if r[0] == 200]
    check("deux commandes simultanées de 2 sur un stock de 2 : une seule aboutit", len(ok) == 1, [r[0] for r in results])
    s, d = call(f"/rest/v1/listings?id=eq.{lid}&select=stock", None, A["tok"], "GET")
    check("stock final = 0 (jamais négatif)", d == [{"stock": 0}], d)
    s, d = call("/rest/v1/listings?select=id&limit=1", None, C["tok"], "GET")
    s, d = call("/rest/v1/rpc/cancel_order", {"p_number": o1["number"]}, C["tok"])
    check("un autre compte ne peut pas annuler la commande de B", s >= 400, f"{s} {str(d)[:70]}")
    s, d = call("/rest/v1/rpc/cancel_order", {"p_number": o1["number"]}, B["tok"])
    check("B annule sa commande impayée", s == 200 and d == "cancelled", d)
    s, d = call("/rest/v1/rpc/cancel_order", {"p_number": o1["number"]}, B["tok"])
    check("double annulation refusée", s >= 400, f"{s} {str(d)[:70]}")
    s, d = call(f"/rest/v1/listings?id=eq.{lid}&select=stock", None, A["tok"], "GET")
    check("le stock réservé est restitué (0 + 3 = 3)", d == [{"stock": 3}], d)
    s, d = call(f"/rest/v1/stock_movements?listing_id=eq.{lid}&select=delta,reason,stock_after&order=id", None, A["tok"], "GET")
    reasons = [(x["delta"], x["reason"]) for x in d] if isinstance(d, list) else d
    check("A lit l'historique des mouvements de stock (initial, commandes, annulation)", reasons[:1] == [(5, "stock initial")] and (-3, "commande") in reasons and (3, "annulation") in reasons, reasons)
    s, d = call(f"/rest/v1/stock_movements?listing_id=eq.{lid}&select=id", None, B["tok"], "GET")
    check("B ne lit pas les mouvements de stock de A", d == [], d)
    s, d = call(f"/rest/v1/listing_history?listing_id=eq.{lid}&select=action", None, A["tok"], "GET")
    check("A lit l'historique des modifications de son annonce", isinstance(d, list) and len(d) >= 2, [x["action"] for x in d] if isinstance(d, list) else d)
    s, d = call(f"/rest/v1/listing_history?listing_id=eq.{lid}&select=action", None, B["tok"], "GET")
    check("B ne lit pas l'historique de A", d == [], d)
    s, d = call(f"/rest/v1/listings?id=eq.{lid}", {"stock": 99999}, A["tok"], "PATCH")
    check("A ajuste son stock", s == 200 and d[0]["stock"] == 99999, d)
    s, d = call(f"/rest/v1/listings?id=eq.{lid}", {"stock": 3, "status": "removed"}, A["tok"], "PATCH")
    check("A supprime (archive) son annonce", s == 200 and d[0]["status"] == "removed", d)
    s, d = call(f"/rest/v1/listings?id=eq.{lid}", {"status": "approved"}, A["tok"], "PATCH")
    check("une annonce supprimée ne peut plus être modifiée", s >= 400, f"{s} {str(d)[:70]}")
    s, d = order(B["tok"], 1)
    check("une annonce supprimée n'est plus commandable", s >= 400, str(d)[:90])

    png = bytes.fromhex("89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d49444154789c6360000002000001e221bc330000000049454e44ae426082")
    sp = f"/storage/v1/object/listing-images/{A['id']}/test-{uuid.uuid4().hex[:6]}.png"
    s, d = call(sp, raw=png, token=A["tok"], headers={"Content-Type": "image/png", "Prefer": ""})
    check("A dépose une image dans son dossier", s in (200, 201), f"{s} {str(d)[:80]}")
    s, d = call(f"/storage/v1/object/listing-images/{B['id']}/intrus.png", raw=png, token=A["tok"], headers={"Content-Type": "image/png", "Prefer": ""})
    check("A ne peut pas déposer dans le dossier de B", s >= 400, f"{s} {str(d)[:80]}")
    s, d = call(f"/storage/v1/object/listing-images/{A['id']}/script.html", raw=b"<script>1</script>", token=A["tok"], headers={"Content-Type": "text/html", "Prefer": ""})
    check("type de fichier non image refusé", s >= 400, f"{s} {str(d)[:80]}")
    s, d = call(sp, token=B["tok"], method="DELETE", headers={"Prefer": ""})
    check("B ne peut pas supprimer l'image de A", not (s == 200 and isinstance(d, dict) and d.get("message") == "Successfully deleted"), f"{s} {str(d)[:80]}")
    r = urllib.request.urlopen(U + sp.replace("/object/", "/object/public/"), timeout=30)
    check("l'image est lisible publiquement", r.status == 200, r.status)
    print("\nEMAILS", A["email"], B["email"], C["email"])
    print("PHASE 2 :", sum(res), "/", len(res))


if __name__ == "__main__":
    phase1() if sys.argv[1] == "1" else phase2()

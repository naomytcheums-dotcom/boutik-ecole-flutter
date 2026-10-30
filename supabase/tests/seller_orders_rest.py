"""Tests REST des commandes reçues par le vendeur (base réelle, comptes jetables zz-test-*).
Phase 1 : A (vendeur), B (acheteur), C (autre vendeur), annonce de A -> un valideur approuve (SQL)
Phase 2 : B commande (non payée) ; contrôles de visibilité                 -> la commande est marquée payée (SQL, simule le webhook)
Phase 3 : liste du vendeur, statuts, notifications, permissions."""
import json, os, sys, urllib.request, urllib.error, uuid

U = "https://zxqcnmgwhtbxkdpjqtlr.supabase.co"
K = "sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01"
STATE = os.environ.get("STATE", "so_state.json")
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
    print("OK    " if cond else "ECHEC ", name, "|", str(detail)[:140])


def mk(tag, name, role):
    email = f"zz-test-{tag}-{uuid.uuid4().hex[:8]}@example.com"
    s, d = call("/auth/v1/signup", {"email": email, "password": uuid.uuid4().hex + "Aa1!"})
    uid, tok = d["user"]["id"], d["access_token"]
    call("/rest/v1/profiles", {"id": uid, "name": name, "email": email, "role": role}, tok)
    return {"id": uid, "tok": tok}


def phase1():
    A, B, C = mk("cvend", "Alice Vendeuse", "student"), mk("cach", "Bruno Acheteur", "client"), mk("cautre", "Chloé Autre", "student")
    title = "zz-test-cmd-" + uuid.uuid4().hex[:6]
    s, d = call("/rest/v1/listings", {"title": title, "department": "T", "category": "Art", "price": 10000, "stock": 10, "status": "pending"}, A["tok"])
    check("A crée une annonce", s in (200, 201), d)
    json.dump({"A": A, "B": B, "C": C, "title": title}, open(STATE, "w"))


def phase2():
    S = json.load(open(STATE)); A, B, C, title = S["A"], S["B"], S["C"], S["title"]
    s, o = call("/rest/v1/rpc/create_order", {"p_items": [{"title": title, "qty": 2}], "p_home": False, "p_method": "Mobile Money"}, B["tok"])
    check("B passe commande (non payée)", s == 200, o)
    S["order"] = o["number"]
    s, d = call("/rest/v1/rpc/seller_orders", {}, A["tok"])
    check("commande non payée : invisible du vendeur", d == [], d)
    json.dump(S, open(STATE, "w"))


def phase3():
    S = json.load(open(STATE)); A, B, C, title, num = S["A"], S["B"], S["C"], S["title"], S["order"]
    s, d = call("/rest/v1/rpc/seller_orders", {}, A["tok"])
    check("A voit la commande payée : titre, quantité, total, acheteur abrégé, statut 0", len(d) == 1 and d[0]["number"] == num and d[0]["qty"] == 2 and d[0]["total"] == 20000 and d[0]["buyer_name"] == "Bruno A." and d[0]["status"] == 0, d)
    s, d = call("/rest/v1/rpc/seller_orders", {}, C["tok"])
    check("C (autre vendeur) ne voit rien", d == [], d)
    s, d = call("/rest/v1/rpc/seller_orders", {}, B["tok"])
    check("B (acheteur) ne voit aucune commande reçue", d == [], d)
    s, d = call("/rest/v1/rpc/seller_orders", {})
    check("anonyme refusé", s >= 400, s)
    s, d = call("/rest/v1/rpc/set_seller_order_status", {"p_order": num, "p_status": 3}, C["tok"])
    check("C ne peut pas changer le statut", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/rpc/set_seller_order_status", {"p_order": num, "p_status": 3}, B["tok"])
    check("l'acheteur ne peut pas changer le statut", s >= 400, str(d)[:80])
    s, d = call(f"/rest/v1/order_lines?select=id", {"fulfillment": 4}, A["tok"], "PATCH")
    check("mise à jour directe de order_lines refusée", s >= 400 or d == [] or d is None, f"{s} {str(d)[:60]}")
    s, d = call("/rest/v1/rpc/set_seller_order_status", {"p_order": num, "p_status": 1}, A["tok"])
    check("A accepte la commande (1)", s == 200 and d == 1, d)
    s, d = call("/rest/v1/rpc/set_seller_order_status", {"p_order": num, "p_status": 3}, A["tok"])
    check("A la marque prête (3)", s == 200 and d == 3, d)
    s, d = call("/rest/v1/rpc/set_seller_order_status", {"p_order": num, "p_status": 2}, A["tok"])
    check("retour en arrière refusé", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/rpc/set_seller_order_status", {"p_order": num, "p_status": 9}, A["tok"])
    check("statut invalide refusé", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/rpc/seller_orders", {}, A["tok"])
    check("le statut est persistant (3)", d[0]["status"] == 3, d)
    s, d = call("/rest/v1/notifications?select=title,body&kind=eq.order&order=created_at", None, B["tok"], "GET")
    titles = [x["title"] for x in d]
    check("B est notifié : paiement confirmé, commande acceptée, commande prête", titles == ["Paiement confirmé", "Commande acceptée", "Commande prête"], titles)
    s, d = call("/rest/v1/notifications?select=title&kind=eq.order", None, C["tok"], "GET")
    check("C n'est pas notifié", d == [], d)
    s, d = call("/rest/v1/rpc/set_seller_order_status", {"p_order": num, "p_status": 4}, A["tok"])
    check("A marque la commande livrée (4)", s == 200 and d == 4, d)
    print(f"\n{sum(res)}/{len(res)}")


if __name__ == "__main__":
    {"1": phase1, "2": phase2, "3": phase3}[sys.argv[1]]()

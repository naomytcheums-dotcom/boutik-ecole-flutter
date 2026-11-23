"""Recette en PRODUCTION par rôle (autorisée le 01/11) : comptes zz-test-recette-*, parcours réels, aucune donnée réelle touchée.

Chaque donnée créée est laissée dans un état final (annulée, masquée, retirée, supprimée). Aucun paiement.
Usage : python prod_recette.py <fichier_comptes.json> <sortie.txt>
"""
import base64, json, sys, time, urllib.error, urllib.request

U = "https://zxqcnmgwhtbxkdpjqtlr.supabase.co"
K = "sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01"
accounts = json.load(open(sys.argv[1], encoding="utf-8"))
out = open(sys.argv[2], "w", encoding="utf-8")
res = []


def call(method, path, body=None, tok=None, headers=None, raw=None, ctype="application/json"):
    h = {"apikey": K}
    if body is not None or raw is not None:
        h["Content-Type"] = ctype
    if tok:
        h["Authorization"] = "Bearer " + tok
    h.update(headers or {})
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(U + path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            t = r.read().decode() or "null"
            return r.status, json.loads(t) if t.strip()[:1] in "[{\"tn0123456789-" else t
    except urllib.error.HTTPError as e:
        t = e.read().decode()
        try:
            return e.code, json.loads(t)
        except Exception:
            return e.code, t


def rpc(fn, params, tok=None):
    return call("POST", f"/rest/v1/rpc/{fn}", params, tok)


def check(name, ok, detail=""):
    res.append(bool(ok))
    line = f"{'OK   ' if ok else 'ECHEC'}  {name} | {str(detail)[:160]}"
    print(line)
    out.write(line + "\n")


def login(role):
    a = accounts[role]
    s, r = call("POST", "/auth/v1/token?grant_type=password", {"email": a["email"], "password": a["password"]})
    return r.get("access_token") if s == 200 else None, (r.get("user") or {}).get("id")


tok, uid = {}, {}
for role in accounts:
    tok[role], uid[role] = login(role)
    check(f"connexion {role}", tok[role] is not None)

# --- rôles réels vus par le serveur
for role, expected in [("admin", "admin"), ("dept", "dept"), ("support", "support"), ("vendeur", "student"), ("client", "client")]:
    s, r = call("GET", f"/rest/v1/profiles?select=role&id=eq.{uid[role]}", tok=tok[role])
    check(f"rôle serveur {role}", s == 200 and r and r[0]["role"] == expected, r)

# --- administrateur : voit tous les comptes ; suspend puis réactive le client de recette ; un client ne peut pas
s, r = call("GET", "/rest/v1/profiles?select=id", tok=tok["admin"], headers={"Prefer": "count=exact", "Range": "0-0"})
check("administrateur : lecture de tous les profils (RLS)", s in (200, 206), s)
s, r = rpc("admin_set_account", {"p_user": uid["client"], "p_role": "client", "p_suspended": True}, tok["admin"])
check("administrateur suspend le client de recette", s == 200, r)
s2, r2 = call("POST", "/auth/v1/token?grant_type=password", {"email": accounts["client"]["email"], "password": accounts["client"]["password"]})
check("compte suspendu : connexion refusée", s2 != 200, s2)
s, r = rpc("admin_set_account", {"p_user": uid["client"], "p_role": "client", "p_suspended": False}, tok["admin"])
check("administrateur réactive le client", s == 200, r)
tok["client"], _ = login("client")
check("client réactivé : connexion rétablie", tok["client"] is not None)
s, r = rpc("admin_set_account", {"p_user": uid["vendeur"], "p_role": "admin", "p_suspended": False}, tok["client"])
check("un client ne peut pas changer un rôle", s >= 400, r)

# --- vendeur → département → client : annonce, validation, commande, annulation
title = f"zz-test recette {int(time.time())}"
s, r = call("POST", "/rest/v1/listings", {"seller_id": uid["vendeur"], "title": title, "department": "IUT de Douala", "category": "Maison", "price": 2000, "stock": 3, "status": "pending"},
            tok["vendeur"], headers={"Prefer": "return=representation"})
lid = r[0]["id"] if s == 201 and r else None
check("vendeur : annonce créée en validation", lid is not None, r)
s, r = call("GET", f"/rest/v1/listings?select=id&id=eq.{lid}", tok=tok["client"])
check("client : annonce en validation invisible", s == 200 and r == [], r)
s, r = call("PATCH", f"/rest/v1/listings?id=eq.{lid}", {"status": "approved"}, tok["vendeur"], headers={"Prefer": "return=representation"})
check("vendeur : ne peut pas s'auto-valider", s >= 400 or (r and r[0]["status"] != "approved"), r)
s, r = call("PATCH", f"/rest/v1/listings?id=eq.{lid}", {"status": "approved"}, tok["dept"], headers={"Prefer": "return=representation"})
check("département : validation de l'annonce", s == 200 and r and r[0]["status"] == "approved", r)
s, o = rpc("create_order", {"p_items": [{"title": title, "qty": 2}], "p_home": False, "p_method": "Orange Money"}, tok["client"])
num = o.get("number") if isinstance(o, dict) else None
check("client : commande en retrait sur campus (prix serveur 2 × 2 000)", s == 200 and o.get("subtotal") == 4000 and o.get("fee") == 0, o)
s, r = call("GET", f"/rest/v1/listings?select=stock&id=eq.{lid}", tok=tok["vendeur"])
check("stock décrémenté (3 → 1)", s == 200 and r and r[0]["stock"] == 1, r)
s, r = rpc("create_order", {"p_items": [{"title": title, "qty": 1}], "p_home": True, "p_method": "Orange Money"}, tok["client"])
check("livraison à domicile refusée (désactivée)", s >= 400, r)
s, r = rpc("cancel_order", {"p_number": num}, tok["client"])
check("client : annulation de la commande", s == 200, r)
s, r = call("GET", f"/rest/v1/listings?select=stock&id=eq.{lid}", tok=tok["vendeur"])
check("stock restitué (1 → 3)", s == 200 and r and r[0]["stock"] == 3, r)
s, r = rpc("my_pickup_code", {"p_number": num}, tok["client"])
check("code de retrait refusé pour une commande non payée", s >= 400, r)
s, r = rpc("confirm_pickup", {"p_number": num, "p_code": "000000"}, tok["support"])
check("support : remise refusée (commande non payée)", s >= 400, r)
s, r = rpc("confirm_pickup", {"p_number": num, "p_code": "000000"}, tok["client"])
check("client : remise au kiosque refusée", s >= 400, r)
s, r = call("PATCH", f"/rest/v1/listings?id=eq.{lid}", {"status": "removed"}, tok["vendeur"], headers={"Prefer": "return=representation"})
check("vendeur : retrait de son annonce", s == 200 and r and r[0]["status"] == "removed", r)

# --- produits de la plateforme : le département les gère, le vendeur non
s, r = call("GET", "/rest/v1/listings?select=id,stock&seller_id=is.null&title=eq.Jus%20de%20bissap", tok=tok["dept"])
pid, pstock = (r[0]["id"], r[0]["stock"]) if s == 200 and r else (None, None)
s, r = call("PATCH", f"/rest/v1/listings?id=eq.{pid}", {"stock": pstock}, tok["vendeur"], headers={"Prefer": "return=representation"})
check("vendeur : ne modifie pas un produit de la plateforme", s >= 400 or r == [], r)
s, r = rpc("seller_orders", {}, tok["dept"])
check("département : commandes à préparer (lecture)", s == 200 and isinstance(r, list), r)

# --- concours : brouillon par le département, invisible au public, puis annulé
s, cid = rpc("save_contest", {"p_id": None, "p_title": "zz-test recette concours", "p_description": "Concours de recette, jamais publié.", "p_theme": "", "p_rules": "",
                               "p_city": "En ligne", "p_reg_close": "2027-01-01T00:00:00Z", "p_submit_close": "2027-01-02T00:00:00Z", "p_starts": None, "p_ends": None,
                               "p_prize": 0, "p_places": 2, "p_publish": False}, tok["dept"])
check("département : concours enregistré en brouillon", s == 200, cid)
s, r = call("GET", f"/rest/v1/contests?select=id&id=eq.{cid}")
check("visiteur : brouillon invisible", s == 200 and r == [], r)
s, r = rpc("register_contest_team", {"p_contest": cid, "p_name": "Équipe test", "p_theme": "", "p_solo": True, "p_rules": True}, tok["vendeur"])
check("étudiant : inscription refusée à un brouillon", s >= 400, r)
s, r = rpc("set_contest_status", {"p_contest": cid, "p_status": "cancelled"}, tok["dept"])
check("département : concours de recette annulé", s == 200, r)
s, r = rpc("save_contest", {"p_id": None, "p_title": "pirate", "p_description": "x" * 40, "p_theme": "", "p_rules": "", "p_city": "Douala", "p_reg_close": "2027-01-01T00:00:00Z",
                             "p_submit_close": "2027-01-02T00:00:00Z", "p_starts": None, "p_ends": None, "p_prize": 0, "p_places": 2, "p_publish": True}, tok["vendeur"])
check("étudiant : publication de concours refusée", s >= 400, r)

# --- parrainage : code du vendeur, saisi par le client (en attente)
s, code = rpc("my_referral_code", {}, tok["vendeur"])
check("parrainage : code personnel", s == 200 and isinstance(code, str) and len(code) == 8, code)
s, r = rpc("claim_referral", {"p_code": code}, tok["client"])
check("parrainage : filleul enregistré (en attente)", s == 200 and r == "pending", r)
s, r = rpc("my_referral_summary", {}, tok["vendeur"])
check("parrainage : synthèse du parrain (aucun gain sans commande payée)", s == 200 and r.get("available") == 0 and r.get("waiting") == 0, r)
s, r = rpc("claim_referral", {"p_code": code}, tok["admin"])
check("parrainage : personnel exclu", s >= 400, r)

# --- livraison : carnet d'adresses
s, aid = rpc("save_address", {"p_id": None, "p_recipient": "Recette Client", "p_phone": "+237690000000", "p_city": "Douala", "p_district": "Ndokoti", "p_line": "Rue de test", "p_landmark": ""}, tok["client"])
check("adresse enregistrée", s == 200, aid)
s, r = call("GET", "/rest/v1/addresses?select=id", tok=tok["vendeur"])
check("adresse invisible aux autres comptes", s == 200 and r == [], r)
s, r = rpc("delete_address", {"p_id": aid}, tok["client"])
check("adresse supprimée", s == 200, r)
s, r = rpc("set_home_delivery", {"p_enabled": True, "p_city": "Douala", "p_fee": 5000}, tok["dept"])
check("département : ne peut pas activer la livraison à domicile", s >= 400, r)

# --- notifications : consentement puis retrait
s, r = rpc("set_notification_preference", {"p_channel": "sms", "p_kind": "order", "p_enabled": True}, tok["client"])
check("notifications : consentement SMS enregistré", s == 200, r)
s, r = rpc("set_notification_preference", {"p_channel": "sms", "p_kind": "order", "p_enabled": False}, tok["client"])
check("notifications : consentement retiré", s == 200, r)

# --- reels et défis : image de test, validation, puis masquage et suppression du média
png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=")
path = f"{uid['vendeur']}/recette-{int(time.time())}.png"
s, r = call("POST", f"/storage/v1/object/post-media/{path}", tok=tok["vendeur"], raw=png, ctype="image/png")
check("reels : média déposé dans son dossier", s == 200, r)
s, r = call("POST", f"/storage/v1/object/post-media/{uid['client']}/intrusion.png", tok=tok["vendeur"], raw=png, ctype="image/png")
check("reels : dépôt dans le dossier d'autrui refusé", s >= 400, s)
s, p = rpc("create_post", {"p_media_path": path, "p_media_kind": "image", "p_caption": "Recette #test", "p_tags": ["test"], "p_listing": None}, tok["vendeur"])
post = p.get("id") if isinstance(p, dict) else None
check("reels : publication en attente (compte non certifié)", s == 200 and p.get("status") == "pending", p)
s, r = rpc("create_post", {"p_media_path": path, "p_media_kind": "image", "p_caption": "x", "p_tags": [], "p_listing": None}, tok["client"])
check("reels : un client ne publie pas", s >= 400, r)
s, r = rpc("moderate_post", {"p_post": post, "p_publish": True, "p_note": None}, tok["dept"])
check("reels : validation par le département", s == 200 and r == "published", r)
s, r = rpc("reels_feed", {"p_limit": 5})
check("reels : visible dans le fil public", s == 200 and any(x["id"] == post for x in r), len(r) if isinstance(r, list) else r)
s, r = rpc("toggle_post_like", {"p_post": post}, tok["client"])
check("reels : « j'aime » du client", s == 200 and r is True, r)
s, r = rpc("moderate_post", {"p_post": post, "p_publish": False, "p_note": "Fin de recette"}, tok["dept"])
check("reels : publication de recette masquée", s == 200 and r == "hidden", r)
s, r = call("DELETE", f"/storage/v1/object/post-media/{path}", tok=tok["vendeur"])
check("reels : média de recette supprimé", s == 200, r)
s, r = rpc("daily_checkin", {}, tok["vendeur"])
check("défis : présence du jour", s == 200 and r >= 1, r)
s, r = rpc("claim_challenge", {"p_code": "posts3"}, tok["vendeur"])
check("défis : récompense refusée tant que le défi n'est pas atteint", s >= 400, r)

for role in tok:
    if tok[role]:
        call("POST", "/auth/v1/logout?scope=global", tok=tok[role])
print(f"\n{sum(res)}/{len(res)}")
out.write(f"\n{sum(res)}/{len(res)}\n")

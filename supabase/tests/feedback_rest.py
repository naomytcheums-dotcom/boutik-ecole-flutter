"""Tests REST des avis, réclamations et signalements (base réelle, comptes jetables zz-test-*).
Phase 1 : A (vendeur), B (acheteur), C (tiers), annonce de A -> un valideur approuve (SQL)
Phase 2 : B commande -> la commande est marquée payée (SQL, simule le webhook)
Phase 3 : avis, réclamations, signalements et permissions."""
import json, os, sys, urllib.request, urllib.error, uuid

U = "https://zxqcnmgwhtbxkdpjqtlr.supabase.co"
K = "sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01"
STATE = os.environ.get("STATE", "fb_state.json")
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
    print("OK    " if cond else "ECHEC ", name, "|", str(detail)[:130])


def mk(tag, name, role):
    email = f"zz-test-{tag}-{uuid.uuid4().hex[:8]}@example.com"
    s, d = call("/auth/v1/signup", {"email": email, "password": uuid.uuid4().hex + "Aa1!"})
    uid, tok = d["user"]["id"], d["access_token"]
    call("/rest/v1/profiles", {"id": uid, "name": name, "email": email, "role": role}, tok)
    return {"id": uid, "tok": tok, "email": email, "session": d}


def phase1():
    A, B, C = mk("fvend", "Alice Vendeuse", "student"), mk("fach", "Bruno Acheteur", "client"), mk("ftiers", "Chloé Tierce", "client")
    title = "zz-test-avis-" + uuid.uuid4().hex[:6]
    s, d = call("/rest/v1/listings", {"title": title, "department": "T", "category": "Art", "price": 10000, "stock": 10, "status": "pending"}, A["tok"])
    check("A crée une annonce", s in (200, 201), d)
    json.dump({"A": A, "B": B, "C": C, "title": title}, open(STATE, "w"))


def phase2():
    S = json.load(open(STATE)); B, title = S["B"], S["title"]
    s, o = call("/rest/v1/rpc/create_order", {"p_items": [{"title": title, "qty": 1}], "p_home": False, "p_method": "Mobile Money"}, B["tok"])
    check("B commande", s == 200, o)
    S["order"] = o["number"]
    json.dump(S, open(STATE, "w"))


def phase3():
    S = json.load(open(STATE)); A, B, C, title, num = S["A"], S["B"], S["C"], S["title"], S["order"]
    rv = lambda tok, **kw: call("/rest/v1/rpc/submit_review", {"p_order": num, "p_title": title, "p_rating": 5, "p_comment": "Très bien", **kw}, tok)
    s, d = rv(B["tok"])
    check("avis refusé tant que le vendeur n'a pas préparé la commande", s >= 400 and "préparé" in str(d), str(d)[:90])
    call("/rest/v1/rpc/set_seller_order_status", {"p_order": num, "p_status": 3}, A["tok"])
    s, d = rv(C["tok"])
    check("un tiers ne peut pas évaluer la commande d'un autre", s >= 400 and "introuvable" in str(d).lower(), str(d)[:90])
    s, d = rv(B["tok"], p_rating=9)
    check("note hors 1-5 refusée", s >= 400, str(d)[:90])
    s, d = rv(A["tok"])
    check("le vendeur ne peut pas évaluer sa propre vente", s >= 400, str(d)[:90])
    s, d = rv(B["tok"])
    check("B dépose son avis vérifié (commande payée, article prêt)", s == 200, d)
    s, d = rv(B["tok"])
    check("un seul avis par article", s >= 400 and "déjà" in str(d), str(d)[:90])
    s, d = call("/rest/v1/reviews?select=rating,comment", None, None, "GET")
    check("les avis sont publics (lecture anonyme)", s == 200 and d and d[0]["rating"] == 5, d)
    s, d = call("/rest/v1/reviews", {"order_id": str(uuid.uuid4()), "listing_id": str(uuid.uuid4()), "reviewer_id": C["id"], "rating": 5}, C["tok"])
    check("aucune écriture directe d'avis (avis fictif impossible)", s >= 400, f"{s}")
    s, d = call("/rest/v1/rpc/listing_rating", {"p_title": title})
    check("note moyenne publique", d and d[0]["average"] == 5.0 and d[0]["total"] == 1, d)
    s, d = call("/rest/v1/notifications?select=title&kind=eq.review", None, A["tok"], "GET")
    check("le vendeur est notifié d'un nouvel avis", [x["title"] for x in d] == ["Nouvel avis"], d)

    cl = lambda tok, **kw: call("/rest/v1/rpc/submit_claim", {"p_order": num, "p_reason": "damaged", "p_details": "Article endommagé à la réception", **kw}, tok)
    s, d = cl(C["tok"])
    check("un tiers ne peut pas déposer de réclamation sur cette commande", s >= 400, str(d)[:80])
    s, d = cl(B["tok"], p_details="court")
    check("description trop courte refusée", s >= 400, str(d)[:80])
    s, d = cl(B["tok"], p_reason="autre")
    check("motif invalide refusé", s >= 400, str(d)[:80])
    s, cid = cl(B["tok"])
    check("B dépose une réclamation", s == 200 and isinstance(cid, str), cid)
    s, d = cl(B["tok"])
    check("une seule réclamation ouverte par commande", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/claims?select=id,status", None, A["tok"], "GET")
    check("le vendeur concerné voit la réclamation", len(d) == 1 and d[0]["status"] == "open", d)
    s, d = call("/rest/v1/claims?select=id", None, C["tok"], "GET")
    check("un tiers ne voit aucune réclamation", d == [], d)
    s, d = call("/rest/v1/rpc/answer_claim", {"p_claim": cid, "p_message": "intrus"}, C["tok"])
    check("un tiers ne peut pas répondre", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/rpc/answer_claim", {"p_claim": cid, "p_message": "Nous vous remboursons ou échangeons l'article."}, A["tok"])
    check("le vendeur répond", s == 200 and d == "answered", d)
    s, d = call("/rest/v1/claims?select=status,answer", None, B["tok"], "GET")
    check("B voit la réponse et le statut « answered »", d[0]["status"] == "answered" and "échangeons" in d[0]["answer"], d)
    s, d = call("/rest/v1/notifications?select=title&kind=eq.claim", None, B["tok"], "GET")
    check("B est notifié de la réponse", [x["title"] for x in d] == ["Réponse à votre réclamation"], d)
    s, d = call("/rest/v1/notifications?select=title&kind=eq.claim", None, A["tok"], "GET")
    check("le vendeur a été notifié de la réclamation", [x["title"] for x in d] == ["Réclamation reçue"], d)
    s, d = call(f"/rest/v1/claims?id=eq.{cid}", {"status": "closed", "answer": "falsifié"}, B["tok"], "PATCH")
    check("aucune modification directe d'une réclamation", s >= 400 or d == [] or d is None, f"{s}")

    rp = lambda tok, **kw: call("/rest/v1/rpc/report_listing", {"p_title": title, "p_reason": "fraud", "p_details": "Photos copiées", **kw}, tok)
    s, d = rp(A["tok"])
    check("le vendeur ne peut pas signaler sa propre annonce", s >= 400, str(d)[:80])
    s, d = rp(C["tok"], p_reason="insulte")
    check("motif de signalement invalide refusé", s >= 400, str(d)[:80])
    s, d = rp(C["tok"])
    check("C signale l'annonce", s == 200, d)
    s, d = rp(C["tok"])
    check("un seul signalement par personne et par annonce", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/listing_reports?select=reason", None, C["tok"], "GET")
    check("C voit son propre signalement", len(d) == 1, d)
    s, d = call("/rest/v1/listing_reports?select=reason", None, B["tok"], "GET")
    check("B ne voit pas le signalement de C", d == [], d)
    s, d = call("/rest/v1/listing_reports?select=reason", None, A["tok"], "GET")
    check("le vendeur signalé ne voit pas qui l'a signalé", d == [], d)
    print(f"\n{sum(res)}/{len(res)}")


if __name__ == "__main__":
    {"1": phase1, "2": phase2, "3": phase3}[sys.argv[1]]()

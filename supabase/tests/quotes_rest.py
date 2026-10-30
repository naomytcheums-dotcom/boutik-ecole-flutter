"""Tests REST des services et devis (base réelle, comptes jetables zz-test-*).
Phase 1 : A (prestataire), B (demandeur), C (tiers), service de A (catégorie « Services ») -> un valideur l'approuve (SQL)
Phase 2 : demande, réponse, décision, annulation et permissions."""
import json, os, sys, urllib.request, urllib.error, uuid

U = os.environ.get("BE_URL", "https://zxqcnmgwhtbxkdpjqtlr.supabase.co")
K = os.environ.get("BE_KEY", "sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01")
STATE = os.environ.get("STATE", "qt_state.json")
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
    pw = "Zz-test-" + uuid.uuid4().hex[:8] + "!"
    s, d = call("/auth/v1/signup", {"email": email, "password": pw})
    uid, tok = d["user"]["id"], d["access_token"]
    call("/rest/v1/profiles", {"id": uid, "name": name, "email": email, "role": role}, tok)
    return {"id": uid, "tok": tok, "email": email, "password": pw}


def phase1():
    A, B, C = mk("qprest", "Alice Prestataire", "student"), mk("qdem", "Bruno Demandeur", "client"), mk("qtiers", "Chloé Tierce", "client")
    title = "zz-test-service-" + uuid.uuid4().hex[:6]
    s, d = call("/rest/v1/listings", {"title": title, "department": "Génie informatique", "category": "Services", "price": 30000, "stock": 999, "status": "pending"}, A["tok"])
    check("A publie un service (catégorie Services)", s in (200, 201), d)
    json.dump({"A": A, "B": B, "C": C, "title": title}, open(STATE, "w"))


def phase2():
    S = json.load(open(STATE)); A, B, C, title = S["A"], S["B"], S["C"], S["title"]
    rq = lambda tok, **kw: call("/rest/v1/rpc/request_quote", {"p_service": title, "p_brief": "Site vitrine de 5 pages avec formulaire", "p_budget": 80000, "p_deadline": "15 déc. 2026", **kw}, tok)
    s, d = call("/rest/v1/rpc/request_quote", {"p_service": title, "p_brief": "x" * 20, "p_budget": 1, "p_deadline": ""})
    check("visiteur : demande de devis refusée", s >= 400, f"{s}")
    s, d = rq(A["tok"])
    check("le prestataire ne peut pas demander un devis à lui-même", s >= 400, str(d)[:80])
    s, d = rq(B["tok"], p_brief="court")
    check("besoin trop court refusé", s >= 400, str(d)[:80])
    s, d = rq(B["tok"], p_service="Service inexistant")
    check("service inexistant refusé", s >= 400, str(d)[:80])
    s, qid = rq(B["tok"])
    check("B demande un devis", s == 200 and isinstance(qid, str), qid)
    s, d = rq(B["tok"])
    check("une seule demande en cours par service", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/quote_requests?select=id,status", None, A["tok"], "GET")
    check("le prestataire voit la demande", len(d) == 1 and d[0]["status"] == "requested", d)
    s, d = call("/rest/v1/quote_requests?select=id", None, C["tok"], "GET")
    check("un tiers ne voit aucune demande", d == [], d)
    s, d = call("/rest/v1/quote_requests?select=id", None, None, "GET")
    check("le public ne voit aucune demande (accès refusé)", s >= 400 or d == [], d)
    s, d = call("/rest/v1/notifications?select=title&kind=eq.quote", None, A["tok"], "GET")
    check("le prestataire est notifié", [x["title"] for x in d] == ["Nouvelle demande de devis"], d)
    s, d = call("/rest/v1/rpc/answer_quote", {"p_id": qid, "p_amount": 70000, "p_delay_days": 10, "p_message": "Possible"}, C["tok"])
    check("un tiers ne peut pas répondre", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/rpc/answer_quote", {"p_id": qid, "p_amount": 70000, "p_delay_days": 10, "p_message": "Possible"}, B["tok"])
    check("le demandeur ne peut pas répondre à sa propre demande", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/rpc/answer_quote", {"p_id": qid, "p_amount": 0, "p_delay_days": 10, "p_message": ""}, A["tok"])
    check("montant nul refusé", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/rpc/answer_quote", {"p_id": qid, "p_amount": 70000, "p_delay_days": 0, "p_message": ""}, A["tok"])
    check("délai nul refusé", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/rpc/decide_quote", {"p_id": qid, "p_accept": True}, B["tok"])
    check("on ne peut pas accepter avant d'avoir reçu un devis", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/rpc/answer_quote", {"p_id": qid, "p_amount": 70000, "p_delay_days": 10, "p_message": "Possible sous 10 jours"}, A["tok"])
    check("le prestataire envoie son devis", s == 200 and d == "quoted", d)
    s, d = call("/rest/v1/quote_requests?select=status,quote_amount,quote_delay_days", None, B["tok"], "GET")
    check("B voit le devis (70 000 FCFA, 10 jours)", d[0]["status"] == "quoted" and d[0]["quote_amount"] == 70000 and d[0]["quote_delay_days"] == 10, d)
    s, d = call("/rest/v1/notifications?select=title&kind=eq.quote", None, B["tok"], "GET")
    check("B est notifié du devis", [x["title"] for x in d] == ["Devis reçu"], d)
    s, d = call("/rest/v1/rpc/decide_quote", {"p_id": qid, "p_accept": True}, C["tok"])
    check("un tiers ne peut pas accepter", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/rpc/decide_quote", {"p_id": qid, "p_accept": True}, A["tok"])
    check("le prestataire ne peut pas accepter à la place du demandeur", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/rpc/decide_quote", {"p_id": qid, "p_accept": True}, B["tok"])
    check("B accepte le devis", s == 200 and d == "accepted", d)
    s, d = call("/rest/v1/rpc/answer_quote", {"p_id": qid, "p_amount": 1, "p_delay_days": 1, "p_message": ""}, A["tok"])
    check("un devis accepté ne peut plus être modifié", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/rpc/cancel_quote", {"p_id": qid}, B["tok"])
    check("une demande acceptée ne peut plus être annulée", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/notifications?select=title&kind=eq.quote", None, A["tok"], "GET")
    check("le prestataire est notifié de l'acceptation", "Devis accepté" in [x["title"] for x in d], d)
    s, d = call(f"/rest/v1/quote_requests?id=eq.{qid}", {"quote_amount": 1}, B["tok"], "PATCH")
    check("aucune modification directe d'un devis", s >= 400 or not d, f"{s}")
    s, d = call("/rest/v1/quote_requests", {"listing_id": str(uuid.uuid4()), "requester_id": B["id"], "provider_id": A["id"], "brief": "x" * 20}, B["tok"])
    check("aucune création directe de demande", s >= 400, f"{s}")
    # nouvelle demande : annulation et refus
    s, q2 = rq(C["tok"])
    check("C demande un devis", s == 200, q2)
    s, d = call("/rest/v1/rpc/cancel_quote", {"p_id": q2}, B["tok"])
    check("B ne peut pas annuler la demande de C", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/rpc/cancel_quote", {"p_id": q2}, C["tok"])
    check("C annule sa demande", s == 200 and d == "cancelled", d)
    s, q3 = rq(C["tok"])
    call("/rest/v1/rpc/answer_quote", {"p_id": q3, "p_amount": 99000, "p_delay_days": 20, "p_message": ""}, A["tok"])
    s, d = call("/rest/v1/rpc/decide_quote", {"p_id": q3, "p_accept": False}, C["tok"])
    check("C refuse le devis", s == 200 and d == "declined", d)
    print(f"\n{sum(res)}/{len(res)}")


if __name__ == "__main__":
    {"1": phase1, "2": phase2}[sys.argv[1]]()

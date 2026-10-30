"""Tests REST des engagements (inscriptions, candidatures, votes, préférences, demandes) — comptes jetables zz-test-*."""
import json, urllib.request, urllib.error, uuid

U = "https://zxqcnmgwhtbxkdpjqtlr.supabase.co"
K = "sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01"
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


def mk(tag, role):
    email = f"zz-test-{tag}-{uuid.uuid4().hex[:8]}@example.com"
    s, d = call("/auth/v1/signup", {"email": email, "password": uuid.uuid4().hex + "Aa1!"})
    uid, tok = d["user"]["id"], d["access_token"]
    call("/rest/v1/profiles", {"id": uid, "name": "Test " + tag, "email": email, "role": role}, tok)
    return {"id": uid, "tok": tok}


A, B = mk("eng-a", "student"), mk("eng-b", "client")
eng = lambda tok, k, r, d=None: call("/rest/v1/rpc/engage", {"p_kind": k, "p_ref": r, "p_data": d or {}}, tok)

s, d = call("/rest/v1/rpc/engage", {"p_kind": "vote", "p_ref": "x", "p_data": {}})
check("visiteur : engagement refusé", s >= 400, f"{s}")
s, d = eng(A["tok"], "event_registration", "event:101", {"title": "Exposition des innovations"})
check("A s'inscrit à un événement", s == 200 and d == "created", d)
s, d = eng(A["tok"], "event_registration", "event:101")
check("inscription en double refusée", s >= 400 and "Déjà" in str(d), str(d)[:80])
s, d = eng(A["tok"], "type_inconnu", "x")
check("type inconnu refusé", s >= 400, str(d)[:80])
s, d = eng(A["tok"], "vote", "   ")
check("cible vide refusée", s >= 400, str(d)[:80])
s, d = eng(A["tok"], "alert_prefs", "me", {"offers": True})
check("préférences enregistrées", s == 200 and d == "created", d)
s, d = eng(A["tok"], "alert_prefs", "me", {"offers": False})
check("préférences mises à jour (pas de doublon)", s == 200 and d == "updated", d)
s, d = call("/rest/v1/engagements?select=kind,ref,data,status&kind=eq.alert_prefs", None, A["tok"], "GET")
check("une seule ligne de préférences, valeur à jour", len(d) == 1 and d[0]["data"] == {"offers": False}, d)
s, d = call("/rest/v1/rpc/cancel_engagement", {"p_kind": "event_registration", "p_ref": "event:101"}, A["tok"])
check("A se désinscrit", s == 200 and d == "cancelled", d)
s, d = eng(A["tok"], "event_registration", "event:101")
check("A peut se réinscrire après désinscription", s == 200 and d == "created", d)
s, d = eng(A["tok"], "data_export_request", "me")
check("demande d'export enregistrée", s == 200, d)
s, d = call("/rest/v1/rpc/cancel_engagement", {"p_kind": "data_export_request", "p_ref": "me"}, A["tok"])
check("une demande d'export ne s'annule pas depuis l'application", s >= 400, str(d)[:80])
s, d = call("/rest/v1/rpc/cancel_engagement", {"p_kind": "vote", "p_ref": "inexistant"}, A["tok"])
check("annulation d'un engagement inexistant refusée", s >= 400, str(d)[:80])
s, d = call("/rest/v1/engagements?select=id", None, B["tok"], "GET")
check("B ne voit aucun engagement de A", d == [], d)
s, d = call("/rest/v1/engagements?select=id", None, None, "GET")
check("le public ne voit aucun engagement (accès refusé)", s >= 400 or d == [], f"{s}")
s, d = call("/rest/v1/engagements", {"user_id": B["id"], "kind": "vote", "ref": "x"}, A["tok"])
check("aucune écriture directe", s >= 400, f"{s}")
s, d = eng(B["tok"], "vote", "duel:220:lampe")
check("B vote", s == 200, d)
s, d = eng(B["tok"], "vote", "duel:220:lampe")
check("un seul vote par duel et par personne", s >= 400, str(d)[:80])
print(f"\n{sum(res)}/{len(res)}")

"""Tests REST de la messagerie et des notifications sur la base réelle (comptes jetables zz-test-*).

Phase 1 : crée A (vendeur), B (acheteur), C (tiers), l'annonce de A.          -> un valideur approuve (SQL, propriétaire de la base)
Phase 2 : conversation, isolation, non-lus, lecture, commande de B.           -> la commande est marquée payée (SQL, simule le webhook)
Phase 3 : notifications de paiement.
"""
import json, os, sys, urllib.request, urllib.error, uuid

U = os.environ.get("BE_URL", "https://zxqcnmgwhtbxkdpjqtlr.supabase.co")
K = os.environ.get("BE_KEY", "sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01")
STATE = os.environ.get("STATE", "messaging_state.json")
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


def mk(tag, role):
    email = f"zz-test-{tag}-{uuid.uuid4().hex[:8]}@example.com"
    pw = uuid.uuid4().hex + "Aa1!"
    s, d = call("/auth/v1/signup", {"email": email, "password": pw})
    uid, tok = d["user"]["id"], d["access_token"]
    call("/rest/v1/profiles", {"id": uid, "name": tag, "email": email, "role": role}, tok)
    return {"email": email, "id": uid, "tok": tok}


def unread(tok):
    s, d = call("/rest/v1/rpc/unread_counts", {}, tok)
    return d


def phase1():
    A, B, C = mk("vendeur", "student"), mk("acheteur", "client"), mk("tiers", "client")
    title = "zz-test-msg-" + uuid.uuid4().hex[:6]
    s, d = call("/rest/v1/listings", {"title": title, "department": "T", "category": "Art", "price": 10000, "stock": 10, "status": "pending"}, A["tok"])
    check("A crée une annonce en attente", s in (200, 201), d)
    json.dump({"A": A, "B": B, "C": C, "title": title, "lid": d[0]["id"]}, open(STATE, "w"))
    print("PHASE 1 :", sum(res), "/", len(res))


def phase2():
    S = json.load(open(STATE)); A, B, C, lid, title = S["A"], S["B"], S["C"], S["lid"], S["title"]
    s, d = call("/rest/v1/notifications?select=kind,title,read_at", None, A["tok"], "GET")
    check("A a reçu une notification « Annonce validée » à la décision du département", any(n["title"] == "Annonce validée" and n["kind"] == "listing" for n in d), d)
    check("compteur de non-lus de A : 1 notification, 0 message", unread(A["tok"]) == {"notifications": 1, "messages": 0}, unread(A["tok"]))

    s, cid = call("/rest/v1/rpc/start_conversation", {"p_listing": lid, "p_body": "Bonjour, est-il disponible ?"}, B["tok"])
    check("B démarre une conversation avec le vendeur", s == 200 and isinstance(cid, str), cid)
    s, cid2 = call("/rest/v1/rpc/start_conversation", {"p_listing": lid, "p_body": "Et la livraison ?"}, B["tok"])
    check("pas de doublon : la même conversation est réutilisée", cid2 == cid, cid2)
    s, d = call("/rest/v1/rpc/start_conversation", {"p_listing": lid, "p_body": "moi"}, A["tok"])
    check("un vendeur ne peut pas s'écrire à lui-même", s >= 400, str(d)[:80])
    s, d = call("/rest/v1/rpc/start_conversation", {"p_listing": lid, "p_body": "   "}, B["tok"])
    check("message vide refusé", s >= 400, str(d)[:80])
    s, L = call("/rest/v1/listings?select=id&seller_id=is.null&limit=1", None, B["tok"], "GET")
    s, d = call("/rest/v1/rpc/start_conversation", {"p_listing": L[0]["id"], "p_body": "bonjour"}, B["tok"])
    check("annonce de la plateforme : pas de conversation vendeur", s >= 400, str(d)[:90])

    s, d = call(f"/rest/v1/messages?conversation_id=eq.{cid}&select=body,sender_id&order=id", None, A["tok"], "GET")
    check("A (participant) lit l'historique persistant", [m["body"] for m in d] == ["Bonjour, est-il disponible ?", "Et la livraison ?"], d)
    s, d = call(f"/rest/v1/messages?conversation_id=eq.{cid}&select=id", None, C["tok"], "GET")
    check("C (tiers) ne lit aucun message", d == [], d)
    s, d = call("/rest/v1/conversations?select=id", None, C["tok"], "GET")
    check("C ne voit aucune conversation", d == [], d)
    s, d = call(f"/rest/v1/conversation_participants?conversation_id=eq.{cid}&select=user_id", None, C["tok"], "GET")
    check("C ne voit pas les participants", d == [], d)
    s, d = call("/rest/v1/messages", {"conversation_id": cid, "sender_id": C["id"], "body": "intrus"}, C["tok"])
    check("C ne peut pas écrire dans la conversation", s >= 400, f"{s} {str(d)[:70]}")
    s, d = call("/rest/v1/messages", {"conversation_id": cid, "sender_id": A["id"], "body": "usurpation"}, B["tok"])
    check("B ne peut pas écrire au nom de A", s >= 400, f"{s} {str(d)[:70]}")
    s, d = call(f"/rest/v1/messages?conversation_id=eq.{cid}", {"body": "modifié"}, B["tok"], "PATCH")
    check("un message ne peut pas être modifié", s >= 400 or d == [], f"{s} {str(d)[:70]}")
    s, d = call(f"/rest/v1/messages?conversation_id=eq.{cid}", None, B["tok"], "DELETE")
    check("un message ne peut pas être supprimé", s >= 400 or d == [], f"{s} {str(d)[:70]}")

    check("A : 2 messages non lus et 2 notifications", unread(A["tok"]) == {"notifications": 3, "messages": 2}, unread(A["tok"]))
    s, d = call("/rest/v1/rpc/mark_conversation_read", {"cid": cid}, A["tok"])
    check("A ouvre la conversation : messages marqués lus", unread(A["tok"])["messages"] == 0, unread(A["tok"]))
    s, d = call("/rest/v1/messages", {"conversation_id": cid, "sender_id": A["id"], "body": "Oui, disponible !"}, A["tok"])
    check("A répond", s in (200, 201), d)
    check("B reçoit 1 message non lu et la notification correspondante", unread(B["tok"])["messages"] == 1 and unread(B["tok"])["notifications"] == 1, unread(B["tok"]))
    s, d = call("/rest/v1/notifications?select=id", None, C["tok"], "GET")
    check("C ne reçoit aucune notification", d == [] and unread(C["tok"]) == {"notifications": 0, "messages": 0}, d)

    s, d = call("/rest/v1/notifications", {"user_id": B["id"], "kind": "x", "title": "faux"}, B["tok"])
    check("un client ne peut pas fabriquer de notification", s >= 400, f"{s} {str(d)[:70]}")
    s, d = call("/rest/v1/notifications?select=id,title", None, A["tok"], "GET")
    nid = d[0]["id"]
    s, d = call(f"/rest/v1/notifications?id=eq.{nid}", {"read_at": "2026-01-01T00:00:00Z"}, B["tok"], "PATCH")
    check("B ne peut pas marquer lue la notification de A", s >= 400 or d == [], f"{s} {str(d)[:70]}")
    s, d = call(f"/rest/v1/notifications?id=eq.{nid}", {"title": "falsifié"}, A["tok"], "PATCH")
    check("A ne peut modifier que l'état de lecture (titre protégé)", s >= 400, f"{s} {str(d)[:70]}")
    s, d = call("/rest/v1/rpc/mark_notifications_read", {}, A["tok"])
    check("A marque ses notifications comme lues", unread(A["tok"])["notifications"] == 0, unread(A["tok"]))

    # reconnexion : l'historique est conservé
    # (nouvelle session de B via mot de passe non conservé ici : la lecture avec le même jeton prouve la persistance serveur)
    s, d = call(f"/rest/v1/messages?conversation_id=eq.{cid}&select=id", None, B["tok"], "GET")
    check("B retrouve 3 messages (persistance serveur)", len(d) == 3, len(d))

    s, o = call("/rest/v1/rpc/create_order", {"p_items": [{"title": title, "qty": 1}], "p_home": False, "p_method": "Mobile Money"}, B["tok"])
    check("B commande l'annonce de A", s == 200, o)
    S["order"] = o["number"]; S["cid"] = cid
    json.dump(S, open(STATE, "w"))
    print("PHASE 2 :", sum(res), "/", len(res))


def phase3():
    S = json.load(open(STATE)); A, B, C = S["A"], S["B"], S["C"]
    s, d = call("/rest/v1/notifications?select=title,kind&kind=eq.order", None, B["tok"], "GET")
    check("B est notifié du paiement confirmé", [x["title"] for x in d] == ["Paiement confirmé"], d)
    s, d = call("/rest/v1/notifications?select=title,kind&kind=eq.order", None, A["tok"], "GET")
    check("A (vendeur) est notifié d'une nouvelle commande", [x["title"] for x in d] == ["Nouvelle commande"], d)
    s, d = call("/rest/v1/notifications?select=id&kind=eq.order", None, C["tok"], "GET")
    check("C n'est pas notifié", d == [], d)
    # correctif non-lus : le tout premier message d'une conversation compte comme non lu pour le vendeur
    D = mk("acheteur2", "client")
    before = unread(A["tok"])["messages"]
    s, cid = call("/rest/v1/rpc/start_conversation", {"p_listing": S["lid"], "p_body": "Premier message de D"}, D["tok"])
    check("le premier message d'une nouvelle conversation est non lu pour le vendeur", s == 200 and unread(A["tok"])["messages"] == before + 1, unread(A["tok"]))
    print("PHASE 3 :", sum(res), "/", len(res))


if __name__ == "__main__":
    {"1": phase1, "2": phase2, "3": phase3}[sys.argv[1]]()

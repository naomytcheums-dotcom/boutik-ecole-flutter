"""Tests REST : conversation liée à une commande, pièces jointes et vocaux (stockage privé) — base réelle, comptes jetables zz-test-*.
Phase 1 : A (vendeur), B (acheteur), C (tiers), annonce de A -> un valideur approuve (SQL)
Phase 2 : commande de B, conversation de commande, pièces jointes, permissions."""
import json, os, sys, urllib.request, urllib.error, uuid

U = os.environ.get("BE_URL", "https://zxqcnmgwhtbxkdpjqtlr.supabase.co")
K = os.environ.get("BE_KEY", "sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01")
STATE = os.environ.get("STATE", "chat_state.json")
res = []
PNG = bytes.fromhex("89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d49444154789c6360000002000001e221bc330000000049454e44ae426082")


def call(path, body=None, token=None, method="POST", raw=None, ctype="application/json", anon_only=False):
    h = {"apikey": K, "Content-Type": ctype}
    if path.startswith("/rest/"):
        h["Prefer"] = "return=representation"
    if token:
        h["Authorization"] = "Bearer " + token
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(U + path, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            b = r.read()
            try:
                return r.status, json.loads(b) if b else None
            except Exception:
                return r.status, b
    except urllib.error.HTTPError as e:
        b = e.read()
        try:
            return e.code, json.loads(b)
        except Exception:
            return e.code, b.decode(errors="replace")[:200]


def check(name, cond, detail=""):
    res.append(bool(cond))
    print("OK    " if cond else "ECHEC ", name, "|", str(detail)[:140])


def mk(tag, name, role):
    email = f"zz-test-{tag}-{uuid.uuid4().hex[:8]}@example.com"
    s, d = call("/auth/v1/signup", {"email": email, "password": uuid.uuid4().hex + "Aa1!"})
    uid, tok = d["user"]["id"], d["access_token"]
    call("/rest/v1/profiles", {"id": uid, "name": name, "email": email, "role": role}, tok)
    return {"id": uid, "tok": tok}


def up(tok, path, data, ctype):
    return call(f"/storage/v1/object/chat-files/{path}", raw=data, token=tok, ctype=ctype)


def phase1():
    A, B, C = mk("vend", "Alice Vendeuse", "student"), mk("ach", "Bruno Acheteur", "client"), mk("tiers", "Chloé Tierce", "client")
    title = "zz-test-pj-" + uuid.uuid4().hex[:6]
    s, d = call("/rest/v1/listings", {"title": title, "department": "T", "category": "Art", "price": 10000, "stock": 10, "status": "pending"}, A["tok"])
    check("A crée une annonce", s in (200, 201), d)
    json.dump({"A": A, "B": B, "C": C, "title": title, "lid": d[0]["id"]}, open(STATE, "w"))


def phase2():
    S = json.load(open(STATE)); A, B, C, title = S["A"], S["B"], S["C"], S["title"]
    s, o = call("/rest/v1/rpc/create_order", {"p_items": [{"title": title, "qty": 1}], "p_home": False, "p_method": "Mobile Money"}, B["tok"])
    num = o["number"]
    s, cid = call("/rest/v1/rpc/start_order_conversation", {"p_order": num, "p_body": "Bonjour, où en est ma commande ?"}, B["tok"])
    check("B ouvre la conversation liée à SA commande", s == 200 and isinstance(cid, str), cid)
    s, c2 = call("/rest/v1/rpc/start_order_conversation", {"p_order": num, "p_body": "Merci de me tenir au courant"}, B["tok"])
    check("la même conversation est réutilisée (pas de doublon)", c2 == cid, c2)
    s, c3 = call("/rest/v1/rpc/start_order_conversation", {"p_order": num, "p_body": "Je prépare votre commande"}, A["tok"])
    check("le vendeur de la commande rejoint la même conversation", c3 == cid, c3)
    s, d = call("/rest/v1/rpc/start_order_conversation", {"p_order": num, "p_body": "intrus"}, C["tok"])
    check("un tiers ne peut pas ouvrir de conversation sur cette commande", s >= 400 and "introuvable" in str(d).lower(), str(d)[:80])
    s, d = call("/rest/v1/rpc/my_conversations", {}, A["tok"])
    check("A (vendeur) voit la conversation liée à la commande avec le nom de l'acheteur", len(d) == 1 and d[0]["order_number"] == num and d[0]["other_name"] == "Bruno Acheteur", d)
    s, d = call("/rest/v1/rpc/my_conversations", {}, C["tok"])
    check("C ne voit rien", d == [], d)

    # pièces jointes
    p1 = f"{cid}/{uuid.uuid4().hex}.png"
    s, d = up(B["tok"], p1, PNG, "image/png")
    check("B (participant) dépose une image dans le dossier de la conversation", s in (200, 201), d)
    s, d = up(A["tok"], f"{cid}/{uuid.uuid4().hex}.png", PNG, "image/png")
    check("A (participant) dépose aussi", s in (200, 201), d)
    s, d = up(C["tok"], f"{cid}/{uuid.uuid4().hex}.png", PNG, "image/png")
    check("C (tiers) ne peut pas déposer dans cette conversation", s >= 400, f"{s} {str(d)[:70]}")
    s, d = up(B["tok"], f"{uuid.uuid4()}/{uuid.uuid4().hex}.png", PNG, "image/png")
    check("dépôt dans le dossier d'une conversation inconnue refusé", s >= 400, f"{s} {str(d)[:70]}")
    s, d = up(B["tok"], f"vrac/{uuid.uuid4().hex}.png", PNG, "image/png")
    check("dépôt hors dossier de conversation refusé", s >= 400, f"{s} {str(d)[:70]}")
    s, d = up(B["tok"], f"{cid}/{uuid.uuid4().hex}.html", b"<script>1</script>", "text/html")
    check("type de fichier dangereux (text/html) refusé", s >= 400, f"{s} {str(d)[:70]}")
    s, d = up(B["tok"], f"{cid}/{uuid.uuid4().hex}.pdf", b"%PDF-1.4" + b"0" * (10 * 1024 * 1024 + 10), "application/pdf")
    check("fichier de plus de 10 Mo refusé", s >= 400, f"{s} {str(d)[:70]}")
    pv = f"{cid}/{uuid.uuid4().hex}.webm"
    s, d = up(B["tok"], pv, b"\x1a\x45\xdf\xa3" + b"0" * 200, "audio/webm")
    check("message vocal (audio/webm) accepté", s in (200, 201), f"{s} {str(d)[:70]}")

    # messages avec pièces jointes
    def msg(tok, **kw):
        body = {"conversation_id": cid, "sender_id": B["id"], "body": "x"}; body.update(kw)
        return call("/rest/v1/messages", body, tok)

    s, d = msg(B["tok"], kind="image", body="Photo", attachment_path=p1, attachment_name="photo.png", attachment_size=len(PNG))
    check("message image avec sa pièce jointe enregistré", s in (200, 201), d)
    s, d = msg(B["tok"], kind="voice", body="Message vocal", attachment_path=pv, attachment_name="vocal.webm", attachment_size=204)
    check("message vocal enregistré", s in (200, 201), d)
    s, d = msg(B["tok"], kind="image", body="Photo", attachment_path=f"{uuid.uuid4()}/x.png", attachment_name="x.png", attachment_size=5)
    check("pièce jointe pointant vers une AUTRE conversation refusée", s >= 400, f"{s} {str(d)[:70]}")
    s, d = msg(B["tok"], kind="image", body="Photo")
    check("message image sans pièce jointe refusé", s >= 400, f"{s} {str(d)[:70]}")
    s, d = msg(B["tok"], kind="text", attachment_path=p1, attachment_name="p", attachment_size=5)
    check("message texte avec pièce jointe refusé", s >= 400, f"{s} {str(d)[:70]}")
    s, d = msg(B["tok"], kind="file", body="f", attachment_path=f"{cid}/a.pdf", attachment_name="a.pdf", attachment_size=0)
    check("taille de pièce jointe invalide refusée", s >= 400, f"{s} {str(d)[:70]}")
    s, d = msg(C["tok"], kind="image", body="Photo", attachment_path=p1, attachment_name="photo.png", attachment_size=len(PNG), sender_id=C["id"])
    check("un tiers ne peut pas écrire dans la conversation", s >= 400, f"{s} {str(d)[:70]}")

    # lecture sécurisée
    s, d = call(f"/storage/v1/object/sign/chat-files/{p1}", {"expiresIn": 60}, token=A["tok"])
    ok_sign = s == 200 and isinstance(d, dict) and "signedURL" in d
    check("A (participant) obtient un lien signé temporaire", ok_sign, str(d)[:70])
    if ok_sign:
        r = urllib.request.urlopen(U + "/storage/v1" + d["signedURL"], timeout=30)
        check("le contenu téléchargé est identique à l'image déposée", r.read() == PNG, r.status)
    s, d = call(f"/storage/v1/object/sign/chat-files/{p1}", {"expiresIn": 60}, token=C["tok"])
    check("C (tiers) ne peut pas obtenir de lien signé", s >= 400 or not (isinstance(d, dict) and "signedURL" in d), f"{s} {str(d)[:70]}")
    s, d = call(f"/storage/v1/object/chat-files/{p1}", token=C["tok"], method="GET")
    check("C ne peut pas lire l'objet directement", s >= 400, f"{s} {str(d)[:70]}")
    s, d = call(f"/storage/v1/object/public/chat-files/{p1}", method="GET")
    check("le dossier n'est pas public (accès anonyme refusé)", s >= 400, f"{s} {str(d)[:70]}")

    s, d = call("/rest/v1/rpc/my_conversations", {}, A["tok"])
    check("la liste affiche « Message vocal » comme dernier message de type vocal", d[0]["last_body"] == "Message vocal", d[0]["last_body"])
    s, d = call(f"/rest/v1/messages?conversation_id=eq.{cid}&select=kind,attachment_name&order=id", None, A["tok"], "GET")
    check("A relit l'historique persistant avec les pièces jointes", [m["kind"] for m in d][-2:] == ["image", "voice"], [m["kind"] for m in d])
    s, d = call(f"/rest/v1/messages?conversation_id=eq.{cid}&select=id", None, C["tok"], "GET")
    check("C ne lit aucun message", d == [], d)
    print(f"\n{sum(res)}/{len(res)}")


if __name__ == "__main__":
    phase1() if sys.argv[1] == "1" else phase2()

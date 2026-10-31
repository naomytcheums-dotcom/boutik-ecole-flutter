"""Tests REST de la migration 20261031b (paramètres, modèles, clés, fichiers, dossier de mission, CV partagé, code de retrait, invitations).
ENVIRONNEMENT ISOLÉ UNIQUEMENT (rôles du personnel attribués par SQL dans le conteneur local).
Usage : BE_URL=http://127.0.0.1:54321 BE_KEY=<publishable locale> python supabase/tests/lots2_rest.py [conteneur_db]
"""
import json, os, subprocess, sys, urllib.error, urllib.request, uuid

U = os.environ.get("BE_URL", "")
K = os.environ.get("BE_KEY", "")
DB = sys.argv[1] if len(sys.argv) > 1 else "supabase_db_boutik_local"
if not U.startswith("http://127.0.0.1") and not U.startswith("http://localhost"):
    sys.exit("Refusé : ce test modifie des rôles par SQL et ne s'exécute que sur une base locale isolée.")
res = []


def call(path, body=None, token=None, method="POST", raw=None, ctype="application/json"):
    h = {"apikey": K, "Content-Type": ctype, "Prefer": "return=representation"}
    if token:
        h["Authorization"] = "Bearer " + token
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(U + path, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            b = r.read()
            try:
                return r.status, (json.loads(b) if b else None)
            except Exception:
                return r.status, b
    except urllib.error.HTTPError as e:
        b = e.read()
        try:
            return e.code, json.loads(b)
        except Exception:
            return e.code, b.decode(errors="replace")


def check(name, cond, detail=""):
    res.append(bool(cond))
    print("OK    " if cond else "ECHEC ", name, "|", str(detail)[:140])


def sql(q):
    r = subprocess.run(["docker", "exec", "-i", DB, "psql", "-U", "postgres", "-t", "-A", "-q"], input=q.encode(), capture_output=True)
    if r.returncode:
        raise SystemExit(r.stderr.decode())
    return r.stdout.decode().strip()


def mk(tag, role, staff=None):
    email = f"zz-test-{tag}-{uuid.uuid4().hex[:8]}@example.com"
    s, d = call("/auth/v1/signup", {"email": email, "password": "Zz-test-" + uuid.uuid4().hex[:8] + "!"})
    uid, tok = d["user"]["id"], d["access_token"]
    call("/rest/v1/profiles", {"id": uid, "name": "Test " + tag, "email": email, "role": role}, tok)
    if staff:
        sql(f"update profiles set role = '{staff}' where id = '{uid}';")
    return {"id": uid, "tok": tok, "email": email}


rpc = lambda fn, body, who=None: call("/rest/v1/rpc/" + fn, body, who["tok"] if who else None)
get = lambda path, who=None: call("/rest/v1/" + path, None, who["tok"] if who else None, "GET")

CL, ST, ST2, DEPT, DIR, ADM, SUP = mk("cli2", "company"), mk("stu3", "student"), mk("stu4", "student"), mk("dep2", "client", "dept"), \
    mk("dir", "client", "direction"), mk("adm", "client", "admin"), mk("sup2", "client", "support")

# ---------------- établissement (118)
inst = {"p_name": "IUT de Douala", "p_acronym": "IUT-D", "p_address": "Bonabéri, Douala", "p_email": "contact@iut-douala.cm",
        "p_phone": "+237 233 00 00 00", "p_primary": "#12253F", "p_accent": "#FBB52B", "p_font": "Sans-serif professionnelle"}
s, d = rpc("save_institution", inst, ST)
check("un étudiant ne modifie pas l'établissement", s >= 400, str(d)[:80])
s, d = rpc("save_institution", {**inst, "p_primary": "bleu"}, DIR)
check("couleur invalide refusée", s >= 400, str(d)[:80])
s, d = rpc("save_institution", {**inst, "p_phone": "+237 233 42 42 42"}, DIR)
check("la direction enregistre l'identité", d == "saved", d)
s, d = get("institution_settings?select=phone,primary_color")
check("identité publique, valeur persistée", d == [{"phone": "+237 233 42 42 42", "primary_color": "#12253F"}], d)

# ---------------- modèles de notifications (265)
s, d = get("notification_templates?select=key", ST)
check("les modèles ne sont pas lisibles par un étudiant", d == [], d)
s, d = rpc("save_notification_template", {"p_key": "order_confirmed", "p_subject": "Commande {{numero}}", "p_body": "Bonjour {{nom}}, c'est confirmé.", "p_channels": ["email", "sms"], "p_active": True}, DEPT)
check("seul l'administrateur modifie un modèle", s >= 400, str(d)[:80])
s, d = rpc("save_notification_template", {"p_key": "order_confirmed", "p_subject": "Commande {{numero}}", "p_body": "Bonjour {{nom}}, c'est confirmé.", "p_channels": ["fax"], "p_active": True}, ADM)
check("canal inconnu refusé", s >= 400, str(d)[:80])
s, d = rpc("save_notification_template", {"p_key": "order_confirmed", "p_subject": "Commande {{numero}}", "p_body": "Bonjour {{nom}}, c'est confirmé.", "p_channels": ["email", "sms"], "p_active": True}, ADM)
check("l'administrateur modifie le modèle", d == "saved", d)
s, d = get("notification_templates?select=body&key=eq.order_confirmed", ADM)
check("modèle persisté", d == [{"body": "Bonjour {{nom}}, c'est confirmé."}], d)

# ---------------- clés d'intégration (280)
s, d = rpc("create_api_key", {"p_label": "Portail entreprises"}, DIR)
check("la direction ne crée pas de clé", s >= 400, str(d)[:80])
s, key = rpc("create_api_key", {"p_label": "Portail entreprises"}, ADM)
check("l'administrateur obtient une clé (affichée une fois)", isinstance(key, str) and key.startswith("be_live_") and len(key) == 56, key[:12] if isinstance(key, str) else key)
s, d = get("api_keys?select=id,prefix,label,revoked_at", ADM)
mine = [x for x in d if x["label"] == "Portail entreprises"]
check("seuls le préfixe et l'empreinte sont stockés", mine and mine[-1]["prefix"] == key[:12], mine[-1:])
s, d = get("api_keys?select=key_hash", ADM)
check("l'empreinte n'est pas lisible par l'API", s >= 400, s)
check("la clé en clair n'existe pas en base", sql(f"select count(*) from api_keys where key_hash = '{key}' or prefix = '{key}';") == "0", "")
s, d = rpc("revoke_api_key", {"p_id": mine[-1]["id"]}, ADM)
check("révocation", d == "revoked", d)
s, d = rpc("revoke_api_key", {"p_id": mine[-1]["id"]}, ADM)
check("double révocation refusée", s >= 400, str(d)[:80])

# ---------------- mission attribuée (préparation) puis dossier (196)
need = {"p_id": None, "p_title": "Identité visuelle Mbella", "p_description": "Logo, charte et déclinaisons pour une marque de parfums.",
        "p_budget_min": 150000, "p_budget_max": 300000, "p_deadline": "", "p_publish": True, "p_kind": "besoin"}
s, mid = rpc("save_mission", need, CL)
s, pid = rpc("propose_on_mission", {"p_mission": mid, "p_amount": 180000, "p_delay_days": 30, "p_message": ""}, ST)
s, d = rpc("send_mission_message", {"p_mission": mid, "p_body": "Bonjour"}, CL)
check("pas de dossier avant attribution", s >= 400, str(d)[:80])
rpc("decide_proposal", {"p_id": pid, "p_accept": True}, CL)
s, d = rpc("send_mission_message", {"p_mission": mid, "p_body": "Voici les trois pistes de logo."}, ST)
check("le prestataire écrit dans le dossier", s == 200, d)
s, d = rpc("send_mission_message", {"p_mission": mid, "p_body": "La piste 2 me plaît."}, CL)
check("le client répond", s == 200, d)
s, d = rpc("send_mission_message", {"p_mission": mid, "p_body": "Intrusion"}, ST2)
check("un tiers n'écrit pas dans le dossier", s >= 400, str(d)[:80])
s, d = get(f"mission_messages?select=body&mission_id=eq.{mid}&order=created_at", ST)
check("messages persistés, visibles des participants", [x["body"] for x in d] == ["Voici les trois pistes de logo.", "La piste 2 me plaît."], d)
s, d = get(f"mission_messages?select=body&mission_id=eq.{mid}", ST2)
check("un tiers ne lit pas le dossier", d == [], d)
s, d = get("notifications?select=title&title=eq.Nouveau%20message%20du%20dossier", CL)
check("le client est notifié du message", len(d) == 1, d)

# ---------------- fichiers (263, 83, 279, 196)
def upload(who, path, body, ctype):
    return call(f"/storage/v1/object/project-files/{path}", None, who["tok"], "POST", raw=body, ctype=ctype)

pdf = b"%PDF-1.4\n%test\n"
p1 = f"{ST['id']}/mission/{uuid.uuid4().hex}-moodboard.pdf"
s, d = upload(ST, p1, pdf, "application/pdf")
check("dépôt PDF dans son dossier", s == 200, d)
s, d = upload(ST, f"{ST2['id']}/mission/x.pdf", pdf, "application/pdf")
check("dépôt dans le dossier d'un autre refusé", s >= 400, s)
s, d = upload(ST, f"{ST['id']}/mission/page.html", b"<script>alert(1)</script>", "text/html")
check("type non autorisé refusé par le stockage", s >= 400, s)
s, fid = rpc("register_file", {"p_scope": "mission", "p_ref": mid, "p_path": p1, "p_name": "moodboard.pdf", "p_mime": "application/pdf", "p_size": len(pdf)}, ST)
check("fichier enregistré dans le dossier de mission", s == 200, fid)
s, d = rpc("register_file", {"p_scope": "mission", "p_ref": mid, "p_path": f"{ST['id']}/mission/absent.pdf", "p_name": "absent.pdf", "p_mime": "application/pdf", "p_size": 10}, ST)
check("fichier non déposé refusé", s >= 400, str(d)[:80])
s, d = rpc("register_file", {"p_scope": "mission", "p_ref": mid, "p_path": p1, "p_name": "virus.exe", "p_mime": "application/pdf", "p_size": len(pdf)}, ST)
check("exécutable refusé", s >= 400, str(d)[:80])
s, d = rpc("register_file", {"p_scope": "media", "p_ref": None, "p_path": p1, "p_name": "x.pdf", "p_mime": "application/pdf", "p_size": len(pdf)}, ST)
check("médiathèque réservée au département", s >= 400, str(d)[:80])
s, d = get(f"files?select=name&ref=eq.{mid}", CL)
check("le client voit le fichier du dossier", d == [{"name": "moodboard.pdf"}], d)
s, d = get(f"files?select=name&ref=eq.{mid}", ST2)
check("un tiers ne voit pas le fichier", d == [], d)
s, d = call(f"/storage/v1/object/project-files/{p1}", None, CL["tok"], "GET")
check("le client télécharge le fichier", s == 200, s)
s, d = call(f"/storage/v1/object/project-files/{p1}", None, ST2["tok"], "GET")
check("un tiers ne télécharge pas le fichier", s >= 400, s)
pm = f"{DEPT['id']}/media/{uuid.uuid4().hex}-lampe.png"
s, d = upload(DEPT, pm, b"\x89PNG\r\n\x1a\n" + b"0" * 64, "image/png")
s, d = rpc("register_file", {"p_scope": "media", "p_ref": None, "p_path": pm, "p_name": "lampe.png", "p_mime": "image/png", "p_size": 6 * 1024 * 1024}, DEPT)
check("image de plus de 5 Mo refusée", s >= 400, str(d)[:80])
s, d = rpc("register_file", {"p_scope": "media", "p_ref": None, "p_path": pm, "p_name": "lampe.png", "p_mime": "image/png", "p_size": 72}, DEPT)
check("le département alimente la médiathèque", s == 200, d)

# ---------------- CV partagé (228)
call(f"/rest/v1/profiles?id=eq.{ST['id']}", {"bio": "Développeuse web", "skills": "React, Python"}, ST["tok"], "PATCH")
s, t1 = rpc("regenerate_cv_link", {}, ST)
check("lien de CV créé", s == 200 and len(t1) == 32, t1)
s, d = rpc("shared_cv", {"p_token": t1})
check("CV public sans compte, sans coordonnées", d and d.get("competences") == "React, Python" and "email" not in json.dumps(d) and "phone" not in json.dumps(d), d)
s, t2 = rpc("regenerate_cv_link", {}, ST)
s, d = rpc("shared_cv", {"p_token": t1})
check("l'ancien lien ne fonctionne plus après régénération", d is None, d)
s, d = rpc("shared_cv", {"p_token": t2})
check("le nouveau lien fonctionne", d and d.get("nom"), d)

# ---------------- code de retrait (46, 146-2)
title = sql("select title from listings where status='approved' and stock > 0 and category <> 'Services' limit 1;")
s, o = rpc("create_order", {"p_items": [{"title": title, "qty": 1}], "p_home": False, "p_method": "Orange Money"}, CL)
s, d = rpc("my_pickup_code", {"p_number": o["number"]}, CL)
check("pas de code avant paiement", s >= 400, str(d)[:80])
sql(f"update orders set paid = true where number = '{o['number']}';")  # étape de mise en place (paiement simulé côté base, comme les tests précédents)
s, code = rpc("my_pickup_code", {"p_number": o["number"]}, CL)
check("l'acheteur obtient un code à 6 chiffres", s == 200 and isinstance(code, str) and len(code) == 6 and code.isdigit(), code)
s, again = rpc("my_pickup_code", {"p_number": o["number"]}, CL)
check("le code est stable", again == code, again)
s, d = rpc("my_pickup_code", {"p_number": o["number"]}, ST)
check("un tiers n'obtient pas le code", s >= 400, str(d)[:80])
s, d = rpc("confirm_pickup", {"p_number": o["number"], "p_code": code}, ST)
check("seul le kiosque confirme la remise", s >= 400, str(d)[:80])
s, d = rpc("confirm_pickup", {"p_number": o["number"], "p_code": "000000" if code != "000000" else "111111"}, SUP)
check("code erroné refusé (signalé, journalisé)", d == "incorrect", str(d)[:80])
check("l'essai erroné est journalisé", sql(f"select count(*) from audit_log where action = 'Code de retrait erroné' and target = '{o['number']}';") == "1", "")
s, d = rpc("confirm_pickup", {"p_number": o["number"], "p_code": code}, SUP)
check("remise confirmée avec le bon code", d == "delivered", d)
s, d = get(f"orders?select=status,picked_up_at&number=eq.{o['number'].replace('#', '%23')}", CL)
check("commande livrée et horodatée", d and d[0]["status"] == 3 and d[0]["picked_up_at"], d)
s, d = rpc("confirm_pickup", {"p_number": o["number"], "p_code": code}, SUP)
check("une commande ne se remet qu'une fois", s >= 400, str(d)[:80])
s, o2 = rpc("create_order", {"p_items": [{"title": title, "qty": 1}], "p_home": False, "p_method": "Orange Money"}, CL)
sql(f"update orders set paid = true where number = '{o2['number']}';")
s, c2 = rpc("my_pickup_code", {"p_number": o2["number"]}, CL)
wrong = "000000" if c2 != "000000" else "111111"
for _ in range(5):
    rpc("confirm_pickup", {"p_number": o2["number"], "p_code": wrong}, SUP)
s, d = rpc("confirm_pickup", {"p_number": o2["number"], "p_code": c2}, SUP)
check("après 5 essais erronés, même le bon code est refusé", s >= 400 and "Trop" in str(d), str(d)[:80])
s, c3 = rpc("my_pickup_code", {"p_number": o2["number"]}, CL)
check("l'acheteur obtient un nouveau code", isinstance(c3, str) and len(c3) == 6 and c3 != c2, c3)
s, d = rpc("confirm_pickup", {"p_number": o2["number"], "p_code": c3}, SUP)
check("le nouveau code permet la remise", d == "delivered", d)

# ---------------- invitations (286)
s, d = rpc("invite_department_member", {"p_email": ST2["email"], "p_role": "validator"}, ST)
check("un étudiant n'invite pas", s >= 400, str(d)[:80])
s, d = rpc("invite_department_member", {"p_email": "pas-une-adresse", "p_role": "member"}, DEPT)
check("adresse invalide refusée", s >= 400, str(d)[:80])
s, d = rpc("invite_department_member", {"p_email": ST2["email"], "p_role": "validator"}, DEPT)
check("le département invite un compte existant (notifié)", d == "notified", d)
s, d = get("notifications?select=title&kind=eq.team", ST2)
check("l'invité est notifié", len(d) == 1, d)
s, d = get("department_invitations?select=role,status", ST2)
check("l'invité voit son invitation", d == [{"role": "validator", "status": "pending"}], d)
s, d = get("department_invitations?select=id", ST)
check("un tiers ne voit pas les invitations", d == [], d)

print(f"\n{sum(res)}/{len(res)}")

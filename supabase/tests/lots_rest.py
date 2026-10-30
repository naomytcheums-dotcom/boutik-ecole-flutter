"""Tests REST de la migration 20261031a (missions, propositions, jalons, vœux, campagnes, certificats, bornes, projets, liens).

ENVIRONNEMENT ISOLÉ UNIQUEMENT : les rôles « dept » et « support » ne peuvent pas être pris par inscription (règle de sécurité) ;
le script les attribue par SQL dans le conteneur Supabase LOCAL, et refuse de s'exécuter si BE_URL n'est pas local.
Usage : BE_URL=http://127.0.0.1:54321 BE_KEY=<publishable locale> python supabase/tests/lots_rest.py [conteneur_db]
"""
import json, os, subprocess, sys, urllib.error, urllib.request, uuid

U = os.environ.get("BE_URL", "")
K = os.environ.get("BE_KEY", "")
DB = sys.argv[1] if len(sys.argv) > 1 else "supabase_db_boutik_local"
if not U.startswith("http://127.0.0.1") and not U.startswith("http://localhost"):
    sys.exit("Refusé : ce test modifie des rôles par SQL et ne s'exécute que sur une base locale isolée.")
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


def sql(q):
    r = subprocess.run(["docker", "exec", "-i", DB, "psql", "-U", "postgres", "-t", "-A", "-q"], input=q.encode(), capture_output=True)
    if r.returncode:
        raise SystemExit(r.stderr.decode())
    return r.stdout.decode().strip()


def mk(tag, role, staff=None):
    email = f"zz-test-{tag}-{uuid.uuid4().hex[:8]}@example.com"
    pw = "Zz-test-" + uuid.uuid4().hex[:8] + "!"
    s, d = call("/auth/v1/signup", {"email": email, "password": pw})
    uid, tok = d["user"]["id"], d["access_token"]
    call("/rest/v1/profiles", {"id": uid, "name": "Test " + tag, "email": email, "role": role}, tok)
    if staff:
        sql(f"update profiles set role = '{staff}' where id = '{uid}';")
    return {"id": uid, "tok": tok, "email": email}


rpc = lambda fn, body, who=None: call("/rest/v1/rpc/" + fn, body, who["tok"] if who else None)
get = lambda path, who=None: call("/rest/v1/" + path, None, who["tok"] if who else None, "GET")

CL, ST, ST2, DEPT, SUP = mk("cli", "company"), mk("stu", "student"), mk("stu2", "student"), mk("dep", "client", "dept"), mk("sup", "client", "support")

# ---------------- missions
need = {"p_id": None, "p_title": "Application de suivi clients", "p_description": "Une application web pour suivre les clients et les commandes.",
        "p_budget_min": 300000, "p_budget_max": 500000, "p_deadline": "30 nov. 2026", "p_publish": False, "p_kind": "besoin"}
s, d = rpc("save_mission", need)
check("visiteur : besoin refusé", s >= 400, s)
s, draft = rpc("save_mission", need, CL)
check("le client enregistre un brouillon", s == 200 and isinstance(draft, str), draft)
s, d = get("missions?select=id&status=eq.draft", ST)
check("un brouillon n'est pas visible des talents", d == [], d)
s, d = rpc("save_mission", {**need, "p_publish": True, "p_description": "court"}, CL)
check("publication sans description suffisante refusée", s >= 400, str(d)[:80])
s, d = rpc("save_mission", {**need, "p_budget_min": 500, "p_budget_max": 100}, CL)
check("budget incohérent refusé", s >= 400, str(d)[:80])
s, mid = rpc("save_mission", {**need, "p_id": draft, "p_publish": True}, CL)
check("le client publie son brouillon", s == 200 and mid == draft, mid)
s, d = rpc("save_mission", {**need, "p_id": draft, "p_title": "Piratage"}, ST)
check("un tiers ne modifie pas le besoin", s >= 400, str(d)[:80])
s, d = call(f"/rest/v1/missions?id=eq.{mid}", {"status": "closed"}, ST["tok"], "PATCH")
check("aucune modification directe d'une mission (ancienne faille fermée)", s >= 400 or not d, s)
s, d = get(f"missions?select=title,status&id=eq.{mid}", ST)
check("le besoin publié est visible des talents", d and d[0]["status"] == "published", d)
s, d = rpc("propose_on_mission", {"p_mission": mid, "p_amount": 400000, "p_delay_days": 14, "p_message": "Équipe de deux"}, CL)
check("le client ne propose pas sur son propre besoin", s >= 400, str(d)[:80])
s, d = rpc("propose_on_mission", {"p_mission": mid, "p_amount": 0, "p_delay_days": 14, "p_message": ""}, ST)
check("montant nul refusé", s >= 400, str(d)[:80])
s, p1 = rpc("propose_on_mission", {"p_mission": mid, "p_amount": 400000, "p_delay_days": 14, "p_message": "Équipe de deux"}, ST)
check("le talent propose", s == 200, p1)
s, d = rpc("propose_on_mission", {"p_mission": mid, "p_amount": 390000, "p_delay_days": 14, "p_message": ""}, ST)
check("une seule proposition en cours par talent", s >= 400, str(d)[:80])
s, p2 = rpc("propose_on_mission", {"p_mission": mid, "p_amount": 450000, "p_delay_days": 10, "p_message": ""}, ST2)
check("un second talent propose", s == 200, p2)
s, d = get("mission_proposals?select=id", ST2)
check("un talent ne voit que sa proposition", len(d) == 1, d)
s, d = get("notifications?select=title&kind=eq.mission", CL)
check("le client est notifié des propositions", len(d) == 2, d)
s, d = rpc("decide_proposal", {"p_id": p1, "p_accept": True}, ST2)
check("un talent ne décide pas à la place du client", s >= 400, str(d)[:80])
s, d = rpc("decide_proposal", {"p_id": p1, "p_accept": True}, CL)
check("le client accepte une proposition", s == 200 and d == "accepted", d)
s, d = get(f"mission_proposals?select=status&id=eq.{p2}", CL)
check("l'autre proposition est déclinée", d[0]["status"] == "declined", d)
s, d = get(f"missions?select=status,total&id=eq.{mid}", CL)
check("le besoin est attribué au montant accepté", d[0] == {"status": "assigned", "total": 400000}, d)
s, d = get("mission_milestones?select=position,amount,status&order=position", ST)
check("trois jalons créés, somme = montant", len(d) == 3 and sum(x["amount"] for x in d) == 400000, d)
s, d = get("mission_milestones?select=position", ST2)
check("le talent non retenu ne voit pas les jalons", d == [], d)
s, d = rpc("decide_milestone", {"p_mission": mid, "p_position": 1, "p_validate": True, "p_note": ""}, CL)
check("on ne valide pas un jalon non livré", s >= 400, str(d)[:80])
s, d = rpc("submit_milestone", {"p_mission": mid, "p_position": 1}, ST2)
check("seul le prestataire retenu livre", s >= 400, str(d)[:80])
s, d = rpc("submit_milestone", {"p_mission": mid, "p_position": 1}, ST)
check("le prestataire livre le jalon 1", s == 200, d)
s, d = rpc("decide_milestone", {"p_mission": mid, "p_position": 1, "p_validate": False, "p_note": ""}, CL)
check("une correction exige un motif", s >= 400, str(d)[:80])
s, d = rpc("decide_milestone", {"p_mission": mid, "p_position": 1, "p_validate": False, "p_note": "Logo plus sobre"}, CL)
check("le client demande une correction", d == "correction", d)
rpc("submit_milestone", {"p_mission": mid, "p_position": 1}, ST)
s, d = rpc("decide_milestone", {"p_mission": mid, "p_position": 1, "p_validate": True, "p_note": ""}, CL)
check("puis valide le jalon corrigé", d == "validated", d)
for pos in (2, 3):
    rpc("submit_milestone", {"p_mission": mid, "p_position": pos}, ST)
    rpc("decide_milestone", {"p_mission": mid, "p_position": pos, "p_validate": True, "p_note": ""}, CL)
s, d = get(f"missions?select=status&id=eq.{mid}", CL)
check("tous les jalons validés : mission livrée", d[0]["status"] == "delivered", d)
s, m2 = rpc("save_mission", {**need, "p_title": "Identité visuelle complète", "p_publish": True}, CL)
s, d = rpc("assign_mission", {"p_mission": m2, "p_team": "Aminata Bello · MMI"}, ST)
check("seul le département attribue", s >= 400, str(d)[:80])
s, d = rpc("assign_mission", {"p_mission": m2, "p_team": "Aminata Bello · MMI"}, DEPT)
check("le département attribue à une équipe", d == "assigned", d)

# ---------------- vœux
wish = {"p_id": None, "p_title": "Lampe en bois recyclé", "p_description": "Bois de récupération", "p_price": 25000, "p_threshold": 200, "p_duration_days": 30, "p_submit": False}
s, w = rpc("save_wish", wish, ST)
check("un vœu en brouillon", s == 200, w)
s, d = get(f"wishes?select=id&id=eq.{w}")
check("un brouillon de vœu n'est pas public", d == [] or s >= 400, d)
s, d = rpc("save_wish", {**wish, "p_id": w, "p_submit": True, "p_price": None}, ST)
check("envoi sans prix refusé", s >= 400, str(d)[:80])
s, d = rpc("save_wish", {**wish, "p_id": w, "p_submit": True}, ST)
check("le vœu est envoyé en validation", s == 200, d)
s, d = rpc("delete_wish", {"p_id": w}, ST)
check("un vœu en validation ne se supprime pas", s >= 400, str(d)[:80])
s, d = get("notifications?select=title&kind=eq.wish", DEPT)
check("le département est notifié", "Vœu à valider" in [x["title"] for x in d], d)
s, d = rpc("review_wish", {"p_id": w, "p_decision": "approved", "p_note": "", "p_scheduled_for": None}, ST)
check("l'auteur ne valide pas son vœu", s >= 400, str(d)[:80])
s, d = rpc("review_wish", {"p_id": w, "p_decision": "rejected", "p_note": "", "p_scheduled_for": None}, DEPT)
check("un refus exige un motif", s >= 400, str(d)[:80])
s, d = rpc("review_wish", {"p_id": w, "p_decision": "scheduled", "p_note": "", "p_scheduled_for": "1er nov."}, DEPT)
check("le département planifie le vœu", d == "scheduled", d)
s, d = get(f"wishes?select=status&id=eq.{w}")
check("un vœu planifié est public", d and d[0]["status"] == "scheduled", d)
s, w2 = rpc("save_wish", {**wish, "p_title": "Brouillon à supprimer"}, ST)
s, d = rpc("delete_wish", {"p_id": w2}, ST2)
check("un autre étudiant ne supprime pas le vœu", s >= 400, str(d)[:80])
s, d = rpc("delete_wish", {"p_id": w2}, ST)
check("l'auteur supprime son brouillon", d == "deleted", d)

# ---------------- campagnes
camp = {"p_id": None, "p_kind": "project", "p_project": "Serre intelligente", "p_goal": 2000000, "p_duration_days": 30,
        "p_presentation": "Une serre connectée pour protéger les récoltes des maraîchers.", "p_rewards": None, "p_submit": True}
s, d = rpc("save_campaign", camp, CL)
check("une entreprise ne crée pas de campagne étudiante", s >= 400, str(d)[:80])
s, d = rpc("save_campaign", {**camp, "p_goal": 10}, ST)
check("objectif trop faible refusé", s >= 400, str(d)[:80])
s, c = rpc("save_campaign", camp, ST)
check("l'étudiant envoie sa campagne", s == 200, c)
s, d = get(f"campaigns?select=id&id=eq.{c}")
check("une campagne non validée n'est pas publique", d == [] or s >= 400, d)
s, d = rpc("review_campaign", {"p_id": c, "p_approve": True, "p_note": ""}, DEPT)
check("le département valide la campagne", d == "approved", d)
s, d = get(f"campaigns?select=status&id=eq.{c}")
check("la campagne validée est publique", d and d[0]["status"] == "approved", d)

# ---------------- certificats
s, d = rpc("issue_certificate", {"p_kind": "talent", "p_subject": "Développeur web", "p_holder_email": ST["email"], "p_holder_name": "", "p_department": "GI"}, ST)
check("un étudiant n'émet pas de certificat", s >= 400, str(d)[:80])
s, d = rpc("issue_certificate", {"p_kind": "product", "p_subject": "Produit inexistant", "p_holder_email": "", "p_holder_name": "X Y", "p_department": ""}, DEPT)
check("produit non validé : certificat refusé", s >= 400, str(d)[:80])
s, code = rpc("issue_certificate", {"p_kind": "talent", "p_subject": "Développeur web", "p_holder_email": ST["email"], "p_holder_name": "", "p_department": "GI"}, DEPT)
check("le département émet un certificat", s == 200 and str(code).startswith("BE-CERT-"), code)
s, d = rpc("issue_certificate", {"p_kind": "talent", "p_subject": "Développeur web", "p_holder_email": ST["email"], "p_holder_name": "", "p_department": "GI"}, DEPT)
check("doublon de certificat refusé", s >= 400, str(d)[:80])
s, d = rpc("verify_certificate", {"p_code": code})
check("vérification publique (sans compte) : authentique", d.get("valide") is True and d.get("titulaire"), d)
s, d = rpc("verify_certificate", {"p_code": "BE-CERT-00000000"})
check("code inconnu : introuvable", d.get("introuvable") is True, d)
s, d = get("certificates?select=code", ST2)
check("un tiers ne liste pas les certificats", d == [], d)
s, d = get("certificates?select=code", ST)
check("le titulaire voit son certificat", [x["code"] for x in d] == [code], d)
s, d = rpc("revoke_certificate", {"p_code": code, "p_reason": "Erreur de titulaire"}, DEPT)
check("révocation motivée", d == "revoked", d)
s, d = rpc("verify_certificate", {"p_code": code})
check("un certificat révoqué n'est plus valide", d.get("valide") is False and d.get("motif_revocation"), d)

# ---------------- bornes
s, d = get("kiosks?select=id&order=id")
check("les bornes sont listées publiquement", [x["id"] for x in d] == ["borne-1", "borne-2", "borne-3", "borne-4"], d)
s, d = rpc("report_kiosk_incident", {"p_kiosk": "borne-2", "p_kind": "offline", "p_message": "Hors ligne depuis 6 min", "p_status": "fallback"}, ST)
check("un étudiant ne signale pas d'incident de borne", s >= 400, str(d)[:80])
s, d = rpc("report_kiosk_incident", {"p_kiosk": "borne-2", "p_kind": "offline", "p_message": "Hors ligne depuis 6 min", "p_status": "fallback"}, SUP)
check("le support signale un incident", s == 200, d)
s, d = get("kiosk_incidents?select=kiosk_id", ST)
check("le journal des incidents est réservé", d == [], d)
s, d = get("kiosks?select=status&id=eq.borne-2")
check("l'état de la borne est mis à jour", d[0]["status"] == "fallback", d)
import random
day = f"{random.randint(2030, 2099)}-{random.randint(1, 12):02d}-{random.randint(1, 28):02d}"  # créneau libre à chaque série
ev = {"p_kiosk": "borne-2", "p_title": "Journée de l'innovation", "p_starts": day + "T08:00:00Z", "p_ends": day + "T18:00:00Z"}
s, d = rpc("schedule_kiosk_event", ev, SUP)
check("le support programme un événement", s == 200, d)
s, d = rpc("schedule_kiosk_event", {**ev, "p_starts": day + "T10:00:00Z", "p_ends": day + "T12:00:00Z"}, SUP)
check("chevauchement de créneau refusé", s >= 400, str(d)[:80])
s, d = rpc("schedule_kiosk_event", {**ev, "p_ends": day + "T07:00:00Z"}, SUP)
check("fin avant début refusée", s >= 400, str(d)[:80])

# ---------------- projets, lives, liens
s, pr = rpc("save_project", {"p_id": None, "p_title": "Serre intelligente", "p_summary": "court", "p_department": "BTA", "p_links": {}, "p_submit": True}, ST)
check("projet trop peu décrit : envoi refusé", s >= 400, str(pr)[:80])
s, pr = rpc("save_project", {"p_id": None, "p_title": "Serre intelligente", "p_summary": "Serre connectée pour les maraîchers de Douala.", "p_department": "BTA", "p_links": {}, "p_submit": False}, ST)
check("projet en brouillon", s == 200, pr)
s, d = rpc("add_project_step", {"p_project": pr, "p_title": "Prototype assemblé"}, ST)
check("étape ajoutée au journal", s == 200, d)
s, d = rpc("add_project_step", {"p_project": pr, "p_title": "Intrusion"}, ST2)
check("un tiers n'écrit pas dans le journal", s >= 400, str(d)[:80])
s, d = rpc("save_project", {"p_id": pr, "p_title": "Serre intelligente", "p_summary": None, "p_department": None, "p_links": {"github": "https://github.com/x/serre"}, "p_submit": True}, ST)
check("liens enregistrés et projet envoyé", s == 200, d)
s, d = rpc("review_project", {"p_id": pr, "p_approve": True, "p_note": ""}, DEPT)
check("le département accepte le projet", d == "approved", d)
s, d = rpc("save_live", {"p_title": "Fabrication de la lampe", "p_starts_at": "Jeudi 16 h", "p_product": "Lampe en bois recyclé", "p_schedule": True}, ST)
check("live programmé", s == 200, d)
s, d = get("scheduled_lives?select=title")
check("les lives programmés sont publics", any(x["title"] == "Fabrication de la lampe" for x in d), d)
s, d = rpc("save_profile_links", {"p_links": [{"label": "Portfolio", "url": "javascript:alert(1)"}]}, ST)
check("lien non https refusé", s >= 400 and "Lien invalide" in str(d), str(d)[:80])
s, d = rpc("save_profile_links", {"p_links": [{"label": "Portfolio", "url": "https://behance.net/x"}]}, ST)
check("lien https enregistré", d == 1, d)

print(f"\n{sum(res)}/{len(res)}")

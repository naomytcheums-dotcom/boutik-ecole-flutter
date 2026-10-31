"""Tests de sécurité ciblés sur 20261031a/b (et leur correctif 20261031c) — ENVIRONNEMENT ISOLÉ UNIQUEMENT.

Chaque contrôle exprime le comportement ATTENDU. Sur « réplique de production + 20261031a + 20261031b », les contrôles
marqués [défaut] échouent (démonstration) ; avec 20261031c ils doivent tous réussir.
Usage : BE_URL=http://127.0.0.1:54321 BE_KEY=<publishable locale> python supabase/tests/security_31_rest.py [conteneur_db]
"""
import json, os, re, subprocess, sys, urllib.error, urllib.request, uuid

U = os.environ.get("BE_URL", "")
K = os.environ.get("BE_KEY", "")
DB = sys.argv[1] if len(sys.argv) > 1 else "supabase_db_boutik_local"
if not U.startswith("http://127.0.0.1") and not U.startswith("http://localhost"):
    sys.exit("Refusé : base locale isolée uniquement.")
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
    print("OK    " if cond else "ECHEC ", name, "|", str(detail)[:150])


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

CL, ST, TIERS, DEPT = mk("sc-cli", "company"), mk("sc-stu", "student"), mk("sc-tiers", "student"), mk("sc-dep", "client", "dept")
need = {"p_id": None, "p_title": "Besoin confidentiel", "p_description": "Refonte complète de la marque, budget et calendrier confidentiels.",
        "p_budget_min": 400000, "p_budget_max": 900000, "p_deadline": "", "p_publish": True, "p_kind": "besoin"}
s, mid = rpc("save_mission", need, CL)
s, pid = rpc("propose_on_mission", {"p_mission": mid, "p_amount": 500000, "p_delay_days": 20, "p_message": ""}, ST)

# --- missions publiées : visibles des talents connectés, jamais du public
s, d = get(f"missions?select=id&id=eq.{mid}", TIERS)
check("un besoin publié est visible d'un talent connecté", len(d) == 1, d)
s, d = get(f"missions?select=id&id=eq.{mid}")
check("un besoin publié n'est pas visible sans compte", d == [] or s >= 400, d)
rpc("decide_proposal", {"p_id": pid, "p_accept": True}, CL)
s, d = get(f"missions?select=id,budget_max,description&id=eq.{mid}", TIERS)
check("[défaut] une mission ATTRIBUÉE n'est plus visible des tiers (budget, description)", d == [], d)
s, d = get(f"missions?select=id&id=eq.{mid}", ST)
check("le prestataire retenu voit toujours sa mission", len(d) == 1, d)
s, d = get(f"missions?select=id&id=eq.{mid}", DEPT)
check("le département voit la mission (modération)", len(d) == 1, d)

# --- appels sans compte aux fonctions sensibles : refusés
for fn, body in (("assign_mission", {"p_mission": mid, "p_team": "X"}), ("submit_milestone", {"p_mission": mid, "p_position": 1}),
                 ("decide_milestone", {"p_mission": mid, "p_position": 1, "p_validate": True, "p_note": ""})):
    s, d = rpc(fn, body)
    check(f"sans compte : {fn} refusé", s >= 400, s)
src = sql("select string_agg(prosrc, ' ') from pg_proc where proname in ('assign_mission','submit_milestone','decide_milestone');")
check("[défaut] assign_mission, submit_milestone, decide_milestone contrôlent explicitement auth.uid()",
      len(re.findall(r"auth\.uid\(\) is null", src)) >= 3, f"{len(re.findall(r'auth.uid\(\) is null', src))} contrôle(s) explicite(s)")

# --- dossier de mission : le personnel peut lire (modération) mais ne parle pas à la place des parties
s, d = rpc("send_mission_message", {"p_mission": mid, "p_body": "Message du prestataire"}, ST)
check("le prestataire écrit dans le dossier", s == 200, d)
s, d = get(f"mission_messages?select=body&mission_id=eq.{mid}", DEPT)
check("le département lit le dossier (modération)", len(d) == 1, d)
s, d = rpc("send_mission_message", {"p_mission": mid, "p_body": "Intervention non sollicitée"}, DEPT)
check("[défaut] le département n'écrit pas dans un dossier dont il n'est pas partie", s >= 400, d)

# --- projet approuvé : toute modification repasse en validation ; un projet en cours d'examen n'est pas modifiable
s, prj = rpc("save_project", {"p_id": None, "p_title": "Serre connectée", "p_summary": "Serre connectée pour les maraîchers de Douala.", "p_department": "BTA", "p_links": {}, "p_submit": True}, ST)
s, d = rpc("save_project", {"p_id": prj, "p_title": "Serre connectée (modifiée pendant l'examen)", "p_summary": None, "p_department": None, "p_links": {}, "p_submit": False}, ST)
check("[défaut] un projet en cours d'examen n'est pas modifiable", s >= 400, d)
rpc("review_project", {"p_id": prj, "p_approve": True, "p_note": ""}, DEPT)
s, d = rpc("save_project", {"p_id": prj, "p_title": "Contenu non validé", "p_summary": None, "p_department": None, "p_links": {"demo": "https://exemple.org"}, "p_submit": False}, ST)
s, d = get(f"projects?select=title,status&id=eq.{prj}", TIERS)
check("[défaut] un projet approuvé modifié n'est plus publié tel quel (repasse en validation)", d == [] or d[0]["status"] != "approved", d)

# --- certificats : code non énumérable, données publiques limitées au certificat
s, code = rpc("issue_certificate", {"p_kind": "talent", "p_subject": "Développeur web", "p_holder_email": ST["email"], "p_holder_name": "", "p_department": "GI"}, DEPT)
check("[défaut] code de certificat d'au moins 64 bits (16 caractères hexadécimaux)", isinstance(code, str) and re.fullmatch(r"BE-CERT-[0-9A-F]{16}", code), code)
s, v = rpc("verify_certificate", {"p_code": code})
check("vérification publique : authentique", isinstance(v, dict) and v.get("valide") is True, v)
check("vérification publique : aucune adresse e-mail ni identifiant de compte", isinstance(v, dict) and "@" not in json.dumps(v) and ST["id"] not in json.dumps(v), sorted(v) if isinstance(v, dict) else v)
s, d = rpc("verify_certificate", {"p_code": "BE-CERT-0000000000000000"})
check("code inconnu : introuvable", isinstance(d, dict) and d.get("introuvable") is True, d)

# --- code de retrait : généré par un aléa cryptographique
src = sql("select prosrc from pg_proc where proname = 'my_pickup_code';")
check("[défaut] le code de retrait utilise gen_random_bytes (et non random())", "gen_random_bytes" in src and "random()" not in src, "random()" if "random()" in src else "ok")

# --- hygiène : fonctions de déclencheur non exécutables directement par anon / authenticated ; search_path fixé
trig = sql("""select string_agg(p.proname, ',') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prorettype = 'trigger'::regtype and (has_function_privilege('anon', p.oid, 'EXECUTE') or has_function_privilege('authenticated', p.oid, 'EXECUTE'));""")
check("[défaut] aucune fonction de déclencheur exécutable par anon ou authenticated", trig == "", trig)
nopath = sql("""select string_agg(p.proname, ',') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f' and (p.proconfig is null or not exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%'));""")
check("[défaut] toutes les fonctions publiques fixent leur search_path", nopath == "", nopath)

# --- politiques héritées : aucune politique « missions » antérieure ne subsiste
pol = sql("select string_agg(policyname, ' | ' order by policyname) from pg_policies where schemaname = 'public' and tablename = 'missions';")
check("[défaut] une seule politique sur missions (anciennes politiques retirées)", pol in ("missions : visibilité restreinte",), pol)
legacy = sql("""select string_agg(tablename || ':' || policyname, ' | ') from pg_policies where schemaname = 'public' and
  policyname in ('journal alimenté par les utilisateurs connectés', 'validation par le département');""")
check("aucune politique permissive héritée de schema.sql (journal, validation des annonces)", legacy == "", legacy)

# --- un déclencheur fonctionne toujours après retrait du droit EXECUTE
sql("insert into listings (seller_id, title, department, category, price, stock, status) values (null, 'zz-test-securite', 'T', 'Maison', 1000, 5, 'approved') on conflict do nothing;")
title = "zz-test-securite"
s, o = rpc("create_order", {"p_items": [{"title": title, "qty": 1}], "p_home": False, "p_method": "Orange Money"}, CL)
s, d = rpc("cancel_order", {"p_number": o.get("number") if isinstance(o, dict) else ""}, CL)
check("les déclencheurs de stock et d'annulation s'exécutent toujours", s == 200 and sql(f"select cancelled from orders where number = '{o['number']}';") == "t", d)

print(f"\n{sum(res)}/{len(res)}")

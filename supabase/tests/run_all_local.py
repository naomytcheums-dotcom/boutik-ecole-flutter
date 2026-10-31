"""Exécute toutes les suites REST sur la base ISOLÉE (Docker), avec les étapes de mise en place réservées au propriétaire
de la base (approbation de l'annonce de test, paiement simulé de la commande de test) faites en SQL local.

Usage : BE_URL=http://127.0.0.1:54321 BE_KEY=<publishable locale> python supabase/tests/run_all_local.py [conteneur_db]
Refuse de s'exécuter si BE_URL n'est pas local. Code de sortie 0 si toutes les suites sont complètes.
"""
import json, os, re, subprocess, sys, tempfile

U = os.environ.get("BE_URL", "")
if not U.startswith("http://127.0.0.1") and not U.startswith("http://localhost"):
    sys.exit("Refusé : base locale isolée uniquement.")
DB = sys.argv[1] if len(sys.argv) > 1 else "supabase_db_boutik_local"
HERE = os.path.dirname(os.path.abspath(__file__))


def sql(q):
    r = subprocess.run(["docker", "exec", "-i", DB, "psql", "-U", "postgres", "-t", "-A", "-q"], input=q.encode(), capture_output=True)
    if r.returncode:
        raise SystemExit(r.stderr.decode())
    return r.stdout.decode().strip()


def run(script, *args, state=None):
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    if state:
        env["STATE"] = state
    r = subprocess.run([sys.executable, os.path.join(HERE, script), *args], capture_output=True, text=True, encoding="utf-8", env=env)
    out = r.stdout + r.stderr
    score = re.findall(r"^(\d+)/(\d+)", out, re.M)
    if not score:  # suites sans total : on compte les lignes de contrôle
        ok, ko = len(re.findall(r"^OK\b", out, re.M)), len(re.findall(r"^ECHEC\b", out, re.M))
        score = [(str(ok), str(ok + ko))] if ok + ko else []
    fails = [l for l in out.splitlines() if l.startswith("ECHEC") or l.startswith("Traceback") or (rc_line := l).startswith("SystemExit")]
    if r.returncode and not fails:
        fails = [out.strip().splitlines()[-1][:200] if out.strip() else f"code {r.returncode}"]
    return score, fails, r.returncode


def approve(state):
    s = json.load(open(state, encoding="utf-8"))
    sql(f"update listings set status = 'approved' where title = '{s['title']}';")


def pay(state):
    s = json.load(open(state, encoding="utf-8"))
    sql(f"update orders set paid = true where buyer_id = '{s['B']['id']}' and not paid and cancelled_at is null;")


SIMPLE = ["lots_rest.py", "lots2_rest.py", "security_31_rest.py", "engagements_rest.py", "favorites_rest.py", "mfa_rest.py"]
PHASED = {  # suite : étapes (« approve » et « pay » sont faites en SQL local entre les phases)
    "quotes_rest.py": ["1", "approve", "2"],
    "listings_stock_rest.py": ["1", "approve", "2"],
    "conversations_list_rest.py": ["1", "approve", "2"],
    "chat_attachments_rest.py": ["1", "approve", "2"],
    "messaging_rest.py": ["1", "approve", "2", "pay", "3"],
    "seller_orders_rest.py": ["1", "approve", "2", "pay", "3"],
    "feedback_rest.py": ["1", "approve", "2", "pay", "3"],
}

if __name__ == "__main__":
    total_ok, total, problems = 0, 0, []
    for s in SIMPLE:
        score, fails, rc = run(s)
        ok, n = (int(score[-1][0]), int(score[-1][1])) if score else (0, 0)
        total_ok += ok; total += n
        print(f"{s:28} {ok}/{n}" + ("" if ok == n and n and not fails else "   <== " + "; ".join(fails[:3])[:200]))
        if ok != n or not n:
            problems.append(s)
    for s, steps in PHASED.items():
        state = os.path.join(tempfile.gettempdir(), f"state_{s}.json")
        if os.path.exists(state):
            os.remove(state)
        ok_s, n_s, fails_all = 0, 0, []
        for st in steps:
            if st == "approve":
                approve(state)
            elif st == "pay":
                pay(state)
            else:
                score, fails, rc = run(s, st, state=state)
                for a, b in score:
                    ok_s += int(a); n_s += int(b)
                fails_all += fails
        # certaines phases n'impriment pas de total : on compte alors les lignes OK/ECHEC
        total_ok += ok_s; total += n_s
        print(f"{s:28} {ok_s}/{n_s}" + ("" if ok_s == n_s and not fails_all else "   <== " + "; ".join(fails_all[:3])[:200]))
        if ok_s != n_s or fails_all:
            problems.append(s)
    print(f"\nTOTAL {total_ok}/{total}" + (f" — à examiner : {', '.join(problems)}" if problems else ""))
    sys.exit(1 if problems else 0)

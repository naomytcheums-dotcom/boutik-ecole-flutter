"""Test de bout en bout de l'Edge Function « pay », en local et sans aucun paiement réel.

La vraie fonction tourne dans Deno ; l'authentification Supabase, PostgREST et l'API Notch Pay sont simulés.
Contrôles : identité exigée, commande d'autrui refusée, numéro invalide, commande annulée, paiement déjà payé,
pas de second prélèvement tant que le premier est en attente, montant absent ou insuffisant refusé, devise et référence,
transition unique non payé -> payé, jamais sur une commande annulée.
Lancement : python supabase/tests/pay_e2e.py   (nécessite Node/npx pour obtenir Deno)
"""
import json, os, subprocess, threading, time, urllib.error, urllib.parse, urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MOCK_PORT, FN_PORT = 54332, 8000
HERE = os.path.dirname(os.path.abspath(__file__))
FN = os.environ.get("PAY_FN") or os.path.join(HERE, "..", "functions", "pay", "index.ts")  # PAY_FN : autre version (démonstration)
state = {}
calls = []


def reset():
    state["users"] = {"jwt-B": {"id": "uB", "email": "b@example.com"}, "jwt-C": {"id": "uC", "email": "c@example.com"}}
    state["orders"] = {
        "o1": {"id": "o1", "number": "#BE-P-1", "buyer_id": "uB", "subtotal": 25000, "fee": 0, "paid": False, "status": 0, "reference": None, "cancelled": False, "cancelled_at": None},
        "o2": {"id": "o2", "number": "#BE-P-2", "buyer_id": "uB", "subtotal": 10000, "fee": 0, "paid": False, "status": 0, "reference": None, "cancelled": True, "cancelled_at": "2026-10-31T08:00:00Z"},
        "o3": {"id": "o3", "number": "#BE-P-3", "buyer_id": "uB", "subtotal": 8000, "fee": 0, "paid": True, "status": 1, "reference": "trx.paid", "cancelled": False, "cancelled_at": None},
        "o4": {"id": "o4", "number": "#BE-P-4", "buyer_id": "uB", "subtotal": 30000, "fee": 0, "paid": False, "status": 0, "reference": "trx.noamount", "cancelled": False, "cancelled_at": None},
        "o5": {"id": "o5", "number": "#BE-P-5", "buyer_id": "uB", "subtotal": 30000, "fee": 0, "paid": False, "status": 0, "reference": "trx.cancelled-late", "cancelled": True, "cancelled_at": "2026-10-31T08:00:00Z"},
    }
    state["notch"] = {
        "trx.noamount": {"reference": "trx.noamount", "status": "complete", "currency": "XAF"},
        "trx.cancelled-late": {"reference": "trx.cancelled-late", "status": "complete", "amount": 30000, "currency": "XAF"},
    }
    state["seq"] = 0
    calls.clear()


def eq(q, k):
    v = q.get(k, [None])[0]
    return v[3:] if v and v.startswith("eq.") else None


class Mock(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def send(self, code, body=None):
        raw = b"" if body is None else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}")

    def handle_any(self, method):
        u = urllib.parse.urlparse(self.path)
        q, p = urllib.parse.parse_qs(u.query), u.path
        calls.append((method, p))
        if p == "/auth/v1/user":
            tok = (self.headers.get("Authorization") or "").replace("Bearer ", "")
            usr = state["users"].get(tok)
            return self.send(200, usr) if usr else self.send(401, {"message": "invalid JWT"})
        if p == "/payments" and method == "POST":
            state["seq"] += 1
            ref = f"trx.new{state['seq']}"
            b = self.body()
            state["notch"][ref] = {"reference": ref, "status": "pending", "amount": b.get("amount"), "currency": b.get("currency")}
            return self.send(201, {"transaction": {"reference": ref}})
        if p.startswith("/payments/"):
            ref = urllib.parse.unquote(p.split("/payments/")[1])
            tx = state["notch"].get(ref)
            if method == "POST":
                return self.send(200, {"transaction": tx}) if tx else self.send(404, {"message": "introuvable"})
            return self.send(200, {"transaction": tx}) if tx else self.send(404, {"message": "introuvable"})
        if p == "/rest/v1/orders":
            rows = list(state["orders"].values())
            for k in ("number", "buyer_id", "id"):
                if eq(q, k) is not None:
                    rows = [r for r in rows if str(r[k]) == eq(q, k)]
            if method == "GET":
                return self.send(200, rows)
            if method == "PATCH":
                if eq(q, "paid") is not None:
                    rows = [r for r in rows if str(r["paid"]).lower() == eq(q, "paid")]
                if q.get("cancelled_at", [None])[0] == "is.null":
                    rows = [r for r in rows if r["cancelled_at"] is None]
                b = self.body()
                for r in rows:
                    r.update(b)
                return self.send(200, [{"id": r["id"]} for r in rows])
        self.send(404, {"message": "route simulée inconnue " + p})

    def do_GET(self): self.handle_any("GET")
    def do_POST(self): self.handle_any("POST")
    def do_PATCH(self): self.handle_any("PATCH")


def pay(body, tok="jwt-B"):
    h = {"Content-Type": "application/json", "Origin": "https://boutik-ecole.vercel.app"}
    if tok:
        h["Authorization"] = "Bearer " + tok
    req = urllib.request.Request(f"http://127.0.0.1:{FN_PORT}/", data=json.dumps(body).encode(), headers=h, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


results = []


def check(name, cond, detail=""):
    results.append(bool(cond))
    print(("OK   " if cond else "ECHEC"), name, str(detail)[:150])


def main():
    reset()
    srv = ThreadingHTTPServer(("127.0.0.1", MOCK_PORT), Mock)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    env = dict(os.environ, SUPABASE_URL=f"http://127.0.0.1:{MOCK_PORT}", SUPABASE_ANON_KEY="anon-test", SUPABASE_SERVICE_ROLE_KEY="service-test",
               NOTCHPAY_KEY="cle-test", NOTCHPAY_API=f"http://127.0.0.1:{MOCK_PORT}")
    proc = subprocess.Popen(["npx", "--yes", "deno", "run", "--allow-net", "--allow-env", FN], env=env, shell=(os.name == "nt"),
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    for _ in range(120):
        try:
            urllib.request.urlopen(f"http://127.0.0.1:{FN_PORT}/", timeout=1)
        except urllib.error.HTTPError:
            break
        except Exception:
            time.sleep(1)
    try:
        reset()
        start = lambda num, **kw: pay({"action": "start", "order_number": num, "phone": "+237690112233", "channel": "cm.orange", **kw})
        s, b = pay({"action": "start", "order_number": "#BE-P-1", "phone": "+237690112233"}, tok=None)
        check("sans compte -> 401", s == 401, b)
        s, b = pay({"action": "start", "order_number": "#BE-P-1", "phone": "+237690112233"}, tok="jwt-C")
        check("commande d'un autre acheteur -> 404", s == 404, b)
        s, b = start("#BE-P-1", phone="0690")
        check("numéro invalide -> 400, aucun appel au fournisseur", s == 400 and not any(c[1] == "/payments" for c in calls), b)
        s, b = start("#BE-P-2")
        check("commande annulée -> 409, aucun prélèvement", s == 409 and b.get("error") == "order_cancelled" and not any(c[1] == "/payments" for c in calls), b)
        s, b = start("#BE-P-3")
        check("commande déjà payée -> 409", s == 409 and b.get("error") == "already_paid", b)
        s, b = start("#BE-P-1")
        ref1 = b.get("reference")
        check("premier paiement demandé -> en attente, référence enregistrée", s == 200 and ref1 and state["orders"]["o1"]["reference"] == ref1, b)
        n_created = sum(1 for c in calls if c == ("POST", "/payments"))
        s, b = start("#BE-P-1")
        check("second appel pendant l'attente -> même référence, aucun second prélèvement", s == 200 and b.get("reference") == ref1 and b.get("reused")
              and sum(1 for c in calls if c == ("POST", "/payments")) == n_created, b)
        state["notch"][ref1].update(status="complete", amount=20000)
        s, b = pay({"action": "status", "order_number": "#BE-P-1"})
        check("montant insuffisant -> refusé, commande non payée", b.get("status") == "failed" and state["orders"]["o1"]["paid"] is False, b)
        state["notch"][ref1].update(amount=25000, currency="EUR")
        s, b = pay({"action": "status", "order_number": "#BE-P-1"})
        check("devise incorrecte -> refusé", b.get("status") == "failed" and state["orders"]["o1"]["paid"] is False, b)
        state["notch"][ref1].update(currency="XAF", reference="trx.autre")
        s, b = pay({"action": "status", "order_number": "#BE-P-1"})
        check("référence différente -> refusé", b.get("status") == "failed" and state["orders"]["o1"]["paid"] is False, b)
        state["notch"][ref1].update(reference=ref1)
        s, b = pay({"action": "status", "order_number": "#BE-P-1"})
        check("paiement complet et conforme -> commande payée", b.get("status") == "complete" and state["orders"]["o1"]["paid"] is True, b)
        s, b = pay({"action": "status", "order_number": "#BE-P-4"})
        check("montant absent chez le fournisseur -> jamais confirmé", b.get("status") == "failed" and state["orders"]["o4"]["paid"] is False, b)
        s, b = pay({"action": "status", "order_number": "#BE-P-5"})
        check("commande annulée -> jamais marquée payée", b.get("status") == "failed" and state["orders"]["o5"]["paid"] is False, b)
        state["orders"]["o1"].update(paid=False)
        state["notch"][ref1].update(status="complete")
        s, b = start("#BE-P-1")
        check("relance alors que le premier paiement a abouti -> confirmé sans nouveau prélèvement",
              b.get("status") == "complete" and state["orders"]["o1"]["paid"] is True and sum(1 for c in calls if c == ("POST", "/payments")) == n_created, b)
        s, b = pay({"action": "inconnue", "order_number": "#BE-P-1"})
        check("action inconnue -> 400", s == 400, b)
    finally:
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True) if os.name == "nt" else proc.terminate()
        srv.shutdown()
    print(f"\n{sum(results)}/{len(results)} contrôles réussis")


if __name__ == "__main__":
    main()

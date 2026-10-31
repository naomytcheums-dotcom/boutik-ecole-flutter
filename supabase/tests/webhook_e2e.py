"""Test de bout en bout du webhook Notch Pay, en local et sans toucher à la production.

La vraie fonction `notchpay-webhook` tourne dans Deno ; Supabase (PostgREST) et l'API Notch Pay sont remplacés par un
serveur simulé. Les événements sont signés avec un Hash Key de test (HMAC-SHA256 du corps brut, en hexadécimal).
Ce test valide la logique serveur ; il ne remplace PAS un événement réel envoyé par Notch Pay.

Lancement :  python supabase/tests/webhook_e2e.py     (nécessite Node/npx pour obtenir Deno)
"""
import hashlib, hmac, json, os, subprocess, sys, threading, time, urllib.parse, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HASH = "hash-de-test-local"
MOCK_PORT, FN_PORT = 54331, 8000
HERE = os.path.dirname(os.path.abspath(__file__))
FN = os.path.join(HERE, "..", "functions", "notchpay-webhook", "index.ts")

state = {"events": {}, "orders": {}, "notch": {}, "notch_down": False, "cancel_on_fetch": None}


def reset():
    state["events"].clear()
    state["notch_down"] = False
    state["cancel_on_fetch"] = None
    state["orders"] = {
        "o1": {"id": "o1", "number": "#BE-T-1", "reference": "trx.A", "subtotal": 25000, "fee": 0, "paid": False, "status": 0},
        "o2": {"id": "o2", "number": "#BE-T-2", "reference": "trx.B", "subtotal": 25000, "fee": 5000, "paid": False, "status": 0},
        "o3": {"id": "o3", "number": "#BE-T-3", "reference": "trx.C", "subtotal": 8000, "fee": 0, "paid": True, "status": 1},
        "o4": {"id": "o4", "number": "#BE-T-4", "reference": "trx.D", "subtotal": 5000, "fee": 0, "paid": False, "status": 0, "cancelled": True, "cancelled_at": "2026-10-31T08:00:00Z"},
    }
    state["notch"] = {
        "trx.A": {"reference": "trx.A", "status": "complete", "amount": 25000, "currency": "XAF"},
        "trx.B": {"reference": "trx.B", "status": "complete", "amount": 25000, "currency": "XAF"},  # attendu : 30000
        "trx.C": {"reference": "trx.C", "status": "complete", "amount": 8000, "currency": "XAF"},
        "trx.D": {"reference": "trx.D", "status": "complete", "amount": 5000, "currency": "XAF"},
    }


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
        q = urllib.parse.parse_qs(u.query)
        p = u.path
        if p.startswith("/payments/") and method == "GET":
            if state["notch_down"]:
                return self.send(503, {"message": "indisponible"})
            ref = urllib.parse.unquote(p.split("/payments/")[1])
            # concurrence simulée : l'acheteur annule pendant la relecture chez le fournisseur
            if state["cancel_on_fetch"] == ref:
                for o in state["orders"].values():
                    if o["reference"] == ref: o.update(cancelled=True, cancelled_at="2026-10-31T09:00:00Z")
            tx = state["notch"].get(ref)
            return self.send(200, {"transaction": tx}) if tx else self.send(404, {"message": "introuvable"})
        if p == "/rest/v1/payment_events":
            if method == "POST":
                b = self.body()
                if b["id"] in state["events"]:
                    return self.send(409, {"code": "23505", "message": "duplicate key value violates unique constraint"})
                state["events"][b["id"]] = dict(b, outcome=None)
                return self.send(201)
            i = eq(q, "id")
            if method == "PATCH":
                if i in state["events"]: state["events"][i].update(self.body())
                return self.send(204)
            if method == "DELETE":
                state["events"].pop(i, None)
                return self.send(204)
        if p == "/rest/v1/orders":
            rows = list(state["orders"].values())
            if eq(q, "reference"): rows = [r for r in rows if r["reference"] == eq(q, "reference")]
            if eq(q, "id"): rows = [r for r in rows if r["id"] == eq(q, "id")]
            if q.get("cancelled_at", [None])[0] == "is.null": rows = [r for r in rows if r.get("cancelled_at") is None]
            if method == "GET":
                return self.send(200, rows)
            if method == "PATCH":
                rows = [r for r in rows if eq(q, "paid") is None or str(r["paid"]).lower() == eq(q, "paid")]
                b = self.body()
                for r in rows: r.update(b)
                return self.send(200, [{"id": r["id"]} for r in rows])
        self.send(404, {"message": "route simulée inconnue " + p})

    def do_GET(self): self.handle_any("GET")
    def do_POST(self): self.handle_any("POST")
    def do_PATCH(self): self.handle_any("PATCH")
    def do_DELETE(self): self.handle_any("DELETE")


def post(body, sig="auto", raw=None):
    data = raw if raw is not None else json.dumps(body).encode()
    h = {"Content-Type": "application/json"}
    if sig == "auto":
        h["x-notch-signature"] = hmac.new(HASH.encode(), data, hashlib.sha256).hexdigest()
    elif sig:
        h["x-notch-signature"] = sig
    req = urllib.request.Request(f"http://127.0.0.1:{FN_PORT}/", data=data, headers=h, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def evt(ref, t="payment.complete", extra=None):
    return {"type": t, "data": {"transaction": {"reference": ref, **(extra or {})}}}


results = []


def check(name, cond, detail=""):
    results.append((name, bool(cond), detail))
    print(("OK   " if cond else "ECHEC"), name, detail)


def main():
    srv = ThreadingHTTPServer(("127.0.0.1", MOCK_PORT), Mock)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    env = dict(os.environ, SUPABASE_URL=f"http://127.0.0.1:{MOCK_PORT}", SUPABASE_SERVICE_ROLE_KEY="service-test",
               NOTCHPAY_HASH=HASH, NOTCHPAY_KEY="cle-test", NOTCHPAY_API=f"http://127.0.0.1:{MOCK_PORT}")
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
        s, b = post(evt("trx.A"), sig=None); check("sans signature -> 401", s == 401, b)
        s, b = post(evt("trx.A"), sig="0" * 64); check("signature fausse -> 401", s == 401, b)
        check("aucune commande modifiée par un appel non signé", not state["orders"]["o1"]["paid"] and not state["events"])
        raw = json.dumps(evt("trx.A")).encode()
        reset()
        sig = hmac.new(HASH.encode(), raw, hashlib.sha256).hexdigest()
        s, b = post(None, sig=sig, raw=raw + b" "); check("signature valide d'un autre corps -> 401", s == 401, b)

        s, b = post(evt("trx.A")); check("payment.complete valide -> commande payée", s == 200 and b.get("confirmed") and state["orders"]["o1"]["paid"] and state["orders"]["o1"]["status"] == 1, b)
        s, b = post(evt("trx.A")); check("rejeu du même événement -> duplicate, sans second traitement", s == 200 and b.get("duplicate"), b)
        n = len(state["events"])
        s, b = post(evt("trx.A", extra={"n": 2})); check("autre événement sur commande déjà payée -> already_paid", s == 200 and b.get("already_paid"), b)

        s, b = post(evt("trx.B")); check("sous-paiement (25 000 < 30 000) -> non confirmé", s == 200 and b.get("confirmed") is False and "underpaid" in b.get("problems", []) and not state["orders"]["o2"]["paid"], b)
        state["notch"]["trx.B"]["amount"] = 30000; state["notch"]["trx.B"]["currency"] = "USD"
        s, b = post(evt("trx.B", extra={"n": 3})); check("devise incorrecte -> non confirmé", b.get("confirmed") is False and "currency_mismatch" in b.get("problems", []) and not state["orders"]["o2"]["paid"], b)
        state["notch"]["trx.B"].update(currency="XAF", reference="trx.AUTRE")
        s, b = post(evt("trx.B", extra={"n": 4})); check("référence du fournisseur différente -> non confirmé", b.get("confirmed") is False and "reference_mismatch" in b.get("problems", []) and not state["orders"]["o2"]["paid"], b)
        state["notch"]["trx.B"].update(reference="trx.B", status="pending")
        s, b = post(evt("trx.B", extra={"n": 5})); check("fournisseur dit « pending » malgré l'événement -> non confirmé", b.get("confirmed") is False and "not_complete" in b.get("problems", []) and not state["orders"]["o2"]["paid"], b)

        state["notch"]["trx.B"].update(status="complete", amount=30000)
        state["notch_down"] = True
        s, b = post(evt("trx.B", extra={"n": 6})); check("fournisseur injoignable -> 503 pour retentative, commande non payée", s == 503 and not state["orders"]["o2"]["paid"], b)
        state["notch_down"] = False
        s, b = post(evt("trx.B", extra={"n": 6})); check("retentative du même événement après panne -> confirmée", s == 200 and b.get("confirmed") and state["orders"]["o2"]["paid"], b)

        s, b = post(evt("trx.INCONNUE")); check("référence inconnue -> ignorée", s == 200 and b.get("ignored") == "unknown_reference", b)
        reset()
        s, b = post(evt("trx.A", t="payment.failed")); check("payment.failed -> enregistré, commande non payée", s == 200 and not state["orders"]["o1"]["paid"], b)
        s, b = post(evt("trx.A", t="payment.canceled")); check("payment.canceled -> commande non payée", not state["orders"]["o1"]["paid"], b)
        s, b = post({"type": "customer.created", "data": {"id": "c1"}}); check("événement non paiement -> ignoré", s == 200 and b.get("ignored"), b)
        s, b = post(None, raw=b"pas du json"); check("corps non JSON signé -> 400", s == 400, b)
        s, b = post(evt("trx.D")); check("paiement reçu sur une commande annulée -> non confirmé, journalisé", s == 200 and b.get("confirmed") is False and state["orders"]["o4"]["paid"] is False and any(e.get("outcome") == "paid_after_cancellation" for e in state["events"].values()), b)
        reset()
        state["cancel_on_fetch"] = "trx.A"
        s, b = post(evt("trx.A", extra={"n": 7}))
        check("annulation pendant la relecture du fournisseur -> non confirmé, journalisé", s == 200 and b.get("confirmed") is False and state["orders"]["o1"]["paid"] is False
              and any(e.get("outcome") == "paid_after_cancellation" for e in state["events"].values()), b)
        req = urllib.request.Request(f"http://127.0.0.1:{FN_PORT}/", method="GET")
        try: urllib.request.urlopen(req, timeout=10)
        except urllib.error.HTTPError as e: check("GET -> 405", e.code == 405)
    finally:
        subprocess.run(['taskkill', '/F', '/T', '/PID', str(proc.pid)], capture_output=True) if os.name == 'nt' else proc.terminate()
        srv.shutdown()
    ko = [r for r in results if not r[1]]
    print(f"\n{len(results) - len(ko)}/{len(results)} contrôles réussis")
    sys.exit(1 if ko else 0)


if __name__ == "__main__":
    main()

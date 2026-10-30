"""Test de conformité du serveur MCP (notchpay-mcp) : la vraie fonction tourne dans Deno ; Notch Pay et PostgREST sont simulés.

Vérifie le protocole (initialize, ping, tools/list, tools/call, notifications, erreurs JSON-RPC, lot) et les protections
(clé d'accès, masquage des téléphones/e-mails, validation des entrées, lecture seule).
Lancement :  python supabase/tests/mcp_e2e.py
"""
import json, os, subprocess, sys, threading, time, urllib.parse, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

KEY = "cle-acces-de-test"
MOCK, FN = 54332, 8000
FNPATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "functions", "notchpay-mcp", "index.ts")
calls = []


class Mock(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def send(self, code, body):
        raw = json.dumps(body).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(raw))); self.end_headers(); self.wfile.write(raw)

    def do_GET(self):
        u = urllib.parse.urlparse(self.path); calls.append(("GET", u.path, self.headers.get("Authorization")))
        if u.path == "/payments":
            return self.send(200, {"items": [{"reference": "trx.A", "amount": 25000, "customer": {"name": "Alice", "phone": "+237670000123", "email": "alice@example.com"}}]})
        if u.path == "/payments/trx.A":
            return self.send(200, {"transaction": {"reference": "trx.A", "status": "complete", "customer": {"phone": "+237670000123"}}})
        if u.path.startswith("/payments/"):
            return self.send(404, {"message": "introuvable"})
        if u.path == "/rest/v1/payment_events":
            return self.send(200, [{"event_type": "payment.complete", "reference": "trx.A", "outcome": "confirmed", "received_at": "2026-10-30T07:00:00Z"}])
        if u.path == "/rest/v1/orders":
            q = urllib.parse.parse_qs(u.query)
            if q.get("number") == ["eq.#BE-2026-0146"]:
                return self.send(200, [{"number": "#BE-2026-0146", "paid": True, "status": 1, "subtotal": 25000, "fee": 0, "method": "MTN Mobile Money", "reference": "trx.A"}])
            return self.send(200, [])
        self.send(404, {"message": "inconnu"})

    def do_POST(self): calls.append(("POST", self.path, None)); self.send(405, {})
    do_PATCH = do_DELETE = do_POST


def rpc(method, params=None, id=1, key=None, path="/mcp", raw=None, http="POST", bearer=None):
    body = raw if raw is not None else json.dumps({"jsonrpc": "2.0", "id": id, "method": method, **({"params": params} if params is not None else {})}).encode()
    h = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
    if bearer: h["Authorization"] = "Bearer " + bearer
    url = f"http://127.0.0.1:{FN}{path}" + (f"?key={key}" if key else "")
    req = urllib.request.Request(url, data=body if http == "POST" else None, headers=h, method=http)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            b = r.read()
            return r.status, (json.loads(b) if b else None)
    except urllib.error.HTTPError as e:
        b = e.read()
        try: return e.code, json.loads(b)
        except Exception: return e.code, b.decode()


res = []
def check(name, cond, detail=""):
    res.append(bool(cond)); print("OK    " if cond else "ECHEC ", name, "|", str(detail)[:130])


def main():
    srv = ThreadingHTTPServer(("127.0.0.1", MOCK), Mock); threading.Thread(target=srv.serve_forever, daemon=True).start()
    env = dict(os.environ, SUPABASE_URL=f"http://127.0.0.1:{MOCK}", SUPABASE_SERVICE_ROLE_KEY="service-test", NOTCHPAY_KEY="cle-notch-test",
               NOTCHPAY_API=f"http://127.0.0.1:{MOCK}", MCP_ACCESS_KEY=KEY)
    proc = subprocess.Popen(["npx", "--yes", "deno", "run", "--allow-net", "--allow-env", FNPATH], env=env, shell=(os.name == "nt"), stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    for _ in range(120):
        try: urllib.request.urlopen(f"http://127.0.0.1:{FN}/", timeout=1)
        except urllib.error.HTTPError: break
        except Exception: time.sleep(1)
    try:
        s, d = rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "test", "version": "1"}})
        r = d["result"]
        check("initialize : version négociée, capacité tools, serverInfo", s == 200 and r["protocolVersion"] == "2025-06-18" and "tools" in r["capabilities"] and r["serverInfo"]["name"], r)
        s, d = rpc("initialize", {"protocolVersion": "1999-01-01"})
        check("initialize : version inconnue -> version supportée proposée", d["result"]["protocolVersion"] in ("2025-06-18", "2025-03-26", "2024-11-05"), d["result"]["protocolVersion"])
        s, d = rpc("ping"); check("ping", d["result"] == {}, d)
        s, d = rpc("tools/list")
        names = [t["name"] for t in d["result"]["tools"]]
        check("tools/list : 4 outils, schémas JSON, tous en lecture seule", len(names) == 4 and all(t["inputSchema"]["type"] == "object" and t["annotations"]["readOnlyHint"] for t in d["result"]["tools"]), names)
        check("aucun outil de création de paiement, transfert ou remboursement", not any(w in n for n in names for w in ("create", "transfer", "refund", "send", "initiate", "charge")), names)
        s, d = rpc("notifications/initialized", id=None, raw=json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}).encode()); check("notification -> 202 sans corps", s == 202, s)
        s, d = rpc("resources/list"); check("resources/list vide", d["result"]["resources"] == [], d)
        s, d = rpc("prompts/list"); check("prompts/list vide", d["result"]["prompts"] == [], d)
        s, d = rpc("methode/inconnue"); check("méthode inconnue -> -32601", d["error"]["code"] == -32601, d)
        s, d = rpc(None, raw=b"{pas du json"); check("JSON invalide -> -32700", s == 400 and d["error"]["code"] == -32700, d)
        s, d = rpc(None, raw=b'{"id":1,"method":"ping"}'); check("requête sans jsonrpc -> -32600", d["error"]["code"] == -32600, d)

        n0 = len(calls)
        s, d = rpc("tools/call", {"name": "notchpay_list_payments", "arguments": {}})
        check("tools/call sans clé -> refusé, aucun appel sortant", d["result"]["isError"] and "refus" in d["result"]["content"][0]["text"].lower() and len(calls) == n0, d["result"]["content"][0]["text"])
        s, d = rpc("tools/call", {"name": "notchpay_list_payments", "arguments": {}}, key="mauvaise")
        check("tools/call avec mauvaise clé -> refusé", d["result"]["isError"] and len(calls) == n0, d)
        s, d = rpc("tools/call", {"name": "notchpay_list_payments", "arguments": {"limit": 5}}, key=KEY)
        t = d["result"]["content"][0]["text"]
        check("tools/call avec clé : paiements listés, téléphone et e-mail masqués", not d["result"]["isError"] and "trx.A" in t and "+237670000123" not in t and "alice@example.com" not in t and "***123" in t, t.replace("\n", " "))
        s, d = rpc("tools/call", {"name": "notchpay_list_payments", "arguments": {}}, bearer=KEY)
        check("clé acceptée aussi en Authorization: Bearer", not d["result"]["isError"], d["result"]["isError"])
        s, d = rpc("tools/call", {"name": "notchpay_get_payment", "arguments": {"reference": "trx.A"}}, key=KEY)
        check("notchpay_get_payment", "complete" in d["result"]["content"][0]["text"], d["result"]["content"][0]["text"][:80])
        s, d = rpc("tools/call", {"name": "notchpay_get_payment", "arguments": {"reference": "../../etc/passwd"}}, key=KEY)
        check("référence malveillante refusée sans appel sortant", d["result"]["isError"] and not any("passwd" in c[1] for c in calls), d["result"]["content"][0]["text"])
        s, d = rpc("tools/call", {"name": "notchpay_get_payment", "arguments": {"reference": "trx.INCONNU"}}, key=KEY)
        check("référence inconnue -> erreur d'outil lisible", d["result"]["isError"] and "introuvable" in d["result"]["content"][0]["text"], d["result"]["content"][0]["text"][:80])
        s, d = rpc("tools/call", {"name": "boutik_recent_webhook_events", "arguments": {}}, key=KEY)
        check("boutik_recent_webhook_events", "confirmed" in d["result"]["content"][0]["text"], d["result"]["content"][0]["text"][:80])
        s, d = rpc("tools/call", {"name": "boutik_order_payment_status", "arguments": {"order_number": "#BE-2026-0146"}}, key=KEY)
        tt = d["result"]["content"][0]["text"]
        check("boutik_order_payment_status : état et montant dû", '"paid": true' in tt and '"montant_du": 25000' in tt, tt.replace("\n", " ")[:100])
        s, d = rpc("tools/call", {"name": "boutik_order_payment_status", "arguments": {"order_number": "n'importe quoi"}}, key=KEY)
        check("numéro de commande invalide refusé", d["result"]["isError"], d["result"]["content"][0]["text"])
        s, d = rpc("tools/call", {"name": "outil_inexistant", "arguments": {}}, key=KEY); check("outil inconnu -> -32602", d["error"]["code"] == -32602, d)
        s, d = rpc(None, raw=json.dumps([{"jsonrpc": "2.0", "id": 1, "method": "ping"}, {"jsonrpc": "2.0", "id": 2, "method": "tools/list"}]).encode())
        check("lot JSON-RPC", isinstance(d, list) and len(d) == 2, d if not isinstance(d, list) else len(d))
        s, d = rpc(None, http="GET"); check("GET -> 405 (serveur sans état)", s == 405, s)
        check("aucune écriture sortante (lecture seule)", all(c[0] == "GET" for c in calls), [c for c in calls if c[0] != "GET"])
        check("la clé API Notch n'est transmise qu'au fournisseur", all(c[2] in (None, "cle-notch-test") for c in calls if not c[1].startswith("/rest/")), "")
    finally:
        subprocess.run(['taskkill', '/F', '/T', '/PID', str(proc.pid)], capture_output=True) if os.name == 'nt' else proc.terminate()
        srv.shutdown()
    ko = res.count(False)
    print(f"\n{len(res) - ko}/{len(res)} contrôles réussis")
    sys.exit(1 if ko else 0)


if __name__ == "__main__":
    main()

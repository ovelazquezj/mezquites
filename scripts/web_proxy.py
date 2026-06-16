"""Reverse-proxy de DEMO (CR-005): un solo origen para la web del voluntario.

Sirve el build estático de Flutter Web en `/` y proxea `/api/`, `/healthz` y `/files/`
al backend (FastAPI). Tras un único túnel ngrok HTTPS, la página y la API comparten
origen: sin contenido mixto, sin CORS, y con **contexto seguro** (cámara +
geolocalización del navegador habilitadas en el teléfono).

Parametrizado por entorno (lo invocan `scripts/appctl.ps1` / `scripts/appctl.sh`):
  PROXY_PORT   puerto local a escuchar           (def 8080)
  WEB_ROOT     carpeta del build web a servir    (def ./build/web)
  BACKEND_URL  backend al que proxear /api etc.  (def http://localhost:8000)
"""
import http.server
import os
import socketserver
import urllib.error
import urllib.request

BACKEND = os.environ.get("BACKEND_URL", "http://localhost:8000").rstrip("/")
WEBROOT = os.environ.get("WEB_ROOT", "build/web")
PORT = int(os.environ.get("PROXY_PORT", "8080"))
PROXY_PREFIXES = ("/api/", "/healthz", "/files/")
HOP = {"host", "content-length", "connection", "accept-encoding",
       "transfer-encoding", "content-encoding", "keep-alive"}


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=WEBROOT, **k)

    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".js": "text/javascript",
        ".mjs": "text/javascript",
        ".json": "application/json",
        ".wasm": "application/wasm",
        ".otf": "font/otf",
        ".ttf": "font/ttf",
    }

    def log_message(self, *a):  # silencio: el wrapper redirige stdout a un log
        pass

    def _is_proxy(self):
        return any(self.path == p or self.path.startswith(p) for p in PROXY_PREFIXES)

    def _proxy(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        req = urllib.request.Request(BACKEND + self.path, data=body, method=self.command)
        for k, v in self.headers.items():
            if k.lower() not in HOP:
                req.add_header(k, v)
        try:
            resp = urllib.request.urlopen(req, timeout=60)
            status, headers, data = resp.status, resp.getheaders(), resp.read()
        except urllib.error.HTTPError as e:
            status, headers, data = e.code, list(e.headers.items()), e.read()
        except Exception as e:  # noqa: BLE001
            self.send_response(502)
            self.end_headers()
            self.wfile.write(f"proxy error: {e}".encode())
            return
        self.send_response(status)
        for k, v in headers:
            if k.lower() not in HOP:
                self.send_header(k, v)
        self.end_headers()
        if data:
            self.wfile.write(data)

    def do_GET(self):
        return self._proxy() if self._is_proxy() else super().do_GET()

    def do_HEAD(self):
        return self._proxy() if self._is_proxy() else super().do_HEAD()

    def do_POST(self):
        return self._proxy()

    def do_PUT(self):
        return self._proxy()

    def do_DELETE(self):
        return self._proxy()

    def do_PATCH(self):
        return self._proxy()

    def do_OPTIONS(self):
        if self._is_proxy():
            return self._proxy()
        self.send_response(204)
        self.end_headers()


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    with Server(("0.0.0.0", PORT), Handler) as httpd:
        print(f"reverse-proxy :{PORT} -> web={WEBROOT} + api={BACKEND}", flush=True)
        httpd.serve_forever()

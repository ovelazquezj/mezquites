#!/usr/bin/env bash
# Controlador de la app del mezquite (FRONT + BACK) para demos y pruebas.
#   appctl.sh <start|stop|restart|status|logs> [all|backend|web|tunnel|admin] [--domain D] [--build] [--no-follow]
#
# Componentes:
#   backend  Docker Compose (postgres + redis + api)            -> http://localhost:<API_PORT>
#   web      App del VOLUNTARIO (Flutter Web) por reverse-proxy  -> tunelada por HTTPS
#   tunnel   Túnel ngrok HTTPS -> proxy (un solo origen)         -> https://<DOMAIN>
#   admin    Web-admin del consorcio (Flutter Web) estática      -> http://localhost:<ADMIN_PORT>
#
# La web del voluntario se ABRE por el túnel HTTPS (https://<DOMAIN>): así la cámara y la
# geolocalización del navegador funcionan (contexto seguro). PIDs/logs en .logs/.
set -euo pipefail

ACTION="status"; TARGET="all"
DOMAIN="component-embody-sympathy.ngrok-free.dev"
API_PORT=8000; PROXY_PORT=8080; ADMIN_PORT=5001; TAIL=80; BUILD=0; NOFOLLOW=0
_pos=()
for a in "$@"; do
  case "$a" in
    --build) BUILD=1 ;;
    --no-follow) NOFOLLOW=1 ;;
    --domain=*) DOMAIN="${a#*=}" ;;
    *) _pos+=("$a") ;;
  esac
done
[ "${#_pos[@]}" -ge 1 ] && ACTION="${_pos[0]}"
[ "${#_pos[@]}" -ge 2 ] && TARGET="${_pos[1]}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE="$ROOT/infra/compose/docker-compose.dev.yml"
MOBILE="$ROOT/mobile"; ADMIN="$ROOT/web-admin"; PROXY="$SCRIPT_DIR/web_proxy.py"
RUNDIR="$ROOT/.logs"; mkdir -p "$RUNDIR"
PUBLIC_URL="https://$DOMAIN"; WEB_API="$PUBLIC_URL/api/v1"; ADMIN_API="http://localhost:$API_PORT/api/v1"

c_info(){ printf '\033[36m%s\033[0m\n' "$*"; }
c_ok(){   printf '\033[32m%s\033[0m\n' "$*"; }
c_warn(){ printf '\033[33m%s\033[0m\n' "$*"; }
c_err(){  printf '\033[31m%s\033[0m\n' "$*"; }
head_(){  printf '\n\033[35m== %s ==\033[0m\n' "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }
rpid(){ [ -f "$RUNDIR/$1.pid" ] && cat "$RUNDIR/$1.pid" || true; }
alive(){ [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null; }
kill_pid(){ local id; id="$(rpid "$1")"; if alive "$id"; then kill "$id" 2>/dev/null || taskkill //PID "$id" //T //F >/dev/null 2>&1 || true; fi; rm -f "$RUNDIR/$1.pid"; }

build_web(){ # <dir> <api_base> <label>
  if [ "$BUILD" -eq 0 ] && [ -f "$1/build/web/index.html" ]; then
    c_info "$3: uso el build web existente (--build para reconstruir)."; return; fi
  c_info "$3: flutter build web (API_BASE_URL=$2)... (~1 min)"
  ( cd "$1" && flutter build web --dart-define=API_BASE_URL="$2" >/dev/null )
}

start_backend(){ head_ "Backend (Docker Compose)"; have docker || { c_err 'docker no está en PATH.'; return; }
  c_info 'postgres + redis + api ...'; docker compose -f "$COMPOSE" up --build -d; status_backend; }
stop_backend(){ head_ "Backend"; have docker && { docker compose -f "$COMPOSE" stop; c_ok 'Backend detenido (datos persisten).'; }; }
status_backend(){ head_ "Backend"; have docker || { c_warn 'docker no está en PATH.'; return; }
  docker compose -f "$COMPOSE" ps
  if curl -s --max-time 4 "http://localhost:$API_PORT/healthz" >/dev/null; then
    c_ok "healthz -> $(curl -s --max-time 4 http://localhost:$API_PORT/healthz)  | Swagger: http://localhost:$API_PORT/api/v1/docs"
  else c_warn 'healthz sin respuesta (backend abajo o iniciando).'; fi; }
logs_backend(){ head_ "Logs backend"; have docker || return; local f=(-f); [ "$NOFOLLOW" -eq 1 ] && f=(); docker compose -f "$COMPOSE" logs --tail "$TAIL" "${f[@]}"; }

start_web(){ head_ "Web del voluntario (proxy :$PROXY_PORT)"; have flutter || { c_err 'flutter no está en PATH.'; return; }
  build_web "$MOBILE" "$WEB_API" "web"
  if alive "$(rpid web)"; then c_warn "web ya en ejecución (restart web)."; return; fi
  PROXY_PORT="$PROXY_PORT" WEB_ROOT="$MOBILE/build/web" BACKEND_URL="http://localhost:$API_PORT" \
    nohup python "$PROXY" >"$RUNDIR/web.log" 2>&1 & echo $! >"$RUNDIR/web.pid"
  c_ok "web sirviendo en :$PROXY_PORT (PID $(rpid web)). Ábrela por el túnel: $PUBLIC_URL"; }
stop_web(){ head_ "Web del voluntario"; if alive "$(rpid web)"; then kill_pid web; c_ok 'web detenida.'; else c_warn 'web no estaba en ejecución.'; rm -f "$RUNDIR/web.pid"; fi; }
status_web(){ head_ "Web del voluntario"; if alive "$(rpid web)"; then c_ok "web EN EJECUCIÓN (PID $(rpid web)) — local http://localhost:$PROXY_PORT ; pública $PUBLIC_URL"; else c_warn 'web DETENIDA.'; fi; }
logs_web(){ head_ "Logs web"; [ -f "$RUNDIR/web.log" ] || { c_warn 'sin log.'; return; }; if [ "$NOFOLLOW" -eq 1 ]; then tail -n "$TAIL" "$RUNDIR/web.log"; else c_info '(Ctrl+C para salir)'; tail -n "$TAIL" -f "$RUNDIR/web.log"; fi; }

start_tunnel(){ head_ "Túnel ngrok ($DOMAIN) -> :$PROXY_PORT"; have ngrok || { c_err 'ngrok no está en PATH.'; return; }
  if alive "$(rpid tunnel)"; then c_warn "túnel ya en ejecución (restart tunnel)."; return; fi
  nohup ngrok http "$PROXY_PORT" --url="$PUBLIC_URL" --log "$RUNDIR/tunnel.log" --log-format logfmt >/dev/null 2>&1 & echo $! >"$RUNDIR/tunnel.pid"
  c_ok "túnel arrancado (PID $(rpid tunnel)). URL pública: $PUBLIC_URL"; }
stop_tunnel(){ head_ "Túnel ngrok"; if alive "$(rpid tunnel)"; then kill_pid tunnel; c_ok 'túnel detenido.'; else c_warn 'túnel no estaba en ejecución.'; rm -f "$RUNDIR/tunnel.pid"; fi; }
status_tunnel(){ head_ "Túnel ngrok"; if alive "$(rpid tunnel)"; then c_ok "túnel EN EJECUCIÓN (PID $(rpid tunnel)) -> $PUBLIC_URL"
    if curl -s --max-time 8 -H 'ngrok-skip-browser-warning: true' "$PUBLIC_URL/healthz" >/dev/null; then c_ok "  público healthz -> $(curl -s --max-time 8 -H 'ngrok-skip-browser-warning: true' "$PUBLIC_URL/healthz")"; else c_warn "  $PUBLIC_URL/healthz sin respuesta."; fi
  else c_warn 'túnel DETENIDO.'; fi; }
logs_tunnel(){ head_ "Logs túnel"; [ -f "$RUNDIR/tunnel.log" ] || { c_warn 'sin log.'; return; }; if [ "$NOFOLLOW" -eq 1 ]; then tail -n "$TAIL" "$RUNDIR/tunnel.log"; else c_info '(Ctrl+C para salir)'; tail -n "$TAIL" -f "$RUNDIR/tunnel.log"; fi; }

start_admin(){ head_ "Web-admin (estático :$ADMIN_PORT)"; have flutter || { c_err 'flutter no está en PATH.'; return; }
  build_web "$ADMIN" "$ADMIN_API" "admin"
  if alive "$(rpid admin)"; then c_warn "admin ya en ejecución (restart admin)."; return; fi
  nohup python -m http.server "$ADMIN_PORT" --directory "$ADMIN/build/web" --bind 0.0.0.0 >"$RUNDIR/admin.log" 2>&1 & echo $! >"$RUNDIR/admin.pid"
  c_ok "web-admin en http://localhost:$ADMIN_PORT (PID $(rpid admin)). Login: usuario/contraseña del admin (bootstrap)."; }
stop_admin(){ head_ "Web-admin"; if alive "$(rpid admin)"; then kill_pid admin; c_ok 'web-admin detenido.'; else c_warn 'web-admin no estaba en ejecución.'; rm -f "$RUNDIR/admin.pid"; fi; }
status_admin(){ head_ "Web-admin"; if alive "$(rpid admin)"; then c_ok "web-admin EN EJECUCIÓN (PID $(rpid admin)) -> http://localhost:$ADMIN_PORT"; else c_warn 'web-admin DETENIDO.'; fi; }
logs_admin(){ head_ "Logs web-admin"; [ -f "$RUNDIR/admin.log" ] || { c_warn 'sin log.'; return; }; if [ "$NOFOLLOW" -eq 1 ]; then tail -n "$TAIL" "$RUNDIR/admin.log"; else c_info '(Ctrl+C para salir)'; tail -n "$TAIL" -f "$RUNDIR/admin.log"; fi; }

printf '\n\033[97m### mezquite appctl :: %s :: %s ###\033[0m\n' "$ACTION" "$TARGET"
printf '\033[90mrepo: %s | web pública: %s | web-admin: http://localhost:%s\033[0m\n' "$ROOT" "$PUBLIC_URL" "$ADMIN_PORT"

case "$ACTION" in
  start)   case "$TARGET" in all) start_backend; start_web; start_tunnel; start_admin;; backend) start_backend;; web) start_web;; tunnel) start_tunnel;; admin) start_admin;; esac;;
  stop)    case "$TARGET" in all) stop_tunnel; stop_web; stop_admin; stop_backend;; backend) stop_backend;; web) stop_web;; tunnel) stop_tunnel;; admin) stop_admin;; esac;;
  restart) case "$TARGET" in all) stop_tunnel; stop_web; stop_admin; stop_backend; start_backend; start_web; start_tunnel; start_admin;; backend) stop_backend; start_backend;; web) stop_web; start_web;; tunnel) stop_tunnel; start_tunnel;; admin) stop_admin; start_admin;; esac;;
  status)  case "$TARGET" in all) status_backend; status_web; status_tunnel; status_admin;; backend) status_backend;; web) status_web;; tunnel) status_tunnel;; admin) status_admin;; esac;;
  logs)    case "$TARGET" in backend) logs_backend;; web) logs_web;; tunnel) logs_tunnel;; admin) logs_admin;; *) logs_backend;; esac;;
  *) c_err "Acción no válida: $ACTION"; exit 2;;
esac
echo

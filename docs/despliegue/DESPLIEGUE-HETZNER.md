# Runbook — Despliegue en **Hetzner Cloud** (servidor único, Linux) — autocontenido

> **Audiencia:** equipo de infraestructura.
> **Propósito:** desplegar **todo** el software del mezquite en **una sola VM Linux de Hetzner Cloud**,
> de principio a fin, **sin saltar a otros documentos**. Concreta el diseño todo-en-uno de
> [`CR-014`](../change-requests/CR-014-despliegue-servidor-unico.md).
> **Runbook agnóstico de referencia** (mismo stack, cualquier proveedor):
> [`DESPLIEGUE-SERVIDOR-UNICO.md`](DESPLIEGUE-SERVIDOR-UNICO.md). Aquí está todo lo necesario para Hetzner.

Última actualización: 2026-06-25.

---

## 0. Resumen

Todo corre en **una sola VM Linux de Hetzner** con 3 contenedores Docker: `caddy` (TLS automático +
sirve los 2 bundles Flutter Web, un solo origen) + `api` (FastAPI/uvicorn) + `postgres/PostGIS`.
**Sin Kubernetes, sin nube gestionada, sin Redis/YOLO** (`BROKER=memory`). Específico de Hetzner:

- **Servidor CX32** (4 vCPU / 8 GB / 80 GB SSD) — perfil *recomendado* de CR-014.
- **Cloud Volume** elástico para las **imágenes** (el disco que crece), ampliable en caliente.
- **Firewall de Hetzner** que solo deja pasar 22/80/443.
- **20 TB de tráfico incluidos** ⇒ servir fotos no cuesta egreso extra.

**Orden recomendado:** §1 prerrequisitos → §2 sizing → §3–§6 infra (VM, firewall, volumen, DNS) →
§7 Firebase → §8–§13 desplegar → §14 backups.

---

## 1. Prerrequisitos externos (los provee el patrocinador / Club)

Antes de tocar la VM, asegúrate de tener:

1. **Dominio + acceso al DNS.** Crearás dos subdominios (§6): `app.<dominio>` (voluntario) y
   `admin.<dominio>` (consola).
2. **Proyecto Firebase / Google Cloud** con *Sign in with Google* habilitado (lo configuras en §7).
   **Sin esto el público no puede autenticarse** (el `mock` no es para producción abierta).
3. **🔴 Aviso de privacidad accesible** en una URL pública. Lo exigen **dos** cosas: la **pantalla de
   consentimiento OAuth de Google** (§7.1, paso 4) y la **LFPDPPP** (ley mexicana). **El *serving* ya
   está cableado** (no hay que montar nada aparte):
   - El stack **publica el aviso** como página HTML estática en **`https://app.<dominio>/aviso-privacidad`**
     (y los términos en `https://app.<dominio>/terminos`) — Caddy las sirve **sin login y sin depender del
     SPA**, justo lo que Google verifica y la LFPDPPP exige. Artefactos: `infra/compose/legal/*.html`,
     montados en el `compose` (no requieren recompilar los bundles). Esa es **la URL** que pones en Google
     (§7.1) y que difundes para la LFPDPPP.
   - Lo único **pendiente humano** es el **texto**: hoy es **BORRADOR** ([`docs/legal/aviso-privacidad.md`](../legal/aviso-privacidad.md),
     CR-006) con el **responsable, domicilio y contacto "pendientes de definición"**. **El Club debe
     finalizarlo y aprobarlo ANTES de apuntar la verificación de Google** (Google rechaza políticas
     incompletas). Para actualizarlo: edita `docs/legal/aviso-privacidad.md` y sincroniza
     `infra/compose/legal/aviso-privacidad.html` (mismo texto; el HTML es el artefacto publicado).
   - **Esto, junto con §7, es el pendiente `CR-004 W1`** que bloquea la apertura al público.
4. **(Opcional) Proveedor SMTP** para el reset de contraseña del administrador. Si no hay, el reset
   degrada a "lo hace el administrador" (no bloquea el arranque).

> **Atajo para piloto cerrado/interno (sin Google):** puedes lanzar a un grupo controlado con
> `AUTH_PROVIDER=mock` (backend) y compilando la web con `--dart-define=AUTH_MODE=mock`. En ese modo
> **no necesitas §7 ni el aviso para Google**, pero **NO es apto para público abierto**: documenta que
> es temporal y planifica el cambio a `firebase` + aviso publicado antes de abrir.

---

## 2. Dimensionamiento para tu escenario

**Escenario de planeación:** **100 voluntarios**, **3 fotos/día c/u**, durante **lo que resta de 2026**
(del **2026-06-25** al **2026-12-31** = **190 días**).

| Magnitud | Cálculo | Valor |
|---|---|---|
| Fotos por día | 100 × 3 | **300/día** |
| Fotos en el periodo (tope) | 300 × 190 | **57 000 fotos** |
| Almacén de imágenes @ ~3 MB/foto | 57 000 × 3 MB | **~171 GB** |
| ↳ rango por tamaño de foto | @2 MB … @4 MB | ~114 … ~228 GB |
| Base de datos (57 k observaciones + índices) | filas de pocos KB | **~1–2 GB** |
| SO + Docker + imágenes base | — | **~12 GB** |
| **Total en disco (tope)** | imágenes + DB + SO | **~185 GB** |

> ⚠️ **El tope asume 100 % de participación, todos los días.** En ciencia ciudadana (referencia eBird)
> la participación real es intermitente: un ~30–50 % sostenido es más realista. A **~40 %** el almacén
> baja a **~68 GB**. **Dimensiona para el tope, opera mirando el real.**

**Decisión de disco:** el **CX32 trae 80 GB**, insuficiente para el tope. Añade un **Cloud Volume**:

- **Cómodo (provisiona una vez):** Volume de **250 GB** (cubre el tope con margen).
- **Ahorrador (empieza chico y crece):** Volume de **100 GB** y **amplíalo en caliente** conforme se
  llena (Hetzner permite *resize* hacia arriba sin downtime).

---

## 3. Crear el servidor

En la **Hetzner Cloud Console** (<https://console.hetzner.cloud>) → crea un **Proyecto** y dentro:

1. **Add Server.**
2. **Location:** elige por latencia a México. **Ashburn, VA** o **Hillsboro, OR** (EE. UU.) quedan más
   cerca de Aguascalientes que las europeas. *(EE. UU. cuesta un poco más; ver §15.)*
3. **Image (SO):** **Ubuntu 24.04 LTS** (o 22.04 LTS). x86-64.
4. **Type:** pestaña **Shared vCPU** → **CX32** (4 vCPU Intel, 8 GB, 80 GB SSD).
5. **Networking:** deja **IPv4 pública** activada (la entrada pública y el TLS de Let's Encrypt la
   necesitan). IPv6 opcional.
6. **SSH Keys:** **sube tu clave pública** (evita contraseñas).
7. **Volumes:** puedes crear aquí el volumen de imágenes (§5) o después.
8. **Firewall:** créalo ahora (§4) o aplícalo después.
9. **Name:** p. ej. `mezquite-prod`. **Create & Buy now.**

Anota la **IP pública**; la usarás en el DNS (§6).

---

## 4. Firewall de Hetzner Cloud

Crea un **Firewall** (Console → *Firewalls* → *Create Firewall*) y aplícalo al servidor. Reglas de
**entrada** (todo lo demás se descarta):

| Puerto | Protocolo | Origen | Para |
|---|---|---|---|
| 22 | TCP | **solo tu IP** (o tu rango admin) | SSH |
| 80 | TCP | `0.0.0.0/0`, `::/0` | HTTP (ACME/Let's Encrypt y redirección a HTTPS) |
| 443 | TCP | `0.0.0.0/0`, `::/0` | HTTPS (la app y la consola) |

> La **DB (5432)** y la **API (8000)** **no** se exponen: Postgres no publica puerto y la API solo
> escucha en `127.0.0.1`. No abras esos puertos.

---

## 5. Volumen de imágenes (Cloud Volume) y conexión con el `compose`

### 5.1 Crear y montar el volumen

1. Console → *Volumes* → **Create Volume** → **250 GB** (o 100 GB si empezarás chico), **misma
   location** que el servidor, **Attach to** `mezquite-prod`.
2. En el servidor (vía SSH), **formatea + monta** de forma persistente:

```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT                 # ubica el disco nuevo
VOL=/dev/disk/by-id/scsi-0HC_Volume_XXXXXXXX       # ← el tuyo (ls /dev/disk/by-id/)

sudo mkfs.ext4 -F "$VOL"                            # formatea (SOLO la 1ª vez; borra el volumen)
sudo mkdir -p /mnt/obsdata
echo "$VOL  /mnt/obsdata  ext4  discard,nofail,defaults  0  0" | sudo tee -a /etc/fstab
sudo mount /mnt/obsdata
df -h /mnt/obsdata                                  # confirma el tamaño montado
```

### 5.2 Apuntar el almacén de imágenes al volumen

El `api` guarda las fotos en `/data/storage` (`STORAGE_LOCAL_DIR`), respaldado por el volumen Docker
**`obsdata`**. Para que viva en el Cloud Volume, edita **una sola cosa** en
[`infra/compose/docker-compose.prod.yml`](../../infra/compose/docker-compose.prod.yml) — el bloque
`volumes:` del final:

```yaml
volumes:
  pgdata:
  obsdata:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/obsdata        # ← Cloud Volume de Hetzner montado en §5.1
  caddy_data:
  caddy_config:
```

> El backend corre como `root` dentro del contenedor, así que escribe en `/mnt/obsdata` sin ajustes de
> permisos. La **DB** se queda en el disco del servidor (volumen `pgdata`).

---

## 6. DNS — crear los subdominios

> **No registras (ni pagas) subdominios.** Solo tienes registrado el dominio principal
> `rescatando-el-mezquite.org`; `app.` y `admin.` son **registros DNS** dentro de su zona — gratis e
> instantáneos. Los creas en el panel de **donde administras el DNS** del dominio (tu registrador, o
> Cloudflare, o el DNS de Hetzner si delegas los *nameservers*).
>
> **Guía concreta para este proyecto (DNS en Hostinger, con la IP real):**
> [`DNS-HOSTINGER.md`](DNS-HOSTINGER.md) — paso a paso en hPanel.

Crea **dos registros A** apuntando ambos a la **misma IP pública** del servidor (la de §3):

| Tipo | Nombre / Host | Valor | TTL |
|---|---|---|---|
| A | `app`   | `<IP_DEL_SERVIDOR>` | 300 |
| A | `admin` | `<IP_DEL_SERVIDOR>` | 300 |

- Algunos paneles piden el **nombre completo** (`app.rescatando-el-mezquite.org`) y otros solo el
  **prefijo** (`app`) — es el mismo registro.
- Si la VM tiene **IPv6**, agrega además dos registros **AAAA** con la dirección IPv6.
- Deja el **TTL bajo (300 s)** al inicio para poder corregir rápido; súbelo después.

**Verifica que resuelven antes de levantar Caddy** (el TLS se emite validando este DNS):

```bash
dig +short app.rescatando-el-mezquite.org      # debe imprimir la IP del servidor
dig +short admin.rescatando-el-mezquite.org    # idem
```

### 6.1 (Opcional) Redirigir el dominio "pelón" a la app

Hoy el stack **solo** sirve `app.` y `admin.`. Si quieres que quien escriba
`https://rescatando-el-mezquite.org` (sin prefijo) **caiga en la app del voluntario**:

1. Crea un registro **A** del *apex* (`@`) → `<IP_DEL_SERVIDOR>`.
2. Agrega este bloque al [`Caddyfile`](../../infra/compose/Caddyfile) (Caddy le emitirá su propio TLS):

   ```caddy
   rescatando-el-mezquite.org {
       redir https://app.rescatando-el-mezquite.org{uri} permanent
   }
   ```

> Hazlo **solo si creas también el registro A del apex**: sin DNS, Caddy intentará emitir un certificado
> para ese nombre y fallará en bucle. Es opcional y **no** bloquea el despliegue.

---

## 7. Firebase (*Sign in with Google*) — paso a paso

> Cubre el pendiente **CR-004 W1**. Incluye un **paso de código** (generar `firebase_options.dart`),
> normalmente a cargo del equipo de desarrollo; se documenta completo para que quede reproducible.
> **Si vas con piloto cerrado (`mock`), salta esta sección** (ver el atajo del §1).
> **Nota (UI verificada 2026-06):** Google reorganizó la consola — el antiguo *"OAuth consent screen"* es
> ahora **"Google Auth Platform"** (pestañas **Público / Marca / Acceso a datos**). Los pasos de abajo ya lo reflejan.

### 7.1 Crear el proyecto y habilitar Google

1. En <https://console.firebase.google.com> → **Crear un proyecto** (anota el **Project ID**, p. ej.
   `mezquite-prod`).
2. **Authentication** (menú izquierdo, sección *Build*) → **Comenzar / Get started** → pestaña
   **Sign-in method** → **Agregar proveedor (Add new provider)** → **Google** → **Activar**; elige el
   **correo de asistencia del proyecto** → **Guardar**.
3. **Authentication → Settings → Dominios autorizados (Authorized domains):** agrega
   **`app.rescatando-el-mezquite.org`** (la consola del admin entra con usuario/contraseña, así que basta `app`).
4. **Configura el "Google Auth Platform"** ⚠️ — *aquí está el cambio*: Google **renombró y reorganizó** el
   antiguo *"OAuth consent screen"*. Ahora vive en **Google Cloud Console → APIs y servicios →
   Google Auth Platform** (Firebase también te ofrece un botón directo al activar Google). El formulario de
   una sola página se reemplazó por **pestañas**:
   - **Público (Audience):** tipo de usuario **External**. En **Testing** solo los **usuarios de prueba**
     que agregues (hasta 100) pueden entrar; para abrir al público pulsa **Publicar app** (pasar a producción).
   - **Marca (Branding):** nombre de la app, logo y correo de asistencia. En **Dominio de la app (App domain)**
     pon los enlaces (ya servidos por Caddy, §1.3):
     - **Vínculo a la política de privacidad:** `https://app.rescatando-el-mezquite.org/aviso-privacidad`
     - **Vínculo a las condiciones del servicio:** `https://app.rescatando-el-mezquite.org/terminos`
     - **Página principal:** `https://app.rescatando-el-mezquite.org`
   - **Acceso a datos (Data Access / scopes):** deja solo los básicos **`openid`, `email`, `profile`**
     (no-sensibles; no disparan verificación de marca). El backend guarda **solo el id opaco** del usuario,
     nunca correo/nombre (gate #2).

> **Por qué el aviso va en `app.<dominio>`:** Google exige que la **política de privacidad esté en el mismo
> dominio** que la app y sea pública (por eso la servimos en `/aviso-privacidad`). Sin estos enlaces **no
> deja publicar ni verificar**. Con solo scopes básicos puedes **publicar a producción**; puede aparecer un
> aviso de *"app no verificada"* (el login funciona igual) que desaparece si más adelante envías la
> **verificación de marca** (opcional para el piloto).

### 7.2 Registrar la app Web

1. Firebase → **Project settings → General → Your apps → Web (</>)** → registra la app (apodo, p. ej.
   `mezquite-voluntario-web`).
2. No copies el snippet a mano: el siguiente paso (`flutterfire configure`) trae la config.

### 7.3 Generar `firebase_options.dart` con **FlutterFire CLI** (paso de código)

Desde una máquina con **Flutter 3.27** y acceso al proyecto Firebase:

```bash
# 1) Herramientas (una vez) — requiere Node.js ≥ 18
npm install -g firebase-tools             # Firebase CLI
dart pub global activate flutterfire_cli  # FlutterFire CLI
export PATH="$PATH":"$HOME/.pub-cache/bin" # asegura el binario flutterfire en PATH

# 2) Inicia sesión con la cuenta dueña del proyecto Firebase
firebase login        # en server headless: firebase login --no-localhost

# 3) Genera la configuración DENTRO del proyecto Flutter del voluntario
cd mobile
flutterfire configure --project=<PROJECT_ID> --platforms=web,android --yes
#   ↳ crea  mobile/lib/firebase_options.dart  con la config de cada plataforma.
```

### 7.4 Cablear las opciones en el arranque de la app (edición de código)

`flutterfire configure` genera `firebase_options.dart`, pero hay que **pasar esas opciones** a
`Firebase.initializeApp` (hoy se llama sin argumentos; basta en Android nativo pero **no** en web).
En `mobile/lib/main.dart`, dentro del init condicional a `AUTH_MODE=firebase`:

```dart
import 'firebase_options.dart'; // generado por flutterfire

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

> `firebase_options.dart` **no contiene secretos** (identificadores públicos del cliente OAuth), pero
> debe estar presente al **compilar** (§9).

### 7.5 Backend: confiar en ese proyecto

En `.env.prod` (§10): `AUTH_PROVIDER=firebase` y `FIREBASE_PROJECT_ID=<PROJECT_ID>` (el backend verifica
`aud`/`iss`/`sub` del ID token de Google contra ese proyecto). No requiere credenciales de servicio.

---

## 8. Instalar Docker en el servidor

Vía SSH al servidor (Ubuntu):

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER     # reabre la sesión SSH para aplicar el grupo
docker compose version            # confirma Compose v2 (plugin `docker compose`)
```

Instala también utilidades: `sudo apt-get install -y git curl openssl`.

---

## 9. Bundles pre-compilados — build **LOCAL** + rama `deploy`

> **La VM NO compila Flutter** (CX22, 4 GB: el build se come 2–4 GB y puede tronar). El build se hace en
> tu **PC** y se publica una rama **`deploy`** = (tu rama de trabajo) + los bundles ya compilados. En la
> VM solo haces `git checkout deploy`. (El `compose up --build` en la VM solo construye la imagen del
> **backend** en Python, que sí cabe en 4 GB.)

### 9.1 En tu PC (Windows): compilar y publicar `deploy`

Requisitos locales: **Flutter 3.27**, git, y `mobile/lib/firebase_options.dart` (de §7). Tu rama de
trabajo debe estar **commiteada y empujada**. Luego corre el script:

```powershell
.\scripts\preparar-rama-deploy.ps1
#   ↳ compila los 2 bundles con el dominio del piloto y AUTH_MODE=firebase,
#     crea/actualiza la rama `deploy` con `mobile/build/web` + `web-admin/build/web`,
#     y la empuja a origin (git push --force origin deploy).
#   Piloto cerrado sin Google:  .\scripts\preparar-rama-deploy.ps1 -AuthMode mock
```

> El build es portable: **un bundle compilado en Windows corre igual en la VM Ubuntu** — son archivos
> estáticos (HTML/JS/assets) que se ejecutan en el navegador, no en el servidor. `API_BASE_URL` y
> `AUTH_MODE` se **hornean en el build**: si cambias dominio o modo de auth, vuelve a correr el script.

### 9.2 En la VM: traer los bundles (sin compilar)

```bash
git clone https://github.com/ovelazquezj/mezquites.git mezquite && cd mezquite
git checkout deploy
test -f mobile/build/web/index.html && test -f web-admin/build/web/index.html && echo "bundles OK"
```

> La imagen del backend se construye sola al levantar el compose (§11); no requiere registro de imágenes.

---

## 10. Configurar `.env.prod`

```bash
cp infra/compose/.env.prod.example infra/compose/.env.prod
nano infra/compose/.env.prod          # edita los valores (abajo)
chmod 600 infra/compose/.env.prod
openssl rand -hex 32                   # pega el resultado en AUTH_SECRET
```

Valores clave a editar (nombres exactos = `backend/app/config.py`):

| Variable | Valor |
|---|---|
| `APP_DOMAIN` / `ADMIN_DOMAIN` | `app.<dominio>` / `admin.<dominio>` |
| `ACME_EMAIL` | correo para avisos de Let's Encrypt |
| `POSTGRES_PASSWORD` + `DATABASE_URL` | misma contraseña en ambos 🔒 |
| `AUTH_SECRET` | `openssl rand -hex 32` 🔒 |
| `AUTH_PROVIDER` / `FIREBASE_PROJECT_ID` | `firebase` / `<PROJECT_ID>` (o `mock` en piloto cerrado) |
| `CORS_ALLOW_ORIGINS` | `https://app.<dominio>,https://admin.<dominio>` |
| `OBFUSCATION_GRID_M` | `300` (gate #5) |
| `BOOTSTRAP_ADMIN_*` | usuario/contraseña/email del primer admin 🔒 |

---

## 11. Levantar el stack

```bash
docker compose -f infra/compose/docker-compose.prod.yml --env-file infra/compose/.env.prod up -d --build

# Verifica
docker compose -f infra/compose/docker-compose.prod.yml ps     # caddy/api/postgres "Up"
curl -fsS http://127.0.0.1:8000/healthz                        # {"status":"ok"} (local)
curl -fsS https://app.<dominio>/healthz                        # {"status":"ok"} (vía Caddy + TLS)
```

> El primer arranque de Caddy **emite el TLS**; requiere que el DNS ya resuelva (§6) y los puertos
> 80/443 abiertos (§4). Si falla: `docker compose ... logs caddy`. La API aplica las migraciones
> Alembic al arrancar.

---

## 12. Sembrar el primer administrador (una vez)

```bash
docker compose -f infra/compose/docker-compose.prod.yml exec api \
  python -m backend.app.bootstrap --username admin --password 'CONTRASEÑA_FUERTE' --email admin@<dominio>
```

> Idempotente (alternativa: `BOOTSTRAP_ADMIN_*` en `.env.prod`). **Cambia la contraseña** tras el primer
> ingreso. Luego el administrador crea evaluador/analista desde la consola.

---

## 13. Smoke test (antes de declarar "listo")

- [ ] `https://app.<dominio>/healthz` → `{"status":"ok"}`.
- [ ] **Voluntario:** entrar con Google · capturar (cámara + GPS del navegador) · verla registrada ·
      abrir el **mapa público** (celdas ~300 m) · **Perfil → Acerca de** (versión `beta-2606`).
- [ ] **Consola** (`https://admin.<dominio>`): login del administrador · **Revisión** (confirmar/retirar/
      volver a aceptada) · **Datos y descargas** (tabla + CSV) · **Mapa** · **Instituciones** · **Acerca de**.
- [ ] La imagen de revisión **no expone GPS** salvo a `aliado_firmante` (gate #5).
- [ ] **Aviso de privacidad** carga en **`https://app.<dominio>/aviso-privacidad`** (HTTPS, sin login) y
      es el enlace puesto en el consentimiento de Google (§1.3, §7.1). `curl -fsS https://app.<dominio>/aviso-privacidad`
      devuelve la página. Igual `/terminos`.
- [ ] Backup de DB generado y **restauración probada** (§14).

---

## 14. Backups en Hetzner

Combina **dos mecanismos** (la DB es lo crítico; las imágenes son grandes):

1. **Backups automáticos del servidor** (Console → servidor → *Backups*, **+20 %** del precio): snapshots
   del **disco del SO + `pgdata`**. **No** respaldan el Cloud Volume.
2. **`pg_dump` lógico** (cron diario) — el respaldo más importante; cópialo **fuera del host**:

   ```bash
   docker compose -f infra/compose/docker-compose.prod.yml exec -T postgres \
     pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > /backups/mezquite-$(date +%F).sql.gz
   ```
3. **Snapshot del Cloud Volume** (Console → Volume → *Snapshot*, ~€0.0118/GB·mes) para punto-en-tiempo de
   las **imágenes** (opcional; los Volumes ya están replicados).

> **Antes de abrir al público:** genera un backup y **prueba la restauración** al menos una vez.

---

## 15. Costos (Hetzner Cloud, mensual)

Precios de lista a mediados de 2026 (ubicaciones UE; **EE. UU. ~5–10 % más**). **Verifica en la consola.**
**Tráfico de salida: 20 TB incluidos** ⇒ **€0** de egreso para este escenario.

### 15.1 Tu escenario (100 voluntarios · 3 fotos/día · 190 días)

| Componente | Detalle | €/mes | ~USD/mes |
|---|---|---|---|
| Servidor **CX32** | 4 vCPU, 8 GB, 80 GB SSD (incl. 20 TB tráfico) | **6.80** | ~7.40 |
| IPv4 primaria | requerida para la entrada pública | **0.60** | ~0.65 |
| **Cloud Volume 250 GB** | imágenes (elástico) — 250 × €0.044 | **11.00** | ~12.00 |
| Backups del servidor | +20 % del CX32 (SO + DB) | **1.36** | ~1.50 |
| *(opcional)* Snapshot del Volume | ~250 GB × €0.0118 | *~2.95* | *~3.20* |
| Egreso (servir fotos) | 20 TB incluidos | 0.00 | 0.00 |
| **Total** | con Volume 250 GB | **~€19.8** | **~$21** |
| **Total** | + snapshot del Volume | **~€22.7** | **~$25** |

**Costo de todo el periodo (~6.25 meses):** **~€124** (≈ **$135**) sin snapshot; **~€142** (≈ **$155**) con.

> 💡 **Ahorro:** el Volume se llena gradual. Provisiónalo en **100 GB** (€4.40/mes) y **amplíalo**
> conforme crece (el almacén llega a ~171 GB recién en diciembre); el promedio del periodo baja varios €/mes.

### 15.2 Si fuera el perfil mínimo (piloto chico)

| Componente | Detalle | €/mes |
|---|---|---|
| Servidor **CX22** | 2 vCPU, 4 GB, 40 GB SSD | 4.59 |
| IPv4 primaria | — | 0.60 |
| Cloud Volume 100 GB | imágenes | 4.40 |
| Backups del servidor | +20 % | 0.92 |
| **Total** | | **~€10.5** (~$11.4) |

---

## 16. Crecer y cuándo escalar

- **Más disco:** amplía el **Cloud Volume** (Console → *Resize*) y luego `sudo resize2fs /mnt/obsdata`.
  Sin downtime.
- **Más carga:** sube el tipo de servidor (CX32 → **CX42** 8 vCPU/16 GB) con un *rescale*. El código no cambia.
- **Alta disponibilidad / RPO-RTO estrictos:** migra a la ruta gestionada
  ([`CR-008` Azure](../change-requests/CR-008-despliegue-azure.md)) o K8s — **solo flips de config**
  (`STORAGE_BACKEND`, `DATABASE_URL`, `BROKER`), gate #6.

---

*Referencias:* [`DESPLIEGUE-SERVIDOR-UNICO.md`](DESPLIEGUE-SERVIDOR-UNICO.md) (runbook agnóstico) ·
[`CR-014`](../change-requests/CR-014-despliegue-servidor-unico.md) (diseño) ·
[`CR-004`](../change-requests/CR-004-firebase-ios-cors.md) · [`docs/legal/aviso-privacidad.md`](../legal/aviso-privacidad.md) (borrador del aviso) ·
[`infra/compose/docker-compose.prod.yml`](../../infra/compose/docker-compose.prod.yml) ·
[`infra/compose/.env.prod.example`](../../infra/compose/.env.prod.example) ·
[`infra/compose/Caddyfile`](../../infra/compose/Caddyfile).

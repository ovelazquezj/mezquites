# CR-015 — Autenticación con Google **sin Firebase** (Google Identity Services)

| Campo | Valor |
|---|---|
| **ID** | CR-015 |
| **Fecha** | 2026-06-28 |
| **Estado** | ✅ **Implementado en `main` + desplegado en la VM** (modo Testing de Google Cloud) |
| **Alcance** | `mobile/` · `backend/` · `scripts/` · `infra/compose/` (config) |
| **Relación** | **Amend de CR-002** (auth identidad) · **cierra CR-004 W1** por una vía distinta (sin Firebase) |
| **Ejecución** | Directo sobre `main`, por el orquestador |

## 1. Contexto

CR-002/CR-004 W1 asumían **Firebase** para "Entrar con Google". Al configurarlo, el usuario hizo el
OAuth **directamente en Google Cloud (APIs y servicios)**, sin crear proyecto Firebase. Por tanto no hay
`Project ID`/`apiKey` de Firebase: el login se resuelve con **Google Identity Services (GIS)** y el
backend verifica un **ID token de Google "puro"**.

## 2. Decisiones del usuario (2026-06-28)
1. Auth **sin Firebase** (OAuth ya configurado en Google Cloud).
2. Web Client ID entregado: `280536104241-q1b2h58avkcf3jv3oke4pi7gghg24fnh.apps.googleusercontent.com`.
3. Probar en **modo Testing** (usuarios de prueba) antes de publicar.

## 3. Qué se hizo
| Pieza | Detalle |
|---|---|
| App (`mobile/`) | Se quitó `firebase_core`/`firebase_auth`; se usa `google_sign_in` 7.x + `google_sign_in_web`. En **WEB** el login usa el **botón GIS** (`renderButton`) + `authenticationEvents`, que entrega el **ID token de Google**; se elimina el paso por Firebase. `google_auth_service.dart` (GIS), `app_config.dart` (`AUTH_MODE`, `GOOGLE_WEB_CLIENT_ID`, `usesGoogleSignIn`), `providers.dart` (`completeGoogleSignIn`), `welcome_screen.dart` (botón GIS + suscripción a eventos), `main.dart` (init GIS condicional). |
| Backend | `FirebaseAuthProvider` ya verificaba tokens de Google "puros" (`iss=accounts.google.com`, `aud=Web Client ID`); se agregó `google-auth` + `requests` a `pyproject.toml`. Config de prod: `AUTH_PROVIDER=firebase` + `GOOGLE_OAUTH_AUDIENCE=<web client id>`, **sin** `FIREBASE_PROJECT_ID` (así solo se acepta el emisor Google). |
| Build/deploy | `scripts/preparar-rama-deploy.ps1`: `-AuthMode google` + `-ClientId`; `--dart-define=AUTH_MODE=google` + `GOOGLE_WEB_CLIENT_ID`. `.env.prod.example`: sección de auth en modo Google. |

## 4. Gates
- **Gate #2 acotado (sin PII):** **intacto y reafirmado** — la app solo entrega el ID token; el backend
  guarda **solo el `sub` opaco** (descarta email/nombre del token). Cambia el *mecanismo* (GIS en vez de
  Firebase), no la propiedad.
- **Gate #6 (auth conmutable):** intacto — `AUTH_MODE=mock`/`AUTH_PROVIDER=mock` siguen para dev/test
  sin red; `google` para prod.
- Resto de gates: sin cambios.

## 5. Verificación (en vivo)
- `POST /auth/google` con un token mock → **401** (el verificador real de Google está activo; el mock ya
  no se acepta).
- El **Web Client ID** queda horneado en el bundle servido (build GIS en vivo).
- Login con Google real **funciona** en navegador (Android), con la cuenta agregada como *test user*.

## 6. Pendiente (decisión humana, en la consola de Google Cloud)
- **Orígenes autorizados de JavaScript** del cliente OAuth = `https://app.rescatando-el-mezquite.org`.
- **Usuarios de prueba** (Audience) mientras la app esté en **Testing**; para abrir al público, publicar
  la app (estado Production) — requiere el aviso de privacidad publicado (ya está en `/aviso-privacidad`).

## 7. Notas
- La frontera de Firebase (`firebase_options.dart`, `google-services.json`) **ya no es necesaria**.
- CR-004 W1 queda **cerrado por esta vía** (no se usará Firebase).

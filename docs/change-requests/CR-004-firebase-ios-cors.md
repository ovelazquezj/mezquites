# CR-004 — Cierres de producción: Google/Firebase real · iOS · CORS

| Campo | Valor |
|---|---|
| **ID** | CR-004 |
| **Título** | Activar Google/Firebase real, añadir plataforma iOS y habilitar CORS |
| **Fecha** | 2026-06-16 |
| **Estado** | **W3 (CORS) ✅ integrado** · **W1 (Firebase) pendiente** (bloquea auth pública) · **W2 (iOS) DIFERIDO/OPCIONAL** (2026-06-16: la web cubre iPhone vía Safari) |
| **Prioridad** | Media (cierres para salir de "solo dev/mock") |
| **Depende de** | CR-002 (auth) integrado · CR-003 (branding) integrado |
| **Alcance** | App Flutter + backend (config/middleware). **Sin** cambios al modelo de revisión humana (CR-001). |

---

## 1. Contexto

Tras CR-001/002/003 quedaron tres cierres conocidos para pasar de "solo dev/mock" a algo desplegable:
**W1** Google real (hoy `MockAuthProvider`), **W2** plataforma iOS (el repo es Android-only) y **W3**
CORS (el web admin se arranca con un workaround de Chrome). Son **independientes** entre sí y pueden
ejecutarse en cualquier orden o en paralelo.

## 2. Gates

**Este CR NO enmienda gates.** W1 se mantiene dentro del **gate #2 acotado** (app = solo `sub` opaco,
sin email/nombre). W2 mantiene el **gate #4** (cámara nativa + EXIF) también en iOS. W3 es
infraestructura. Gates #3/#5/#6/#7 intactos.

---

## 3. W1 — Activar Google / Firebase real

**Objetivo:** que la app autentique con Google real en QA/Prod, conmutando `AUTH_PROVIDER=firebase`
(el mock sigue para dev/test, gate #6).

**Prerrequisitos del usuario (bloqueantes para activar; el código se prepara sin ellos):**
1. Proyecto **Firebase** (Google Cloud) con Authentication → Google habilitado (define **H6**).
2. App Android registrada: package `com.mezquite.app` + **huellas SHA-1/SHA-256** (debug + release).
3. **`google-services.json`** en `mobile/android/app/`.
4. Pantalla de **consentimiento OAuth** (`openid email profile`).
5. **Aviso de privacidad** + **borrado de datos** publicados (Google/Play, LFPDPPP).

**Software (lo prepara el equipo):**
- Backend: completar `FirebaseAuthProvider` (verificación real del ID token contra llaves de Google /
  Firebase Admin), parámetros `GOOGLE_OAUTH_AUDIENCE`/`FIREBASE_PROJECT_ID` por entorno; `AUTH_PROVIDER=firebase`
  en overlays QA/Prod.
- Móvil: init real de Firebase cuando exista `google-services.json`; `AUTH_MODE=firebase` en builds
  QA/Prod; el camino mock se conserva para dev/test.
- Docs: actualizar `docs/auth.md` y `docs/DESPLIEGUE.md` con el procedimiento de activación.

**Archivos:** `backend/app/auth_provider.py`, `config.py`, overlays `infra/k8s/overlays/{stg,prod}`,
`mobile/lib/src/services/google_auth_service.dart`, `mobile/android/app/`, `docs/`.

**Aceptación:** con credenciales reales, login con cuenta Google funciona en un dispositivo; sin
ellas, dev/test siguen verdes con el mock; **ninguna cuenta voluntario guarda email/nombre** (gate #2).

**Riesgo:** SHA de release equivocada → "Entrar con Google" falla solo en el APK firmado; validar con
el APK de release real.

---

## 4. W2 — Plataforma iOS

> **DIFERIDO / OPCIONAL (decisión del usuario, 2026-06-16).** El lanzamiento va **web-first**: la app
> web de Flutter corre en **iPhone vía Safari** (sin App Store), y el código de captura ya detecta
> iOS-web (`isMobileWebBrowser()` ⇒ cámara habilitada en Safari móvil, gate #4 intacto). Por eso **W2
> NO es requerido para el lanzamiento**. Solo haría falta para una **app nativa en la App Store**,
> **notificaciones push** (que iOS-web casi no soporta) u **offline-first**.
>
> **Pendiente para confirmar que la web cubre iOS:** un **smoke test en un iPhone/Safari real** — abrir
> la URL → **cámara** → **geolocalización del navegador** (Safari borra el EXIF-GPS, por eso la
> ubicación viene del API de geolocalización, no del EXIF) → **Entrar con Google** (flujo OAuth web).
> Hasta ahora solo se validó en Android. Mientras eso no se pruebe, "la web cubre iPhone" es un
> supuesto razonable pero **no verificado**.

**Objetivo (si algún día se retoma):** que la app compile y corra en iOS con el branding de CR-003.

**Tareas:**
- `cd mobile && flutter create --platforms=ios .` para generar `mobile/ios/` (Runner).
- Reactivar en `flutter_launcher_icons`/`flutter_native_splash` el target **iOS** (`ios: true`,
  `remove_alpha_ios: true`) y regenerar AppIcon + LaunchScreen; verificar AppIcon **sin canal alfa**.
- `Info.plist`: permisos de **cámara** (`NSCameraUsageDescription`) y **ubicación**
  (`NSLocationWhenInUseUsageDescription`) — gate #4.
- Firebase iOS (si W1): `GoogleService-Info.plist` + config; init condicional como en Android.
- Build: `flutter build ios --no-codesign` (CI) o firmado en macOS.

**Prerrequisito:** **macOS + Xcode** para compilar/firmar iOS (no se puede en Windows/CI sin runner mac).

**Archivos:** `mobile/ios/**` (nuevo), config de los dos paquetes, `mobile/pubspec.yaml`.

**Aceptación:** `flutter build ios` compila; AppIcon sin alfa; splash y onboarding correctos; captura
por cámara y EXIF funcionan en iOS (gate #4).

**Riesgo:** firma/perfiles de aprovisionamiento Apple (cuenta de desarrollador) — fuera del software.

---

## 5. W3 — CORS

**Objetivo:** que el web admin (y un eventual FE web) hablen con la API **sin** el workaround de Chrome.

**Tareas:**
- Backend: habilitar `CORSMiddleware` en `backend/app/main.py` con **orígenes por entorno** (config
  `CORS_ALLOW_ORIGINS`, p. ej. `http://localhost:*` en dev, dominios reales en QA/Prod).
- Quitar de la guía/scripts el `--disable-web-security` de Chrome (QUICKSTART Parte 3, `manage.ps1`).
- Pruebas: una prueba de que responde los headers CORS a un origen permitido y los niega a otro.

**Archivos:** `backend/app/main.py`, `config.py`, `backend/tests/test_cors.py` (nuevo), overlays K8s
(variable de orígenes), `QUICKSTART.md`, `scripts/manage.ps1`, `docs/DESPLIEGUE.md`.

**Aceptación:** el web admin carga datos desde Chrome **normal** (sin flags); preflight OPTIONS y
headers `Access-Control-Allow-Origin` correctos por entorno; orígenes no permitidos rechazados.

**Riesgo:** abrir CORS de más → restringir por entorno (nunca `*` con credenciales en prod).

---

## 6. Desglose por agente

| # | Agente | Unidad | Archivos | Pruebas |
|---|---|---|---|---|
| D1 | Dev backend | W1 FirebaseAuthProvider real + config/overlays | `auth_provider.py`, `config.py`, overlays | mock sigue verde; firebase tras credenciales |
| D2 | Dev móvil | W1 init real condicional | `google_auth_service.dart`, `android/app/` | build con/sin `google-services.json` |
| D3 | Dev móvil | W2 scaffold iOS + ícono/splash iOS + Info.plist | `mobile/ios/**`, configs | `flutter build ios` (en macOS) |
| D4 | Dev backend | W3 CORSMiddleware + prueba | `main.py`, `config.py`, `test_cors.py` | preflight + orígenes |
| D5 | Documentador | quitar workaround Chrome; actualizar auth/DESPLIEGUE/QUICKSTART | docs, `scripts/` | enlaces al día |

## 7. Definition of Done

- `AUTH_PROVIDER=mock` sigue verde offline; `firebase` documentado y listo para credenciales (W1).
- iOS compila y respeta gate #4 (W2, en macOS).
- Web admin sin flags de Chrome; CORS por entorno con prueba (W3).
- Sin cambios al modelo de revisión humana (CR-001); gates intactos.

> **Estado:** propuesto para tu revisión. Al aprobarlo lo agrego al índice y, si quieres, lo ejecuto
> por workstreams (W1/W2/W3 son independientes; W2 requiere macOS).

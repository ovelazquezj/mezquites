import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/enums.dart';
import '../models/models.dart';
import 'api_exception.dart';

/// Cliente de la API REST `/api/v1` del backend del mezquite.
///
/// Refleja `backend/app/routers/*` y `backend/app/schemas.py`: nombres de campo
/// y rutas EXACTOS. Auth por bearer token (CR-002: identidad real, gate #2 acotado).
///
/// Endpoints cubiertos:
///   auth/google (login social), observations (multipart), observations/mine,
///   me/feedback, me/profile, gamification/rankings, public/observations,
///   public/indicators, institutions (lista F3) + institutions/request (CR-010 #6),
///   me/sessions + me/evidence (CR-010 #7).
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Base sin barra final, p.ej. `http://10.0.2.2:8000/api/v1`.
  final String baseUrl;
  final http.Client _http;

  String? _token;

  /// Fija el bearer token tras login/registro/recover.
  void setToken(String? token) => _token = token;

  /// CR-035: se invoca ante un 401 **con token puesto** — la señal reactiva de
  /// "la sesión venció". El guard `_token != null` importa: sin token no hay
  /// sesión que vencer (un login fallido desde un dispositivo limpio también
  /// responde 401 y NO debe encender el aviso). Un re-login fallido con el token
  /// viejo aún en memoria sí re-dispara — idempotente e inocuo, el flag ya
  /// estaba encendido.
  void Function()? onSessionExpired;

  void _avisarSiSesionVencida(http.Response r) {
    if (r.statusCode == 401 && _token != null) onSessionExpired?.call();
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
        // Evita la página intersticial de ngrok-free en túneles de demo.
        // Backends que no son ngrok ignoran este header.
        'ngrok-skip-browser-warning': 'true',
      };

  Map<String, dynamic> _decode(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return r.body.isEmpty
          ? <String, dynamic>{}
          : (json.decode(r.body) as Map).cast<String, dynamic>();
    }
    _avisarSiSesionVencida(r);
    throw ApiException(r.statusCode, 'Error de la API', body: r.body);
  }

  List<dynamic> _decodeList(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return json.decode(r.body) as List<dynamic>;
    }
    _avisarSiSesionVencida(r);
    throw ApiException(r.statusCode, 'Error de la API', body: r.body);
  }

  // --- Auth con identidad real (CR-002, gate #2 acotado) ---

  /// Login social: envía el ID token de Google a `POST /auth/google`. El backend lo verifica y
  /// devuelve nuestro JWT + el handle de presentación. La app NO manda email/nombre: solo el ID
  /// token (el backend guarda únicamente el `sub` opaco). [institutionId] null => "Independiente".
  Future<AuthSession> loginWithGoogle({
    required String idToken,
    String? institutionId,
  }) async {
    final r = await _http.post(
      _uri('/auth/google'),
      headers: _headers(),
      body: json.encode({
        'id_token': idToken,
        if (institutionId != null) 'institution_id': institutionId,
      }),
    );
    final session = AuthSession.fromToken(_decode(r));
    _token = session.token;
    return session;
  }

  // --- Observaciones ---

  /// Envía una observación (multipart: `payload` JSON con 8 etiquetas + `image`).
  ///
  /// CR-031: devuelve [SubmitResult] en vez del id suelto, porque ahora hay dos
  /// desenlaces buenos distintos: **201** (se creó) y **200 + `ya_existia`** (era el
  /// reintento de una captura que sí había llegado, y el servidor devolvió la
  /// original en vez de duplicar el árbol). Los dos significan "ya está a salvo en
  /// el servidor", así que los dos permiten borrarla del teléfono.
  ///
  /// Propaga `ApiException` con el código HTTP: el motor de subida decide según él
  /// (5xx reintenta, 422 necesita atención, 401 pausa, 410 borra la cola).
  Future<SubmitResult> submitObservation(ObservationDraft draft) async {
    final request = http.MultipartRequest('POST', _uri('/observations'));
    request.headers['ngrok-skip-browser-warning'] = 'true';
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.fields['payload'] = json.encode(draft.toPayloadJson());
    // Web: la cámara del navegador entrega bytes (no hay ruta de archivo).
    // Móvil nativo: ruta del JPEG con EXIF. (CR-005)
    if (draft.imageBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('image', draft.imageBytes!,
            filename: 'observacion.jpg',),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath('image', draft.imagePath!),
      );
    }
    final streamed = await _http.send(request);
    final r = await http.Response.fromStream(streamed);
    final body = _decode(r);
    return SubmitResult(
      observationId: body['observation_id'] as String,
      yaExistia: body['ya_existia'] as bool? ?? false,
    );
  }

  /// Historial propio. SIN estado de validación individual (gate #9).
  Future<List<MineObservation>> myObservations() async {
    final r = await _http.get(_uri('/observations/mine'), headers: _headers());
    return _decodeList(r)
        .map((e) => MineObservation.fromJson((e as Map).cast()))
        .toList();
  }

  // --- Feedback / perfil ---

  /// Feedback AGREGADO de tasa de validación (gate #9).
  Future<FeedbackAggregate> feedback() async {
    final r = await _http.get(_uri('/me/feedback'), headers: _headers());
    return FeedbackAggregate.fromJson(_decode(r));
  }

  Future<Profile> profile() async {
    final r = await _http.get(_uri('/me/profile'), headers: _headers());
    return Profile.fromJson(_decode(r));
  }

  // --- Gamificación ---

  Future<Rankings> rankings({String period = 'all', String? estado}) async {
    final r = await _http.get(
      _uri('/gamification/rankings', {
        'period': period,
        if (estado != null) 'estado': estado,
      }),
      headers: _headers(),
    );
    return Rankings.fromJson(_decode(r));
  }

  // --- Geografía derivada (CR-036) ---

  /// Pregunta al servidor a qué estado/municipio pertenece un punto.
  ///
  /// Solo sirve para MOSTRARLE al voluntario dónde va a quedar su registro: la ubicación que se
  /// guarda la resuelve el servidor otra vez al recibir el POST. Por eso, si esto falla —sin señal,
  /// que es lo normal en campo— **no pasa nada**: se devuelve `null`, la pantalla enseña las
  /// coordenadas y la captura sigue su curso (CR-031).
  Future<GeoLugar?> geoResolve({required double lat, required double lon}) async {
    try {
      final r = await _http.get(
        _uri('/geo/resolve', {'lat': '$lat', 'lon': '$lon'}),
        headers: _headers(),
      );
      if (r.statusCode != 200) return null;
      return GeoLugar.fromJson(_decode(r));
    } catch (_) {
      return null;
    }
  }

  /// Catálogo de entidades federativas con límites cargados (CR-036).
  Future<List<String>> geoEstados() async {
    final r = await _http.get(_uri('/geo/estados'), headers: _headers());
    return _decodeList(r)
        .map((e) => (e as Map)['estado'] as String)
        .toList();
  }

  // --- Vistas de datos públicas ---

  /// Observaciones públicas individuales con la ubicación del mezquite
  /// (presentación pública, CR-025). Sin auth (endpoint `public/*`).
  Future<List<PublicObservation>> publicObservations({
    String? estado,
    int limit = 500,
    int offset = 0,
  }) async {
    final r = await _http.get(
      _uri('/public/observations', {
        if (estado != null) 'estado': estado,
        'limit': '$limit',
        'offset': '$offset',
      }),
      headers: _headers(json: false),
    );
    return _decodeList(r)
        .map((e) => PublicObservation.fromJson((e as Map).cast()))
        .toList();
  }

  /// Dataset público COMPLETO (CR-034): recorre `/public/observations` con
  /// `offset` en páginas del tope del backend (5000) hasta la página corta.
  /// Un `limit` solo, sin lazo, era un tope silencioso: el mapa dejaba de
  /// pintar árboles al rebasarlo.
  Future<List<PublicObservation>> publicObservationsAll({
    String? estado,
  }) async {
    const porPagina = 5000;
    final todas = <PublicObservation>[];
    var offset = 0;
    while (true) {
      final p = await publicObservations(
        estado: estado,
        limit: porPagina,
        offset: offset,
      );
      todas.addAll(p);
      if (p.length < porPagina) return todas;
      offset += porPagina;
    }
  }

  /// Mapa de calor público (CR-009): celdas de ~300 m (binning de agregación
  /// server-side). Agrega solo observaciones NO RECHAZADAS. Sin auth
  /// (endpoint `public/*`; `_headers(json:false)` no exige token).
  ///
  /// CR-034: default = 5000, el tope del backend (es el máximo de FILAS que
  /// escanea el binning, no de celdas; la deuda de agregar sin tope queda
  /// anotada para cuando el piloto rebase 5000 confirmadas).
  /// CR-036: sin `limit`. El backend agrega el mapa de calor en SQL y ya no escanea un tope de
  /// filas, así que el mapa del voluntario deja de truncarse en silencio al crecer el dataset —
  /// la última deuda que quedaba viva de CR-034.
  Future<List<GridCell>> publicGrid({String? estado}) async {
    final r = await _http.get(
      _uri('/public/grid', {
        if (estado != null) 'estado': estado,
      }),
      headers: _headers(json: false),
    );
    return _decodeList(r)
        .map((e) => GridCell.fromJson((e as Map).cast()))
        .toList();
  }

  Future<Indicators> publicIndicators({String? estado}) async {
    final r = await _http.get(
      _uri('/public/indicators', {if (estado != null) 'estado': estado}),
      headers: _headers(json: false),
    );
    return Indicators.fromJson(_decode(r));
  }

  // --- Instituciones (lista F3) ---
  //
  // Catálogo público (GET /institutions): instituciones APROBADAS, sin auth, para
  // que el voluntario elija afiliación en el alta (Q4). Las solicitadas viven en
  // /admin/institutions (rol admin). Si la red falla, la UI degrada a
  // "Independiente" + "solicitar agregar" (ticket).
  Future<List<Institution>> listInstitutions() async {
    final r = await _http.get(_uri('/institutions'), headers: _headers(json: false));
    if (r.statusCode != 200) {
      return const <Institution>[];
    }
    return _decodeList(r)
        .map((e) => Institution.fromJson((e as Map).cast()))
        .toList();
  }

  /// Registrar una nueva institución (CR-010 #6). El voluntario autenticado
  /// la propone; queda `solicitada` hasta que el consorcio la apruebe (no entra
  /// al catálogo público hasta entonces). Devuelve la institución creada.
  ///
  /// CR-028: si ya existía una con el mismo nombre (sin acentos, minúsculas,
  /// espacios colapsados) el backend NO crea otra — afilia la cuenta a la que ya
  /// está y responde 200 con `ya_existia: true`. Nunca es un error: el catálogo
  /// público solo lista las aprobadas, así que el voluntario no tiene forma de
  /// ver una institución en revisión para elegirla.
  Future<Institution> requestInstitution({
    required String name,
    String? estado,
  }) async {
    final r = await _http.post(
      _uri('/institutions/request'),
      headers: _headers(),
      body: json.encode({
        'name': name,
        if (estado != null) 'estado': estado,
      }),
    );
    return Institution.fromJson(_decode(r));
  }

  // --- Sesiones de participación + evidencia (CR-010 #7) ---

  /// Registra una sesión de participación (tiempo en foreground entre
  /// login/logout o resume/pause). Gate #2: solo tiempos, sin PII (el backend
  /// asocia por la cuenta del token). Fire-and-forget: la UI no debe bloquear.
  Future<void> postSession({
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    final r = await _http.post(
      _uri('/me/sessions'),
      headers: _headers(),
      body: json.encode({
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
      }),
    );
    // 201 esperado; _decode valida el rango 2xx y lanza si no.
    _decode(r);
  }

  /// Comprobante de participación AGREGADO (CR-010 #7): capturas, horas
  /// acumuladas, nº de sesiones y rango de fechas. Sin PII (gate #2).
  Future<Evidence> evidence() async {
    final r = await _http.get(_uri('/me/evidence'), headers: _headers());
    return Evidence.fromJson(_decode(r));
  }

  // --- Reportar un problema (CR-019) ---

  /// Envía un reporte de problema con diagnóstico técnico SIN PII (gate #2: nunca email/nombre;
  /// `userAgent`/`platform`/`appVersion` son metadatos técnicos aceptables). Auth OPCIONAL
  /// (gate #3): `_headers()` adjunta el token solo si existe; sin token el reporte va anónimo.
  /// El backend responde 201; propaga [ApiException] si falla para que la UI muestre `reportFailed`.
  Future<void> submitProblemReport({
    String? note,
    String? context,
    String? errorDetail,
    required String userAgent,
    required String platform,
    required String appVersion,
  }) async {
    final r = await _http.post(
      _uri('/problem-reports'),
      headers: _headers(),
      body: json.encode({
        'user_agent': userAgent,
        'platform': platform,
        'app_version': appVersion,
        'context': (context == null || context.isEmpty) ? 'general' : context,
        if (note != null && note.isNotEmpty) 'message': note,
        if (errorDetail != null && errorDetail.isNotEmpty)
          'error_detail': errorDetail,
      }),
    );
    // 201 esperado; _decode valida el rango 2xx y lanza ApiException si no.
    _decode(r);
  }

  void close() => _http.close();
}

/// Mapea un enum del vocabulario a su valor de wire (defensivo para llamadas
/// dinámicas en pruebas).
String wireOfNivel(NivelG4 n) => n.wire;

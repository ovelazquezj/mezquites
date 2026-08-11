import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'api_exception.dart';

/// Cliente de la API REST `/api/v1` del backend del mezquite, para la web admin.
///
/// Refleja `backend/app/routers/*` y `backend/app/schemas.py`: rutas y nombres
/// de campo EXACTOS. Auth por bearer token (sin PII, gate #2). Reimplementado
/// para la web admin; no se importa el cliente del móvil.
///
/// Endpoints cubiertos (rol admin_consorcio salvo donde se indique):
///   POST /auth/recover (público)
///   GET  /admin/institutions · POST /admin/institutions
///   POST /admin/allies
///   POST /admin/indicators/organizational
///   POST /admin/snapshots
///   GET  /public/observations (público) · GET /public/indicators (público)
///   GET  /restricted/observations (rol aliado_firmante/autorizado)
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Base sin barra final, p.ej. `http://localhost:8000/api/v1`.
  final String baseUrl;
  final http.Client _http;

  String? _token;

  /// Fija el bearer token tras login/recover (o token pegado).
  void setToken(String? token) => _token = token;

  String? get token => _token;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Map<String, dynamic> _decode(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return r.body.isEmpty
          ? <String, dynamic>{}
          : (json.decode(r.body) as Map).cast<String, dynamic>();
    }
    throw ApiException(r.statusCode, 'Error de la API', body: r.body);
  }

  List<dynamic> _decodeList(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return json.decode(r.body) as List<dynamic>;
    }
    throw ApiException(r.statusCode, 'Error de la API', body: r.body);
  }

  // --- Auth con identidad real (CR-002) ---

  /// Login de los roles de backend: usuario + contraseña → token (POST /auth/login).
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final r = await _http.post(
      _uri('/auth/login'),
      headers: _headers(),
      body: json.encode({'username': username, 'password': password}),
    );
    final session = AuthSession.fromToken(_decode(r));
    _token = session.token;
    return session;
  }

  // --- Gestión de usuarios por el administrador (CR-002) ---

  /// Lista de usuarios de backend (sin exponer email; solo `has_email`).
  Future<List<BackendUser>> listUsers() async {
    final r = await _http.get(_uri('/admin/users'), headers: _headers(json: false));
    return _decodeList(r)
        .map((e) => BackendUser.fromJson((e as Map).cast()))
        .toList();
  }

  /// Crea un usuario de backend (evaluador/analista/administrador) con contraseña temporal.
  /// `email` SOLO es válido para `administrador` (gate #2 acotado; el backend lo valida).
  Future<BackendUserCreated> createUser({
    required String username,
    required String role,
    String? email,
  }) async {
    final r = await _http.post(
      _uri('/admin/users'),
      headers: _headers(),
      body: json.encode({
        'username': username,
        'role': role,
        if (email != null && email.isNotEmpty) 'email': email,
      }),
    );
    return BackendUserCreated.fromJson(_decode(r));
  }

  /// Cambia el rol de un usuario de backend.
  Future<BackendUser> patchUserRole({
    required String userId,
    required String role,
  }) async {
    final r = await _http.patch(
      _uri('/admin/users/$userId'),
      headers: _headers(),
      body: json.encode({'role': role}),
    );
    return BackendUser.fromJson(_decode(r));
  }

  /// El administrador dispara un reset: nueva contraseña temporal.
  Future<String> resetUser({required String userId}) async {
    final r = await _http.post(
      _uri('/admin/users/$userId/reset'),
      headers: _headers(),
    );
    return _decode(r)['temp_password'] as String;
  }

  // --- ARCO: cancelación de cuenta (CR-006). SOLO administrador. ---

  /// Busca cuentas por coincidencia parcial de handle para localizar la que se
  /// va a cancelar (GET /admin/accounts?handle=...). No expone PII (solo `has_email`).
  /// El backend exige rol `administrador`; lanza [ApiException] 403 si no lo es.
  Future<List<AdminAccountSummary>> searchAccounts({
    String? handle,
    int limit = 50,
  }) async {
    final r = await _http.get(
      _uri('/admin/accounts', {
        if (handle != null && handle.isNotEmpty) 'handle': handle,
        'limit': '$limit',
      }),
      headers: _headers(json: false),
    );
    return _decodeList(r)
        .map((e) => AdminAccountSummary.fromJson((e as Map).cast()))
        .toList();
  }

  /// Cancelación ARCO (DELETE /admin/accounts/{id}): anonimiza las observaciones,
  /// elimina la identidad y audita sin PII (gates #2/#7). SOLO administrador.
  /// `reason` es el motivo para la auditoría; NO debe contener datos personales.
  Future<DeleteAccountResult> deleteAccount({
    required String accountId,
    String? reason,
  }) async {
    final r = await _http.delete(
      _uri('/admin/accounts/$accountId'),
      headers: _headers(),
      body: json.encode({
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      }),
    );
    return DeleteAccountResult.fromJson(_decode(r));
  }

  // --- Admin: instituciones (lista F3, Q4) ---

  /// Lista F3 COMPLETA (aprobadas + solicitadas). Rol admin_consorcio.
  Future<List<Institution>> listInstitutions() async {
    final r = await _http.get(_uri('/admin/institutions'), headers: _headers());
    return _decodeList(r)
        .map((e) => Institution.fromJson((e as Map).cast()))
        .toList();
  }

  /// Alta directa (aprobada) o "solicitar agregar" (status=solicitada → EA3).
  Future<Institution> addInstitution({
    required String name,
    String? estado,
    bool requestOnly = false,
  }) async {
    final r = await _http.post(
      _uri('/admin/institutions'),
      headers: _headers(),
      body: json.encode({
        'name': name,
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        'request_only': requestOnly,
      }),
    );
    return Institution.fromJson(_decode(r));
  }

  /// Corrige nombre y/o estado de una institución (CR-029). NO cambia `status`.
  ///
  /// Lanza `ApiException(409)` si el nombre nuevo ya lo usa **otra** institución
  /// (índice único de CR-028). Pasar `estado: ''` lo deja vacío.
  Future<Institution> updateInstitution(
    String id, {
    String? name,
    String? estado,
  }) async {
    final r = await _http.patch(
      _uri('/admin/institutions/$id'),
      headers: _headers(),
      body: json.encode({
        if (name != null) 'name': name,
        if (estado != null) 'estado': estado,
      }),
    );
    return Institution.fromJson(_decode(r));
  }

  /// Aprueba una institución **solicitada** (CR-011): pasa a `aprobada` y entra al
  /// catálogo público (`GET /institutions`).
  Future<Institution> approveInstitution(String id) async {
    final r = await _http.post(
      _uri('/admin/institutions/$id/approve'),
      headers: _headers(),
    );
    return Institution.fromJson(_decode(r));
  }

  // --- Admin: aliados firmantes (Q4/Q5.B) ---

  /// Promueve una cuenta existente a `aliado_firmante` (habilita coords exactas).
  Future<Map<String, dynamic>> addAlly({required String handle}) async {
    final r = await _http.post(
      _uri('/admin/allies'),
      headers: _headers(),
      body: json.encode({'handle': handle}),
    );
    return _decode(r);
  }

  // --- Admin: indicadores organizacionales (Q6 amendment, captura manual) ---

  /// Captura MANUAL de un indicador organizacional. SIN umbrales (U1).
  Future<Map<String, dynamic>> addOrganizationalIndicator({
    required String key,
    required double value,
    String? estado,
  }) async {
    final r = await _http.post(
      _uri('/admin/indicators/organizational'),
      headers: _headers(),
      body: json.encode({
        'key': key,
        'value': value,
        if (estado != null && estado.isNotEmpty) 'estado': estado,
      }),
    );
    return _decode(r);
  }

  // --- Admin: snapshots trimestrales (Q5.B) ---

  /// Dispara un snapshot trimestral del dataset público.
  Future<SnapshotResult> createSnapshot() async {
    final r = await _http.post(_uri('/admin/snapshots'), headers: _headers());
    return SnapshotResult.fromJson(_decode(r));
  }

  // --- Vistas de datos ---

  /// Recorre un listado paginado del backend hasta la página corta (CR-034).
  /// Mismo patrón que `reviewQueueAll` (CR-033): un `limit` solo, sin lazo de
  /// `offset`, es un tope silencioso que esconde el resto del dataset.
  Future<List<T>> _fetchAll<T>(
    Future<List<T>> Function(int limit, int offset) pagina,
    int porPagina,
  ) async {
    final todas = <T>[];
    var offset = 0;
    while (true) {
      final p = await pagina(porPagina, offset);
      todas.addAll(p);
      if (p.length < porPagina) return todas;
      offset += porPagina;
    }
  }

  /// Dashboard PÚBLICO: coords EXACTAS del árbol (CR-025).
  /// Sin auth. Filtro geográfico por estado (Q8).
  Future<List<PublicObservation>> publicObservations({
    String? estado,
    String? cveEnt,
    String? cveMun,
    int limit = 500,
    int offset = 0,
  }) async {
    final r = await _http.get(
      _uri('/public/observations', {
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        if (cveEnt != null && cveEnt.isNotEmpty) 'cve_ent': cveEnt,
        if (cveMun != null && cveMun.isNotEmpty) 'cve_mun': cveMun,
        'limit': '$limit',
        'offset': '$offset',
      }),
      headers: _headers(json: false),
    );
    return _decodeList(r)
        .map((e) => PublicObservation.fromJson((e as Map).cast()))
        .toList();
  }

  /// Dataset público COMPLETO (CR-034): pagina con el tope del backend (5000).
  Future<List<PublicObservation>> publicObservationsAll({
    String? estado,
    String? cveEnt,
    String? cveMun,
  }) =>
      _fetchAll(
        (limit, offset) => publicObservations(
          estado: estado,
          cveEnt: cveEnt,
          cveMun: cveMun,
          limit: limit,
          offset: offset,
        ),
        5000,
      );

  /// Mapa de calor público (CR-009/CR-010 #2): celdas de ~300 m (binning de
  /// agregación server-side). Agrega solo observaciones no-rechazadas.
  /// Sin auth (endpoint `public/*`).
  /// CR-036: sin `limit` — el backend agrega en SQL y ya no escanea un tope de filas, así que
  /// el mapa deja de truncarse en silencio al crecer el dataset.
  Future<List<GridCell>> publicGrid({
    String? estado,
    String? cveEnt,
    String? cveMun,
  }) async {
    final r = await _http.get(
      _uri('/public/grid', {
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        if (cveEnt != null && cveEnt.isNotEmpty) 'cve_ent': cveEnt,
        if (cveMun != null && cveMun.isNotEmpty) 'cve_mun': cveMun,
      }),
      headers: _headers(json: false),
    );
    return _decodeList(r)
        .map((e) => GridCell.fromJson((e as Map).cast()))
        .toList();
  }

  /// Indicadores Q6 públicos (con caveat de origen ciudadano). Sin auth.
  Future<Indicators> publicIndicators({
    String? estado,
    String? cveEnt,
    String? cveMun,
  }) async {
    final r = await _http.get(
      _uri('/public/indicators', {
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        if (cveEnt != null && cveEnt.isNotEmpty) 'cve_ent': cveEnt,
        if (cveMun != null && cveMun.isNotEmpty) 'cve_mun': cveMun,
      }),
      headers: _headers(json: false),
    );
    return Indicators.fromJson(_decode(r));
  }

  /// Dashboard RESTRINGIDO: coords EXACTAS. Requiere rol aliado_firmante/admin
  /// autorizado (gate #5). Lanza [ApiException] 403 si el rol no es suficiente.
  /// CR-026: [estadoRevision] filtra por estado de revisión. Omitirlo devuelve
  /// TODOS los estados — la consola es la vista de trabajo y no debe esconderle
  /// al evaluador lo que le falta revisar, aunque el mapa público solo publique
  /// las confirmadas.
  Future<List<RestrictedObservation>> restrictedObservations({
    String? estado,
    String? cveEnt,
    String? cveMun,
    String? estadoRevision,
    int limit = 2000,
    int offset = 0,
  }) async {
    final r = await _http.get(
      _uri('/restricted/observations', {
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        if (cveEnt != null && cveEnt.isNotEmpty) 'cve_ent': cveEnt,
        if (cveMun != null && cveMun.isNotEmpty) 'cve_mun': cveMun,
        if (estadoRevision != null && estadoRevision.isNotEmpty)
          'estado_revision': estadoRevision,
        'limit': '$limit',
        'offset': '$offset',
      }),
      headers: _headers(json: false),
    );
    return _decodeList(r)
        .map((e) => RestrictedObservation.fromJson((e as Map).cast()))
        .toList();
  }

  /// Vista restringida COMPLETA (CR-034): pagina con el tope del backend (20000).
  Future<List<RestrictedObservation>> restrictedObservationsAll({
    String? estado,
    String? estadoRevision,
    String? cveEnt,
    String? cveMun,
  }) =>
      _fetchAll(
        (limit, offset) => restrictedObservations(
          estado: estado,
          estadoRevision: estadoRevision,
          cveEnt: cveEnt,
          cveMun: cveMun,
          limit: limit,
          offset: offset,
        ),
        20000,
      );

  // --- Revisión humana (CR-001): rol evaluador/analista/administrador ---

  /// Cola de revisión (sin coord exacta, gate #5). Filtros opcionales.
  Future<List<ReviewQueueItem>> reviewQueue({
    String? estadoRevision,
    String? estado,
    String? municipio,
    String? cveEnt,
    String? cveMun,
    int limit = 100,
    int offset = 0,
  }) async {
    final r = await _http.get(
      _uri('/review/queue', {
        if (estadoRevision != null && estadoRevision.isNotEmpty)
          'estado_revision': estadoRevision,
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        if (municipio != null && municipio.isNotEmpty) 'municipio': municipio,
        if (cveEnt != null && cveEnt.isNotEmpty) 'cve_ent': cveEnt,
        if (cveMun != null && cveMun.isNotEmpty) 'cve_mun': cveMun,
        'limit': '$limit',
        'offset': '$offset',
      }),
      headers: _headers(json: false),
    );
    return _decodeList(r)
        .map((e) => ReviewQueueItem.fromJson((e as Map).cast()))
        .toList();
  }

  /// Cola de revisión COMPLETA (CR-033): recorre `/review/queue` con `offset`
  /// en páginas del tope del backend (`le=1000`) hasta recibir una página
  /// corta. Antes la pantalla pedía una sola página de 200 y el resto de la
  /// cola quedaba invisible aunque existiera en la base.
  Future<List<ReviewQueueItem>> reviewQueueAll({
    String? estadoRevision,
    String? estado,
    String? municipio,
    String? cveEnt,
    String? cveMun,
  }) async {
    const porPagina = 1000;
    final todas = <ReviewQueueItem>[];
    var offset = 0;
    while (true) {
      final pagina = await reviewQueue(
        estadoRevision: estadoRevision,
        estado: estado,
        municipio: municipio,
        cveEnt: cveEnt,
        cveMun: cveMun,
        limit: porPagina,
        offset: offset,
      );
      todas.addAll(pagina);
      if (pagina.length < porPagina) return todas;
      offset += porPagina;
    }
  }

  /// Detalle + historial de veredictos de una observación (sin coord exacta).
  Future<ReviewObservationDetail> reviewDetail(String observationId) async {
    final r = await _http.get(
      _uri('/review/observations/$observationId'),
      headers: _headers(json: false),
    );
    return ReviewObservationDetail.fromJson(_decode(r));
  }

  /// URL de la imagen para el visor (el bearer va en el header del propio GET).
  /// La sirve el backend con EXIF GPS saneado salvo aliado_firmante (gate #5).
  Uri reviewImageUri(String observationId) =>
      _uri('/review/observations/$observationId/image');

  /// Bytes de la imagen (EXIF GPS saneado server-side salvo aliado_firmante).
  Future<List<int>> reviewImageBytes(String observationId) async {
    final r =
        await _http.get(reviewImageUri(observationId), headers: _headers(json: false));
    if (r.statusCode >= 200 && r.statusCode < 300) return r.bodyBytes;
    throw ApiException(r.statusCode, 'No se pudo cargar la imagen', body: r.body);
  }

  /// Emite un veredicto humano (confirmada|rechazada). Solo evaluador/administrador.
  Future<Map<String, dynamic>> submitVerdict({
    required String observationId,
    required String veredicto,
    String? nota,
  }) async {
    final r = await _http.post(
      _uri('/review/observations/$observationId/verdict'),
      headers: _headers(),
      body: json.encode({
        'veredicto': veredicto,
        if (nota != null && nota.isNotEmpty) 'nota': nota,
      }),
    );
    return _decode(r);
  }

  /// Métricas de la cola de revisión (Monitor del analista).
  Future<ReviewStats> reviewStats() async {
    final r = await _http.get(_uri('/review/stats'), headers: _headers(json: false));
    return ReviewStats.fromJson(_decode(r));
  }

  // --- Catálogo geográfico (CR-036) ---

  /// Entidades federativas con límites cargados. Alimenta los filtros de la consola.
  Future<List<GeoEstado>> geoEstados() async {
    final r = await _http.get(_uri('/geo/estados'), headers: _headers(json: false));
    return _decodeList(r).map((e) => GeoEstado.fromJson((e as Map).cast())).toList();
  }

  /// Municipios de una entidad. Sin `cveEnt` devolvería los ~2 478 del país, que no le sirve a
  /// ningún selector: la consola siempre acota por estado primero.
  Future<List<GeoMunicipio>> geoMunicipios({required String cveEnt}) async {
    final r = await _http.get(
      _uri('/geo/municipios', {'cve_ent': cveEnt}),
      headers: _headers(json: false),
    );
    return _decodeList(r).map((e) => GeoMunicipio.fromJson((e as Map).cast())).toList();
  }

  // --- Analítica del analista (CR-010 #3): rol analista/administrador ---

  Map<String, String> _analyticsQuery({
    String? estadoRevision,
    String? municipio,
    String? nivelG4,
    String? desde,
    String? hasta,
    String? cveEnt,
    String? cveMun,
    int? limit,
    int? offset,
  }) =>
      {
        if (estadoRevision != null && estadoRevision.isNotEmpty)
          'estado_revision': estadoRevision,
        if (municipio != null && municipio.isNotEmpty) 'municipio': municipio,
        // CR-036: el filtro geográfico viaja por CLAVE INEGI. Es la identidad estable: inmune a
        // acentos y, sobre todo, a los homónimos — "Jesús María" existe en tres entidades y
        // filtrar por nombre las fundiría en una sola.
        if (cveEnt != null && cveEnt.isNotEmpty) 'cve_ent': cveEnt,
        if (cveMun != null && cveMun.isNotEmpty) 'cve_mun': cveMun,
        if (nivelG4 != null && nivelG4.isNotEmpty) 'nivel_g4': nivelG4,
        if (desde != null && desde.isNotEmpty) 'desde': desde,
        if (hasta != null && hasta.isNotEmpty) 'hasta': hasta,
        if (limit != null) 'limit': '$limit',
        if (offset != null) 'offset': '$offset',
      };

  /// Tarjetas de resumen (GET /admin/analytics/summary). Conteos agregados sin
  /// coords exactas (gate #5). Acepta los mismos filtros que la tabla.
  Future<AnalyticsSummary> analyticsSummary({
    String? estadoRevision,
    String? municipio,
    String? nivelG4,
    String? desde,
    String? hasta,
    String? cveEnt,
    String? cveMun,
  }) async {
    final r = await _http.get(
      _uri('/admin/analytics/summary',
          _analyticsQuery(
            estadoRevision: estadoRevision,
            municipio: municipio,
            nivelG4: nivelG4,
            desde: desde,
            hasta: hasta,
            cveEnt: cveEnt,
            cveMun: cveMun,
          )),
      headers: _headers(json: false),
    );
    return AnalyticsSummary.fromJson(_decode(r));
  }

  /// Tabla de observaciones del analista (GET /admin/analytics/observations).
  /// SIN coord exacta: solo estado/municipio (gate #5).
  Future<List<AnalyticsObservation>> analyticsObservations({
    String? estadoRevision,
    String? municipio,
    String? nivelG4,
    String? desde,
    String? hasta,
    String? cveEnt,
    String? cveMun,
    int limit = 500,
    int offset = 0,
  }) async {
    final r = await _http.get(
      _uri('/admin/analytics/observations',
          _analyticsQuery(
            estadoRevision: estadoRevision,
            municipio: municipio,
            nivelG4: nivelG4,
            desde: desde,
            hasta: hasta,
            cveEnt: cveEnt,
            cveMun: cveMun,
            limit: limit,
            offset: offset,
          )),
      headers: _headers(json: false),
    );
    return _decodeList(r)
        .map((e) => AnalyticsObservation.fromJson((e as Map).cast()))
        .toList();
  }

  /// Tabla del analista COMPLETA (CR-034): pagina con el tope del backend (5000).
  Future<List<AnalyticsObservation>> analyticsObservationsAll({
    String? estadoRevision,
    String? municipio,
    String? nivelG4,
    String? desde,
    String? hasta,
    String? cveEnt,
    String? cveMun,
  }) =>
      _fetchAll(
        (limit, offset) => analyticsObservations(
          estadoRevision: estadoRevision,
          municipio: municipio,
          nivelG4: nivelG4,
          desde: desde,
          hasta: hasta,
          cveEnt: cveEnt,
          cveMun: cveMun,
          limit: limit,
          offset: offset,
        ),
        5000,
      );

  /// Bytes del CSV de observaciones (GET /admin/analytics/observations.csv) con
  /// el header Authorization (Flutter Web ignora headers en `<a download>`, así
  /// que se baja por fetch autenticado y luego se entrega al navegador). El CSV
  /// NO incluye coords exactas (gate #5): solo estado/municipio.
  Future<List<int>> analyticsCsvBytes({
    String? estadoRevision,
    String? municipio,
    String? nivelG4,
    String? desde,
    String? hasta,
    String? cveEnt,
    String? cveMun,
  }) async {
    final r = await _http.get(
      _uri('/admin/analytics/observations.csv',
          _analyticsQuery(
            estadoRevision: estadoRevision,
            municipio: municipio,
            nivelG4: nivelG4,
            desde: desde,
            hasta: hasta,
            cveEnt: cveEnt,
            cveMun: cveMun,
          )),
      headers: _headers(json: false),
    );
    if (r.statusCode >= 200 && r.statusCode < 300) return r.bodyBytes;
    throw ApiException(r.statusCode, 'No se pudo descargar el CSV', body: r.body);
  }

  /// Bytes del CSV de **participación por día** (CR-026,
  /// `GET /admin/analytics/participation.csv`): una fila por (día × voluntario)
  /// con sesiones y horas frente al desglose de revisión de ese día. Es lo que
  /// la institución necesita para evaluar sin pedir acceso a la base.
  ///
  /// Ojo al leerlo: las horas miden tiempo con la app abierta, no trabajo en
  /// campo — por eso CR-026 las quitó de la pantalla del voluntario.
  Future<List<int>> participationCsvBytes({
    String? municipio,
    String? desde,
    String? hasta,
    String? cveEnt,
    String? cveMun,
  }) async {
    final r = await _http.get(
      _uri('/admin/analytics/participation.csv', {
        if (municipio != null && municipio.isNotEmpty) 'municipio': municipio,
        if (cveEnt != null && cveEnt.isNotEmpty) 'cve_ent': cveEnt,
        if (cveMun != null && cveMun.isNotEmpty) 'cve_mun': cveMun,
        if (desde != null && desde.isNotEmpty) 'desde': desde,
        if (hasta != null && hasta.isNotEmpty) 'hasta': hasta,
      }),
      headers: _headers(json: false),
    );
    if (r.statusCode >= 200 && r.statusCode < 300) return r.bodyBytes;
    throw ApiException(r.statusCode, 'No se pudo descargar el CSV', body: r.body);
  }

  // --- Reportes de problemas (CR-019): rol admin (admin_consorcio/administrador) ---

  /// Lista de reportes de problemas que envían las apps (GET /admin/problem-reports).
  /// Requiere rol admin; lanza [ApiException] 403 si el rol no es suficiente.
  /// Sin PII más allá del handle seudónimo (gate #2).
  Future<List<ProblemReport>> listProblemReports() async {
    final r = await _http.get(
      _uri('/admin/problem-reports'),
      headers: _headers(json: false),
    );
    return _decodeList(r)
        .map((e) => ProblemReport.fromJson((e as Map).cast()))
        .toList();
  }

  /// Cambia el estado de un reporte (POST /admin/problem-reports/{id}/status).
  /// `status`: 'visto' | 'resuelto'. Devuelve el reporte actualizado si el backend
  /// lo incluye en la respuesta.
  Future<ProblemReport> setProblemReportStatus({
    required String id,
    required String status,
  }) async {
    final r = await _http.post(
      _uri('/admin/problem-reports/$id/status'),
      headers: _headers(),
      body: json.encode({'status': status}),
    );
    return ProblemReport.fromJson(_decode(r));
  }

  void close() => _http.close();
}

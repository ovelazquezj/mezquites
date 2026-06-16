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

  // --- Auth (sin PII, gate #2) ---

  /// Login admin: handle + código de respaldo → token. SIN email/contraseña/PII.
  Future<AuthSession> recover({
    required String handle,
    required String backupCode,
  }) async {
    final r = await _http.post(
      _uri('/auth/recover'),
      headers: _headers(),
      body: json.encode({'handle': handle, 'backup_code': backupCode}),
    );
    final session = AuthSession.fromToken(_decode(r));
    _token = session.token;
    return session;
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

  /// Dashboard PÚBLICO: coords obfuscadas a 1 km server-side (gate #5).
  /// Sin auth. Filtro geográfico por estado (Q8).
  Future<List<PublicObservation>> publicObservations({
    String? estado,
    int limit = 500,
  }) async {
    final r = await _http.get(
      _uri('/public/observations', {
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        'limit': '$limit',
      }),
      headers: _headers(json: false),
    );
    return _decodeList(r)
        .map((e) => PublicObservation.fromJson((e as Map).cast()))
        .toList();
  }

  /// Indicadores Q6 públicos (con caveat de origen ciudadano). Sin auth.
  Future<Indicators> publicIndicators({String? estado}) async {
    final r = await _http.get(
      _uri('/public/indicators',
          {if (estado != null && estado.isNotEmpty) 'estado': estado}),
      headers: _headers(json: false),
    );
    return Indicators.fromJson(_decode(r));
  }

  /// Dashboard RESTRINGIDO: coords EXACTAS. Requiere rol aliado_firmante/admin
  /// autorizado (gate #5). Lanza [ApiException] 403 si el rol no es suficiente.
  Future<List<RestrictedObservation>> restrictedObservations({
    String? estado,
    int limit = 2000,
  }) async {
    final r = await _http.get(
      _uri('/restricted/observations', {
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        'limit': '$limit',
      }),
      headers: _headers(json: false),
    );
    return _decodeList(r)
        .map((e) => RestrictedObservation.fromJson((e as Map).cast()))
        .toList();
  }

  // --- Revisión humana (CR-001): rol evaluador/analista/administrador ---

  /// Cola de revisión (sin coord exacta, gate #5). Filtros opcionales.
  Future<List<ReviewQueueItem>> reviewQueue({
    String? estadoRevision,
    String? estado,
    String? municipio,
    int limit = 100,
    int offset = 0,
  }) async {
    final r = await _http.get(
      _uri('/review/queue', {
        if (estadoRevision != null && estadoRevision.isNotEmpty)
          'estado_revision': estadoRevision,
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        if (municipio != null && municipio.isNotEmpty) 'municipio': municipio,
        'limit': '$limit',
        'offset': '$offset',
      }),
      headers: _headers(json: false),
    );
    return _decodeList(r)
        .map((e) => ReviewQueueItem.fromJson((e as Map).cast()))
        .toList();
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

  void close() => _http.close();
}

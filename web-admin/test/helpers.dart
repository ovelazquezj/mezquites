import 'dart:convert';

import 'package:http/http.dart' as http;

/// Construye un JWT **sin firma válida** (solo claims) para pruebas del gate de
/// rol: el cliente solo lee `handle`/`role` de la sección de payload.
String fakeJwt({required String handle, required String role}) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  final header = b64({'alg': 'HS256', 'typ': 'JWT'});
  final payload = b64({'sub': 'x', 'handle': handle, 'role': role});
  return '$header.$payload.signature';
}

/// Registra cada petición HTTP para aserciones (qué rutas se llamaron).
class RequestRecorder {
  final List<http.BaseRequest> requests = [];

  List<String> get paths => requests.map((r) => r.url.path).toList();

  bool hitPathContaining(String fragment) =>
      paths.any((p) => p.contains(fragment));
}

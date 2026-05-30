import 'dart:convert';

/// Decodifica los *claims* de un JWT **sin verificar la firma** (la verificación
/// es autoritativa en el backend). Solo se usa para leer `handle`/`role` cuando
/// el admin pega un token, y así aplicar el gate de rol en la UI.
///
/// El token del backend (`security.py`) lleva en el payload solo `sub`, `handle`,
/// `role`, `iat`, `exp` — sin PII (gate #2). Devuelve `null` si no es un JWT.
Map<String, dynamic>? decodeJwtClaims(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final payload = utf8.decode(base64Url.decode(normalized));
    final decoded = json.decode(payload);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return null;
  } catch (_) {
    return null;
  }
}

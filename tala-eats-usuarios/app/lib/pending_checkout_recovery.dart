import 'production_api.dart';

/// Fail-closed verification of a checkout journal after Android process death.
///
/// Does not create orders, restart payment intents, or call payment providers.
/// The journal is cleared only after an authenticated owner-matched GET 200.
class PendingCheckoutRecovery {
  static Future<Map<String, dynamic>?> recover({
    required int userId,
    required bool signedIn,
    required String? activeReference,
    required Future<String?> Function() read,
    required Future<Map<String, dynamic>> Function(String reference) lookup,
    required Future<void> Function() clear,
  }) async {
    final String? pending = await read();
    if (pending == null || pending.isEmpty) return null;
    final int split = pending.indexOf('|');
    final int? owner = split > 0 ? int.tryParse(pending.substring(0, split)) : null;
    final String ref = split >= 0 ? pending.substring(split + 1) : '';
    if (!signedIn || owner == null || owner != userId ||
        !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(ref)) {
      throw ApiException(409, 'Hay una compra pendiente de otra sesión. Cierra sesión antes de continuar.');
    }
    if (activeReference == ref) return null; // same process replay has same body
    Map<String, dynamic> order;
    try {
      order = await lookup(ref);
    } on ApiException catch (e) {
      // 404 cannot distinguish a not-yet-committed POST from an older
      // deployment without the recovery route. Never reissue a NEW order.
      if (e.statusCode == 404) {
        throw ApiException(409, 'Hay un pedido por verificar. Consulta Mis pedidos o soporte antes de comprar de nuevo.');
      }
      rethrow;
    }
    final int? id = int.tryParse((order['id'] ?? '').toString());
    final int? ownerFromApi = int.tryParse((order['user_id'] ?? '').toString());
    if (id == null || id <= 0 || ownerFromApi != userId ||
        order['client_reference'] != ref) {
      throw ApiException(409, 'La respuesta del servidor no coincide con la compra pendiente.');
    }
    await clear();
    return order;
  }
}

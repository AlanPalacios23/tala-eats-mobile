import 'dart:convert';
import 'dart:math';

import 'production_api.dart';

/// A durable, account-scoped store. Android implementation encrypts journal
/// using AndroidKeyStore AES-GCM and writes it synchronously before HTTP POST.
abstract class PendingOrderStore {
  Future<String?> read(int accountId);
  Future<void> write(int accountId, String payload);
  Future<void> clear(int accountId);
}

class AndroidPendingOrderStore implements PendingOrderStore {
  @override
  Future<String?> read(int accountId) => NativeBridge.readPendingOrder(accountId);

  @override
  Future<void> write(int accountId, String payload) =>
      NativeBridge.writePendingOrder(accountId, payload);

  @override
  Future<void> clear(int accountId) => NativeBridge.clearPendingOrder(accountId);
}

/// Preserves the *entire* submitted body and client_reference until the
/// server confirms the outcome. A process crash, app restart or timeout
/// therefore cannot silently generate a different reference for that checkout.
///
/// A stored but unresolved checkout BLOCKS any changed cart/body until the
/// customer can reconcile the reference against the authenticated API.
/// When the API responds 404, do NOT erase the journal: the request could
/// still be in flight elsewhere. No new payment is made automatically.
class OrderSubmissionGuard {
  OrderSubmissionGuard({PendingOrderStore? store, int Function()? accountId})
      : _store = store,
        _accountId = accountId,
        _random = Random.secure();

  final PendingOrderStore? _store;
  final int Function()? _accountId;
  final Random _random;
  String? _requestSignature;
  String? _clientReference;
  Future<Map<String, dynamic>>? _inFlight;
  int _generation = 0;

  String? get unresolvedClientReference => _clientReference;

  int _owner() {
    final owner = _accountId?.call() ?? 0;
    if (_store != null && owner <= 0) {
      throw ApiException(401, 'La sesión debe verificarse antes de pedir.');
    }
    return owner;
  }

  /// Returns the same Future for two simultaneous taps, including while
  /// reading/encrypting a journal. Never sends HTTP before durable commit.
  Future<Map<String, dynamic>> submit(
    Map<String, dynamic> draft,
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload) send,
  ) {
    if (_inFlight != null) return _inFlight!;
    final future = _submitOnce(draft, send, _generation);
    _inFlight = future;
    return future;
  }

  Future<Map<String, dynamic>> _submitOnce(
    Map<String, dynamic> draft,
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload) send,
    int generation,
  ) async {
    // Cross the first async boundary before _owner() can reject a signed-out
    // account. Otherwise a synchronous rejection may predate _inFlight setup.
    await Future<void>.value();
    int owner = 0;
    try {
      owner = _owner();
      if (draft.containsKey('client_reference')) {
        throw ArgumentError('El guard genera client_reference internamente.');
      }
      final signature = jsonEncode(draft);
      final saved = await _readSaved(owner);
      if (generation != _generation) {
        throw ApiException(401, 'La sesión cambió antes de enviar el pedido.');
      }

      if (saved != null && saved.signature != signature) {
        throw ApiException(409, 'Existe un pedido sin confirmar. '
            'Revisa Mis pedidos y conserva el carrito original.');
      }
      if (saved == null && _requestSignature != null &&
          _requestSignature != signature) {
        throw ApiException(409, 'Existe un pedido anterior sin confirmar. '
            'Revisa Mis pedidos antes de comprar de nuevo.');
      }

      final reference = saved?.reference ??
          _clientReference ?? _newReference(draft['restaurant_id']);
      if (saved == null && _store != null) {
        // Durable before HTTP: if encryption/disk commit fails, fail closed.
        await _store.write(owner, jsonEncode(<String, dynamic>{
          'v': 1,
          'owner': owner,
          'signature': signature,
          'reference': reference,
        }));
      }
      if (generation != _generation) {
        throw ApiException(401, 'La sesión cambió antes de enviar el pedido.');
      }
      _requestSignature = signature;
      _clientReference = reference;
      final body = Map<String, dynamic>.from(jsonDecode(signature) as Map);
      body['client_reference'] = reference;
      final result = await send(body);
      if (generation == _generation) {
        await _clearConfirmed(owner);
      }
      return result;
    } on ApiException catch (e) {
      // An explicit rejected request may release the reference, but transport
      // failures/5xx and 408/409/429 are ambiguous and MUST retain it.
      if (owner > 0 && generation == _generation &&
          <int>{400, 401, 403, 404, 422}.contains(e.statusCode)) {
        await _clearConfirmed(owner);
      }
      rethrow;
    } finally {
      if (generation == _generation) _inFlight = null;
    }
  }

  Future<_SavedAttempt?> _readSaved(int owner) async {
    if (_store == null) return null;
    final raw = await _store.read(owner); // errors/corruption -> fail closed
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('journal object');
      if (decoded['v'] != 1 || decoded['owner'] != owner) {
        throw const FormatException('journal ownership/version');
      }
      final signature = decoded['signature'];
      final reference = decoded['reference'];
      if (signature is! String || signature.isEmpty ||
          signature.length > 12000 || reference is! String ||
          !RegExp(r'^android-[0-9]+-[a-f0-9]{32}$').hasMatch(reference)) {
        throw const FormatException('journal body/reference');
      }
      final intent = jsonDecode(signature);
      if (intent is! Map || intent['restaurant_id'] == null ||
          intent.containsKey('client_reference')) {
        throw const FormatException('journal intent');
      }
      return _SavedAttempt(signature, reference);
    } catch (_) {
      throw ApiException(409, 'La compra pendiente no pudo verificarse '
          'de forma segura. Contacta soporte antes de pedir otra vez.');
    }
  }

  /// Queries only, never re-submits an order. 404 leaves encrypted journal
  /// intact; user can retry the frozen payload under original reference.
  Future<Map<String, dynamic>?> recover(
    Future<Map<String, dynamic>> Function(String reference) lookup,
  ) async {
    if (_inFlight != null) return null;
    final owner = _owner();
    final generation = _generation;
    final saved = await _readSaved(owner);
    if (saved == null || generation != _generation) return null;
    try {
      final found = await lookup(saved.reference);
      if (generation != _generation) return null;
      if (found['client_reference'] != saved.reference ||
          found['user_id'] != owner) {
        throw ApiException(409, 'La respuesta del pedido no coincide con '
            'la cuenta autenticada.');
      }
      await _clearConfirmed(owner);
      return found;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null; // uncertain, keep journal
      rethrow;
    }
  }

  Future<void> _clearConfirmed(int owner) async {
    if (_store != null) await _store.clear(owner);
    _requestSignature = null;
    _clientReference = null;
  }

  String _newReference(Object? restaurantId) {
    final randomHex = List<int>.generate(
      16, (_) => _random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return 'android-$restaurantId-$randomHex';
  }

  /// On logout only reset volatile state. The encrypted journal stays
  /// attached to that account until a confirmed resolution. Never copy
  /// the previous account's pending intent into the next account.
  void clearAfterConfirmedResolution() {
    _generation++;
    _requestSignature = null;
    _clientReference = null;
    _inFlight = null;
  }
}

class _SavedAttempt {
  const _SavedAttempt(this.signature, this.reference);
  final String signature;
  final String reference;
}

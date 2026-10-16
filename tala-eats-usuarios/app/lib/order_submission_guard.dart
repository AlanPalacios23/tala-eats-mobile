import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'production_api.dart';

/// A single checkout attempt has one immutable request body and one reference.
///
/// An uncertain HTTP response (timeout, offline, 5xx) retains the reference.
/// Replaying an unchanged request reaches backend order uniqueness constraints;
/// it never invents a second customer order while the first may have committed.
///
/// Scope: current authenticated app process. Recovery after app termination
/// still needs durable local persistence + a server-side lookup contract.
class OrderSubmissionGuard {
  OrderSubmissionGuard() : _random = Random.secure();

  final Random _random;
  String? _requestSignature;
  String? _clientReference;
  Future<Map<String, dynamic>>? _inFlight;
  int _generation = 0;

  String? get unresolvedClientReference => _clientReference;

  Future<Map<String, dynamic>> submit(
    Map<String, dynamic> draft,
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload) send,
  ) {
    if (draft.containsKey('client_reference')) {
      return Future<Map<String, dynamic>>.error(
        ArgumentError('El guard genera client_reference internamente.'),
      );
    }
    // Freeze the serialized body BEFORE choosing/reusing its reference.
    final String signature = jsonEncode(draft);
    if (_requestSignature != null && signature != _requestSignature) {
      return Future<Map<String, dynamic>>.error(ApiException(
        409,
        'Hay un pedido anterior sin confirmar. Revisa Mis pedidos y '
        'reintenta sin cambiar el carrito para evitar compras duplicadas.',
      ));
    }
    if (_inFlight != null) return _inFlight!;

    _requestSignature ??= signature;
    _clientReference ??= _newReference(draft['restaurant_id']);
    final Map<String, dynamic> frozen =
        Map<String, dynamic>.from(jsonDecode(_requestSignature!) as Map);
    frozen['client_reference'] = _clientReference;
    final Future<Map<String, dynamic>> future = _dispatch(
      frozen, send, _generation,
    );
    _inFlight = future;
    return future;
  }

  Future<Map<String, dynamic>> _dispatch(
    Map<String, dynamic> body,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>) send,
    int generation,
  ) async {
    try {
      final Map<String, dynamic> result = await send(body);
      // A response from the previous signed-out session must never
      // clear a newer customer's pending checkout.
      if (_generation == generation) _clearPending();
      return result;
    } on ApiException catch (e) {
      // A timeout/408/409/429/5xx remains ambiguous: preserve one key.
      if (_generation == generation &&
          <int>{400, 401, 403, 404, 422}.contains(e.statusCode)) {
        _clearPending();
      }
      rethrow;
    } finally {
      if (_generation == generation) _inFlight = null;
    }
  }

  void _clearPending() {
    _requestSignature = null;
    _clientReference = null;
  }

  String _newReference(Object? restaurantId) {
    final String randomHex = List<int>.generate(
      16, (_) => _random.nextInt(256),
    ).map((int byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return 'android-$restaurantId-$randomHex';
  }

  /// Use only after confirmed POST success, confirmed rejection, or logout.
  void clearAfterConfirmedResolution() {
    _generation++;
    _clearPending();
    _inFlight = null;
  }
}

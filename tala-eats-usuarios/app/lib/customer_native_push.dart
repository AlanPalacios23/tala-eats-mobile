import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'production_api.dart';

/// User-initiated Android notifications using Firebase Cloud Messaging.
/// No credentials, tokens or user payloads in logs or static assets.
/// In debug/default builds all Firebase options are empty -> feature OFF.
class CustomerNativePush {
  static const String _apiKey = String.fromEnvironment('TALAEATS_FCM_API_KEY');
  static const String _appId = String.fromEnvironment('TALAEATS_FCM_APP_ID');
  static const String _senderId = String.fromEnvironment('TALAEATS_FCM_SENDER_ID');
  static const String _projectId = String.fromEnvironment('TALAEATS_FCM_PROJECT_ID');

  static bool get firebaseConfigured =>
      _apiKey.isNotEmpty && _appId.isNotEmpty &&
      _senderId.isNotEmpty && _projectId.isNotEmpty;

  /// Fail closed if customer APK and backend FCM configurations target
  /// different Firebase projects. Firebase project IDs are public, never keys.
  static bool matchesServerProject(Map<String, dynamic> config,
      {String? configuredProjectId}) {
    final local = configuredProjectId ?? _projectId;
    return config['enabled'] == true && config['provider'] == 'fcm' &&
        local.isNotEmpty && config['project_id'] == local;
  }

  StreamSubscription<String>? _rotatingToken;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  String? _deviceId;
  int? _ownerId;
  int _generation = 0;
  bool active = false;

  Future<bool> enable(
    TalaApi api, {
    required int userId,
    required bool marketing,
    required bool askPermission,
    required void Function() onInbox,
    required void Function() onOpenOrders,
  }) async {
    final int generation = ++_generation;
    final String? identityToken = api.token;
    if (!Platform.isAndroid || userId <= 0 || identityToken == null) return false;
    if (!firebaseConfigured) {
      if (askPermission) {
        throw ApiException(503,
          'Las notificaciones Android requieren configurar Firebase primero.');
      }
      return false;
    }
    if (!askPermission && !await NativeBridge.readPushConsent(userId)) {
      return false;
    }
    final config = await api.customerPushConfig();
    if (config['enabled'] != true || config['provider'] != 'fcm') {
      if (askPermission) throw ApiException(503,
        'El servidor todavía no tiene notificaciones FCM activas.');
      return false;
    }
    if (!matchesServerProject(config)) {
      if (askPermission) throw ApiException(503,
        'El proyecto Firebase de la aplicación y del servidor no coincide.');
      return false;
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: const FirebaseOptions(
        apiKey: _apiKey, appId: _appId,
        messagingSenderId: _senderId, projectId: _projectId,
      ));
    }
    final messaging = FirebaseMessaging.instance;
    final permission = askPermission
        ? await messaging.requestPermission(
            alert: true, badge: true, sound: true, provisional: false)
        : await messaging.getNotificationSettings();
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      if (askPermission) throw ApiException(403,
        'Permiso de notificaciones denegado. Puedes cambiarlo en Android.');
      return false;
    }
    final deviceId = await NativeBridge.pushInstallationId();
    final token = await messaging.getToken();
    if (deviceId == null || token == null || token.isEmpty) {
      if (askPermission) throw ApiException(503,
        'Firebase no pudo obtener un token para este dispositivo.');
      return false;
    }
    if (generation != _generation || api.token != identityToken) return false;

    final response = await api.registerCustomerPush(
      token: token, deviceId: deviceId, marketing: marketing);
    if (response['registered'] != true || response['application'] != 'customer') {
      throw ApiException(502, 'El servidor no confirmó el registro push.');
    }
    if (generation != _generation || api.token != identityToken) {
      // An account change may have occurred in flight. Do not attach listeners
      // to the new account or assume registration belongs to it.
      return false;
    }
    if (askPermission) await NativeBridge.writePushConsent(userId, true);
    await _closeSubscriptions();
    _ownerId = userId;
    _deviceId = deviceId;
    active = true;

    _rotatingToken = messaging.onTokenRefresh.listen((String newToken) {
      if (generation != _generation || api.token != identityToken ||
          _ownerId != userId || newToken.isEmpty) return;
      unawaited(api.registerCustomerPush(token: newToken,
          deviceId: deviceId, marketing: marketing).then((_) {}).catchError((Object _) {}));
    });
    _foreground = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (generation == _generation && api.token == identityToken) onInbox();
    });
    _opened = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (generation == _generation && api.token == identityToken) onOpenOrders();
    });
    final initial = await messaging.getInitialMessage();
    if (initial != null && generation == _generation && api.token == identityToken) {
      onOpenOrders();
    }
    return true;
  }

  Future<void> _closeSubscriptions() async {
    await _rotatingToken?.cancel();
    await _foreground?.cancel();
    await _opened?.cancel();
    _rotatingToken = null;
    _foreground = null;
    _opened = null;
  }

  Future<void> updateMarketing(TalaApi api, bool enabled) async {
    if (active && _deviceId != null && api.token != null) {
      await api.changeCustomerPushMarketing(_deviceId!, enabled);
    }
  }

  /// Best-effort server-side unregister PLUS local Firebase token invalidation.
  /// Returns false when the server did not acknowledge unregistration.
  Future<bool> disable(TalaApi api, int userId) async {
    ++_generation;
    await _closeSubscriptions();
    // An Android process can die after consent/registration. Recover the
    // stable installation ID even when listeners have not resumed yet.
    final consented = userId > 0 &&
        await NativeBridge.readPushConsent(userId);
    final deviceId = _deviceId ??
        (consented ? await NativeBridge.pushInstallationId() : null);
    _deviceId = null;
    _ownerId = null;
    active = false;
    bool remoteRevoked = deviceId == null;
    if (deviceId != null && api.token != null) {
      try {
        await api.unregisterCustomerPush(deviceId)
            .timeout(const Duration(seconds: 8));
        remoteRevoked = true;
      } catch (_) {
        remoteRevoked = false;
      }
    }
    // The device should not continue to receive pushes after local logout.
    if (firebaseConfigured) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: const FirebaseOptions(
            apiKey: _apiKey, appId: _appId,
            messagingSenderId: _senderId, projectId: _projectId,
          ));
        }
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
    if (userId > 0) {
      try { await NativeBridge.writePushConsent(userId, false); } catch (_) {}
    }
    return remoteRevoked;
  }
}

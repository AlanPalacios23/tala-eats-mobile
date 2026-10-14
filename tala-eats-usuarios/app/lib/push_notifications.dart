part of 'main.dart';

/// Opciones públicas de Firebase (NO incluir service-account ni claves de
/// cifrado FCM). Definir mediante --dart-define cuando se configure Firebase.
/// Sin configuración la app conserva su buzón y no solicita permisos FCM.
const String _fcmProjectId = String.fromEnvironment('TALAEATS_FCM_PROJECT_ID');
const String _fcmAppId = String.fromEnvironment('TALAEATS_FCM_ANDROID_APP_ID');
const String _fcmSenderId = String.fromEnvironment('TALAEATS_FCM_SENDER_ID');
const String _fcmApiKey = String.fromEnvironment('TALAEATS_FCM_API_KEY');

bool get customerFirebaseConfigured =>
    _fcmProjectId.isNotEmpty &&
    _fcmAppId.isNotEmpty &&
    _fcmSenderId.isNotEmpty &&
    _fcmApiKey.isNotEmpty;

int? safePushOrderId(Map<String, dynamic> data) {
  final String raw = (data['order_id'] ?? '').toString();
  final int? id = int.tryParse(raw);
  return id != null && id > 0 ? id : null;
}

/// La persistencia de mensajes y el TTL pertenecen al backend/FCM.
/// La app NO usa un timer en background ni almacena tokens FCM en texto plano.
class CustomerPushService extends ChangeNotifier {
  CustomerPushService(this.model);

  final TalaModel model;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  StreamSubscription<String>? _rotations;
  bool _firebaseReady = false;
  bool _backendReady = false;
  bool _registered = false;
  bool _busy = false;
  bool _disposed = false;
  bool _hadSession = false;
  String _deviceId = '';
  int? _pendingOrderOpen;
  bool _pendingTap = false;
  String message = 'Comprueba la disponibilidad de notificaciones del dispositivo.';

  bool get configured => _firebaseReady && _backendReady;
  bool get registered => _registered;
  bool get busy => _busy;

  void _update(String value) {
    if (_disposed) return;
    message = value;
    notifyListeners();
  }

  Future<void> start() async {
    if (_disposed) return;
    if (!Platform.isAndroid || !customerFirebaseConfigured) {
      _update('Notificaciones del dispositivo pendientes de configuración Firebase.');
      return;
    }
    try {
      final dynamic config = await model.api.get('/mobile-push/config');
      _backendReady = config is Map && config['enabled'] == true;
      if (!_backendReady) {
        _update('El servidor todavía no tiene las notificaciones push habilitadas.');
        return;
      }
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: _fcmApiKey,
          appId: _fcmAppId,
          messagingSenderId: _fcmSenderId,
          projectId: _fcmProjectId,
        ),
      );
      _firebaseReady = true;
      _deviceId = await NativeBridge.pushDeviceId() ?? '';
      model.setOrderPush(await NativeBridge.pushEnabled());
      model.setPromoPush(await NativeBridge.pushMarketing());
      if (_deviceId.length < 8) {
        _update('No pudimos identificar el dispositivo de forma segura.');
        return;
      }
      _foreground = FirebaseMessaging.onMessage.listen(_onMessage);
      _opened = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
      _rotations = FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
        if (model.signedIn) unawaited(_registerIfPermissionGranted());
      });
      final RemoteMessage? launch = await FirebaseMessaging.instance.getInitialMessage();
      if (launch != null) _onOpened(launch);
      await _registerIfPermissionGranted();
      _update(_registered ? 'Avisos de pedidos activados en este dispositivo.' : 'Activa los avisos para seguir tus pedidos aunque cierres la app.');
    } catch (_) {
      _update('No pudimos configurar las notificaciones en este dispositivo.');
    }
  }

  Future<void> onAuthChanged() async {
    if (_disposed || !_firebaseReady || !_backendReady) return;
    if (!model.signedIn) {
      _hadSession = false;
      _registered = false;
      _update('Inicia sesión para recibir avisos de tus pedidos.');
      return;
    }
    if (_hadSession) return;
    _hadSession = true;
    if (_pendingTap) {
      final int? pendingId = _pendingOrderOpen;
      _pendingOrderOpen = null;
      _pendingTap = false;
      _openWhenReady(pendingId);
    }
    await _registerIfPermissionGranted();
  }

  Future<void> _registerIfPermissionGranted() async {
    if (!configured || !model.signedIn || !model.orderPush || _deviceId.isEmpty) return;
    try {
      final NotificationSettings settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) return;
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _register(token);
    } catch (_) {
      _update('No pudimos registrar las notificaciones. Prueba otra vez.');
    }
  }

  Future<void> enable() async {
    if (_busy) return;
    if (!configured) {
      _update('Firebase y el servidor deben estar configurados antes de activar avisos.');
      return;
    }
    if (!model.signedIn) {
      _update('Inicia sesión para activar los avisos.');
      return;
    }
    _busy = true;
    notifyListeners();
    try {
      final NotificationSettings result = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      if (result.authorizationStatus != AuthorizationStatus.authorized &&
          result.authorizationStatus != AuthorizationStatus.provisional) {
        _update('Permiso denegado. Puedes cambiarlo en los ajustes de Android.');
        return;
      }
      model.setOrderPush(true);
      await NativeBridge.setPushEnabled(true);
      await _registerIfPermissionGranted();
    } catch (_) {
      _update('No fue posible habilitar avisos en el dispositivo.');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _register(String token) async {
    if (_disposed || !configured || !model.signedIn || !model.orderPush ||
        token.length < 20 || _deviceId.length < 8) return;
    try {
      await model.api.put('/mobile-push/devices', <String, dynamic>{
        'token': token,
        'device_id': _deviceId,
        'application': 'customer',
        'platform': 'android',
        'marketing_opt_in': model.marketing && model.promoPush,
      });
      _registered = true;
      _update('Avisos de pedidos activados en este dispositivo.');
    } on ApiException catch (_) {
      _registered = false;
      _update('Avisos sin registrar. Revisa tu conexión o inténtalo de nuevo.');
    } catch (_) {
      _registered = false;
      _update('No fue posible registrar este dispositivo.');
    }
  }

  Future<void> setMarketing(bool enabled) async {
    model.setPromoPush(enabled);
    await NativeBridge.setPushMarketing(enabled);
    if (!configured || !_registered || !model.signedIn) return;
    try {
      await model.api.put('/mobile-push/devices/$_deviceId/preferences',
          <String, dynamic>{'marketing_opt_in': enabled && model.marketing});
    } catch (_) {
      _update('No pudimos guardar la preferencia de promociones en el servidor.');
    }
  }

  Future<void> disable() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      if (_registered && _deviceId.isNotEmpty && model.signedIn) {
        await model.api.delete('/mobile-push/devices/$_deviceId');
      }
      model.setOrderPush(false);
      await NativeBridge.setPushEnabled(false);
      _registered = false;
      await FirebaseMessaging.instance.deleteToken();
      _update('Notificaciones push desactivadas en este dispositivo.');
    } catch (_) {
      _update('No pudimos desactivar los avisos. Inténtalo otra vez.');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Ejecutar ANTES de borrar el bearer; cerrar sesión no debe conservar
  /// notificaciones privadas en un teléfono compartido.
  void signOut() {
    if (!_firebaseReady || (!model.signedIn && !_registered && !_hadSession)) return;
    if (_deviceId.isNotEmpty && model.api.token != null) {
      unawaited(model.api.delete('/mobile-push/devices/$_deviceId').catchError((Object _) => null));
    }
    unawaited(FirebaseMessaging.instance.deleteToken().catchError((Object _) {}));
    _registered = false;
    _hadSession = false;
  }

  void _onMessage(RemoteMessage message) {
    if (!model.signedIn) return;
    unawaited(model.refreshNotifications());
    if (safePushOrderId(message.data) != null) unawaited(model.refreshOrders());
  }

  void _onOpened(RemoteMessage message) {
    final int? orderId = safePushOrderId(message.data);
    if (!model.signedIn) {
      // El usuario debe autenticarse para consultar los detalles de un pedido.
      _pendingOrderOpen = orderId;
      _pendingTap = true;
      return;
    }
    _openWhenReady(orderId);
  }

  void _openWhenReady(int? orderId) {
    if (!model.signedIn || _disposed) return;
    if (orderId != null) model.pendingOrderId = orderId;
    model.setTab(orderId == null ? 3 : 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && model.signedIn) unawaited(_navigateToPush(orderId));
    });
  }

  Future<void> _navigateToPush(int? orderId) async {
    if (_disposed || !model.signedIn) return;
    if (orderId == null) {
      await model.refreshNotifications();
      if (_disposed || !model.signedIn) return;
      final NavigatorState? nav = talaNavigatorKey.currentState;
      if (nav != null && nav.mounted) {
        nav.push(premiumRoute(NotificationsScreen(model: model)));
      }
      return;
    }
    await model.refreshOrders();
    if (_disposed || !model.signedIn) return;
    OrderEntry? order;
    for (final OrderEntry candidate in model.orders) {
      if (candidate.id == orderId) {
        order = candidate;
        break;
      }
    }
    if (order == null) return;
    final NavigatorState? nav = talaNavigatorKey.currentState;
    if (nav == null || !nav.mounted) return;
    final Widget page = order.canShowTrackingMap
        ? TrackingScreen(model: model, order: order)
        : OrderDetailScreen(model: model, order: order);
    nav.push(premiumRoute(page));
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_foreground?.cancel());
    unawaited(_opened?.cancel());
    unawaited(_rotations?.cancel());
    super.dispose();
  }
}

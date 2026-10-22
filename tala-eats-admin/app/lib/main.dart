import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'admin_api.dart';
import 'admin_support.dart';
import 'admin_restaurants.dart';
import 'admin_registration.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TalaEatsAdminApp());
}

enum AdminStage { loading, unconfigured, signedOut, enrollMfa, signedIn }

class AdminController extends ChangeNotifier {
  AdminController({AdminApi? api, FlutterSecureStorage? storage})
      : api = api ?? AdminApi(),
        storage = storage ?? const FlutterSecureStorage();

  static const _key = 'talaeats_admin_session_v1';
  final AdminApi api;
  final FlutterSecureStorage storage;
  AdminStage stage = AdminStage.loading;
  Map<String, dynamic>? user;
  Map<String, dynamic> stats = {};
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> applications = [];
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> tickets = [];
  List<Map<String, dynamic>> restaurants = [];
  int tab = 0;
  bool busy = false;
  String? error;
  String? notice;
  String? mfaSecret;

  void _signal() => notifyListeners();
  Future<void> bootstrap() async {
    if (!api.configured) {
      stage = AdminStage.unconfigured;
      _signal();
      return;
    }
    try {
      final remembered = await storage.read(key: _key);
      if (remembered == null || remembered.isEmpty) {
        stage = AdminStage.signedOut;
      } else {
        api.token = remembered;
        final me = await api.me();
        if (me['role'] == 'admin' && me['two_factor_enabled'] == true) {
          // /auth/me comprueba identidad, pero /admin/stats comprueba además
          // la sesión MFA efectiva. Un JWT previo al alta de 2FA no basta.
          stats = await api.stats();
          user = me;
          stage = AdminStage.signedIn;
        } else {
          await _forget();
          stage = AdminStage.signedOut;
        }
      }
    } catch (_) {
      await _forget();
      stage = AdminStage.signedOut;
    }
    _signal();
    if (stage == AdminStage.signedIn) await refresh();
  }

  Future<void> _forget() async {
    api.token = null;
    user = null;
    mfaSecret = null;
    notice = null;
    stats = {};
    orders = [];
    applications = [];
    users = [];
    tickets = [];
    restaurants = [];
    try {
      await storage.delete(key: _key);
    } catch (_) {
      // Falla de storage: no mantener token en memoria.
    }
  }

  Future<void> login(String email, String password, String otp) async {
    if (busy) return;
    busy = true;
    error = null;
    notice = null;
    _signal();
    try {
      final identity = await api.login(email, password, otp);
      user = identity;
      if (identity['two_factor_enabled'] == true) {
        await storage.write(key: _key, value: api.token);
        stage = AdminStage.signedIn;
      } else {
        // No persistir token de cuenta privilegiada sin factor activo.
        stage = AdminStage.enrollMfa;
      }
    } catch (e) {
      error = e.toString();
      await _forget();
      stage = AdminStage.signedOut;
    } finally {
      busy = false;
      _signal();
    }
    if (stage == AdminStage.signedIn) await refresh();
  }

  Future<void> startMfa() async {
    if (busy) return;
    busy = true;
    error = null;
    _signal();
    try {
      final setup = await api.mfaSetup();
      mfaSecret = setup['secret'] as String;
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      _signal();
    }
  }

  Future<void> confirmMfa(String otp) async {
    if (busy) return;
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      error = 'Ingresa los 6 dígitos del autenticador.';
      _signal();
      return;
    }
    busy = true;
    error = null;
    _signal();
    try {
      await api.mfaConfirm(otp);
      // La sesión original fue emitida ANTES de probar TOTP: el JWT
      // conserva mfa=false. Revocarla y exigir nuevo login con OTP.
      try {
        await api.logout();
      } catch (_) {
        // Aun sin red, jamás reutilizar ese token temporal.
      }
      await _forget();
      stage = AdminStage.signedOut;
      notice = 'Autenticador activado. Inicia sesión de nuevo '
          'con tu contraseña y el código TOTP para entrar al panel.';
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      _signal();
    }
    if (stage == AdminStage.signedIn) await refresh();
  }

  Future<void> selectTab(int selected) async {
    tab = selected;
    error = null;
    _signal();
    await refresh();
  }

  Future<void> refresh() async {
    if (stage != AdminStage.signedIn || busy) return;
    busy = true;
    error = null;
    _signal();
    // Nunca presentar un snapshot anterior como si fuera información actual.
    if (tab == 0) stats = {};
    if (tab == 1) orders = [];
    if (tab == 2) tickets = [];
    if (tab == 3) restaurants = [];
    if (tab == 4) {
      applications = [];
      users = [];
    }
    _signal();
    try {
      if (tab == 0) {
        stats = await api.stats();
      } else if (tab == 1) {
        orders = await api.collection('/admin/orders?limit=50&offset=0');
      } else if (tab == 2) {
        tickets = await api.collection('/admin/support?status=all&limit=200');
      } else if (tab == 3) {
        restaurants = await api.collection('/admin/restaurants?filter=all&limit=100');
      } else {
        final nextApplications =
            await api.collection('/operations/admin/onboarding');
        final nextUsers =
            await api.collection('/admin/users?limit=50&offset=0');
        applications = nextApplications;
        users = nextUsers;
      }
    } on AdminApiException catch (e) {
      if (e.status == 401 || e.status == 403) {
        await _forget();
        stage = AdminStage.signedOut;
      }
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      _signal();
    }
  }

  Future<bool> decide(int id, String status, String notes) async {
    if (busy || stage != AdminStage.signedIn) return false;
    busy = true;
    error = null;
    _signal();
    try {
      await api.decideOnboarding(id, status, notes);
      busy = false;
      await refresh();
      return stage == AdminStage.signedIn && error == null;
    } on AdminApiException catch (e) {
      if (e.status == 401 || e.status == 403) {
        await _forget();
        stage = AdminStage.signedOut;
      }
      error = e.message;
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      _signal();
    }
  }

  Future<bool> supportAction(int id, String status, String reply) async {
    if (busy || stage != AdminStage.signedIn) return false;
    busy = true;
    error = null;
    _signal();
    try {
      await api.respondSupport(id, status, reply);
      busy = false;
      await refresh();
      return stage == AdminStage.signedIn && error == null;
    } on AdminApiException catch (e) {
      if (e.status == 401 || e.status == 403) {
        await _forget();
        stage = AdminStage.signedOut;
      }
      error = e.message;
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      _signal();
    }
  }

  Future<bool> restaurantAction(int id, String operation,
      {String confirmName = '', String reason = ''}) async {
    if (busy || stage != AdminStage.signedIn) return false;
    busy = true;
    error = null;
    _signal();
    try {
      if (operation == 'archive') {
        await api.archiveRestaurant(id, confirmName, reason);
      } else if (operation == 'suspend') {
        await api.suspendRestaurant(id);
      } else {
        throw const AdminApiException(422, 'Acción no soportada.');
      }
      busy = false;
      await refresh();
      return stage == AdminStage.signedIn && error == null;
    } on AdminApiException catch (e) {
      if (e.status == 401 || e.status == 403) {
        await _forget();
        stage = AdminStage.signedOut;
      }
      error = e.message;
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      _signal();
    }
  }

  Future<void> logout() async {
    try {
      if (api.token != null) await api.logout();
    } catch (_) {
      // La sesión local siempre se borra, incluso si el servidor está caído.
    }
    await _forget();
    stage = AdminStage.signedOut;
    tab = 0;
    error = null;
    notice = null;
    _signal();
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }
}

const _orange = Color(0xFFF56A21);
const _ink = Color(0xFF192337);
const _canvas = Color(0xFFF6F7FA);

class TalaEatsAdminApp extends StatefulWidget {
  const TalaEatsAdminApp({super.key, this.controller});
  final AdminController? controller;

  @override
  State<TalaEatsAdminApp> createState() => _TalaEatsAdminAppState();
}

class _TalaEatsAdminAppState extends State<TalaEatsAdminApp> {
  late final AdminController control;
  late final bool ownsController;
  @override
  void initState() {
    super.initState();
    ownsController = widget.controller == null;
    control = widget.controller ?? AdminController();
    control.bootstrap();
  }

  @override
  void dispose() {
    if (ownsController) control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Tala Eats Admin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _canvas,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _orange,
            surface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: _ink,
            centerTitle: false,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        home: ListenableBuilder(
          listenable: control,
          builder: (context, _) {
            switch (control.stage) {
              case AdminStage.loading:
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              case AdminStage.unconfigured:
                return const _ConfigurationScreen();
              case AdminStage.signedOut:
                return _LoginScreen(control: control);
              case AdminStage.enrollMfa:
                return _MfaScreen(control: control);
              case AdminStage.signedIn:
                return _AdminShell(control: control);
            }
          },
        ),
      );
}

class _ConfigurationScreen extends StatelessWidget {
  const _ConfigurationScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.security_rounded, size: 54, color: _orange),
                SizedBox(height: 20),
                Text('Tala Eats Admin', style: TextStyle(
                    fontSize: 27, fontWeight: FontWeight.w800)),
                SizedBox(height: 12),
                Text('Falta configurar la URL HTTPS del backend ADMIN.',
                    textAlign: TextAlign.center),
                SizedBox(height: 12),
                Text('Compila con --dart-define=TALAEATS_ADMIN_API_BASE_URL=https://TU-SERVIDOR/api/v1',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ),
      );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.local_dining_rounded, color: _orange, size: 28),
            SizedBox(width: 9),
            Text('TALA EATS', style: TextStyle(fontSize: 17,
                fontWeight: FontWeight.w900, letterSpacing: 1.8, color: _ink)),
            SizedBox(width: 10),
            _Tag(text: 'ADMIN'),
          ]),
          const SizedBox(height: 28),
          Text(title, style: const TextStyle(
              fontSize: 29, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
        ],
      );
}

class _LoginScreen extends StatefulWidget {
  const _LoginScreen({required this.control});
  final AdminController control;
  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final otp = TextEditingController();
  bool hidden = true;
  bool checkingApi = false;
  Future<void> checkConnection() async {
    if (checkingApi) return;
    setState(() => checkingApi = true);
    String message;
    try {
      message = await widget.control.api.connectionInfo();
    } catch (_) {
      message = 'No se pudo comprobar la API. Verifica el servidor '
          'y la conexión a Internet.';
    }
    if (!mounted) return;
    setState(() => checkingApi = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 7)));
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(27),
                decoration: _panelDecoration(),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _BrandHeader(
                          title: 'Centro de operaciones',
                          subtitle: 'Acceso privado para personal autorizado.'),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: checkingApi ? null : checkConnection,
                        icon: checkingApi
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.wifi_tethering_rounded),
                        label: Text(checkingApi
                            ? 'Comprobando conexión…'
                            : 'Probar conexión al backend'),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                            labelText: 'Correo administrativo',
                            prefixIcon: Icon(Icons.alternate_email_rounded)),
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Ingresa un correo válido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: password,
                        obscureText: hidden,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: hidden ? 'Mostrar contraseña' : 'Ocultar contraseña',
                            icon: Icon(hidden ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => hidden = !hidden),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Ingresa tu contraseña' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: otp,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6)],
                        decoration: const InputDecoration(
                          labelText: 'Código TOTP (si ya tienes 2FA)',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (widget.control.error != null) _ErrorLabel(
                          message: widget.control.error!),
                      if (widget.control.notice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(widget.control.notice!,
                              style: const TextStyle(
                                  color: Color(0xFF276749),
                                  fontWeight: FontWeight.w600)),
                        ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: widget.control.busy ? null : () {
                          if (form.currentState!.validate()) {
                            widget.control.login(email.text, password.text, otp.text);
                          }
                        },
                        child: widget.control.busy
                            ? const SizedBox(height: 21, width: 21,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Acceder al panel'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: widget.control.busy ? null : () async {
                          final created = await Navigator.of(context)
                              .push<String>(MaterialPageRoute(
                                  builder: (_) => AdminRegistrationScreen(
                                      api: widget.control.api)));
                          if (!mounted || created == null) return;
                          email.text = created;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text(
                              'Cuenta estándar creada. El acceso ADMIN '
                              'requiere habilitación privada y 2FA.')),
                          );
                        },
                        icon: const Icon(Icons.person_add_alt_outlined),
                        label: const Text('Crear cuenta'),
                      ),
                      const SizedBox(height: 22),
                      const Text('Protegido por autenticación y verificación en dos pasos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _MfaScreen extends StatefulWidget {
  const _MfaScreen({required this.control});
  final AdminController control;
  @override
  State<_MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<_MfaScreen> {
  final code = TextEditingController();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Seguridad ADMIN'),
          actions: [TextButton(onPressed: widget.control.logout,
            child: const Text('Salir'))]),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: _panelDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandHeader(
                        title: 'Activa tu autenticador',
                        subtitle: 'Se requiere TOTP para administrar Tala Eats.'),
                    const SizedBox(height: 20),
                    const Text('Instala una app autenticadora. Genera una clave y añádela manualmente en tu autenticador.',
                        style: TextStyle(height: 1.45)),
                    const SizedBox(height: 18),
                    if (widget.control.mfaSecret == null)
                      FilledButton.icon(
                        onPressed: widget.control.busy ? null : widget.control.startMfa,
                        icon: const Icon(Icons.shield_outlined),
                        label: const Text('Generar clave TOTP'),
                      )
                    else ...[
                      const Text('Clave de configuración (no la compartas):',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 9),
                      SelectableText(widget.control.mfaSecret!,
                          style: const TextStyle(
                              fontSize: 16, letterSpacing: 1.3,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: code,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Código de 6 dígitos',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: widget.control.busy ? null :
                            () => widget.control.confirmMfa(code.text),
                        child: const Text('Confirmar y acceder'),
                      ),
                    ],
                    if (widget.control.busy) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    if (widget.control.error != null) ...[
                      const SizedBox(height: 14),
                      _ErrorLabel(message: widget.control.error!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _AdminShell extends StatelessWidget {
  const _AdminShell({required this.control});
  final AdminController control;
  static const titles = [
    'Resumen general', 'Pedidos recientes', 'Soporte al cliente',
    'Restaurantes', 'Gestión de cuentas',
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 19,
          title: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_dining_rounded, color: _orange),
            SizedBox(width: 8),
            Text('Tala Eats', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(width: 7),
            _Tag(text: 'ADMIN'),
          ]),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: control.busy ? null : control.refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: control.logout,
              icon: const Icon(Icons.logout_rounded),
            ),
            const SizedBox(width: 7),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: RefreshIndicator(
                onRefresh: control.refresh,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(titles[control.tab], style: const TextStyle(
                        fontSize: 25, fontWeight: FontWeight.w800, color: _ink)),
                    const SizedBox(height: 7),
                    Text('Hola, ${control.user?['name'] ?? 'ADMIN'} · Datos de la API compartida',
                        style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 20),
                    if (control.busy) const LinearProgressIndicator(minHeight: 3),
                    if (control.error != null) ...[
                      const SizedBox(height: 13),
                      _ErrorLabel(message: control.error!),
                    ],
                    const SizedBox(height: 18),
                    if (control.tab == 0) ...[
                      _StatsGrid(data: control.stats),
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Los importes provienen de pedidos no cancelados y '
                          'pueden incluir pedidos pendientes de pago. '
                          'No representan ingresos cobrados ni utilidad neta.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ),
                    ],
                    if (control.tab == 1) _OrdersList(orders: control.orders),
                    if (control.tab == 2) AdminSupportPanel(
                      tickets: control.tickets, busy: control.busy,
                      writesEnabled: control.api.writesEnabled,
                      onRespond: control.supportAction,
                      error: control.error),
                    if (control.tab == 3) AdminRestaurantsPanel(
                      restaurants: control.restaurants, busy: control.busy,
                      writesEnabled: control.api.writesEnabled,
                      onAction: (id, action, name, reason) =>
                          control.restaurantAction(id, action,
                            confirmName: name, reason: reason),
                      error: control.error),
                    if (control.tab == 4) ...[
                      const Text('Solicitudes de alta', style: TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      _OnboardingList(control: control),
                      const SizedBox(height: 24),
                      const Text('Usuarios registrados', style: TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      _UsersList(users: control.users),
                    ],
                    const SizedBox(height: 26),
                    const Text('Operaciones administrativas sujetas a permisos del servidor y auditoría. '
                        'Pagos y retiros no están habilitados en esta app.',
                        style: TextStyle(color: Colors.black45, fontSize: 12),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: control.tab,
          onDestinationSelected: control.busy ? null : control.selectTab,
          height: 72,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Pedidos'),
            NavigationDestination(icon: Icon(Icons.support_agent_outlined),
                selectedIcon: Icon(Icons.support_agent_rounded), label: 'Soporte'),
            NavigationDestination(icon: Icon(Icons.store_outlined),
                selectedIcon: Icon(Icons.store_rounded), label: 'Tiendas'),
            NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined),
                selectedIcon: Icon(Icons.admin_panel_settings_rounded), label: 'Gestión'),
          ],
        ),
      );
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final cards = <(String, String, IconData)>[
      ('Pedidos totales', '${data['orders'] ?? '—'}', Icons.shopping_bag_outlined),
      ('Pedidos activos', '${data['active_orders'] ?? '—'}', Icons.delivery_dining_outlined),
      ('Restaurantes', '${data['restaurants'] ?? '—'}', Icons.storefront_outlined),
      ('Repartidores', '${data['drivers'] ?? '—'}', Icons.two_wheeler_outlined),
      ('Usuarios', '${data['users'] ?? '—'}', Icons.people_alt_outlined),
      ('Soporte abierto', '${data['support_open'] ?? '—'}', Icons.support_agent_outlined),
      ('Importe no cancelado', '\$ ${data['gross_sales'] ?? '—'}', Icons.attach_money_rounded),
      ('Comisiones calculadas', '\$ ${data['commissions'] ?? '—'}', Icons.account_balance_wallet_outlined),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth >= 760 ? 4 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: constraints.maxWidth < 390 ? 1.05 : 1.25,
          crossAxisSpacing: 12, mainAxisSpacing: 12,
        ),
        itemBuilder: (context, i) {
          final card = cards[i];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: _panelDecoration(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(card.$3, color: _orange),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                  child: Text(card.$2, style: const TextStyle(fontSize: 25,
                      fontWeight: FontWeight.w800, color: _ink))),
                Text(card.$1, maxLines: 2, style: const TextStyle(
                    fontSize: 12, color: Colors.black54)),
              ],
            ),
          );
        },
      );
    });
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.orders});
  final List<Map<String, dynamic>> orders;
  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const _EmptyData(message: 'No hay pedidos recientes.');
    return Column(children: orders.map((order) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16), decoration: _panelDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Pedido #${order['id']}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            _Tag(text: '${order['status'] ?? 'sin estado'}'),
          ]),
          const SizedBox(height: 8),
          Text('Restaurante #${order['restaurant_id']} · Cliente #${order['user_id']}',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 7),
          Text('Total: \$ ${order['total'] ?? '—'} · Pago: ${order['payment_status'] ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    )).toList());
  }
}

class _UsersList extends StatelessWidget {
  const _UsersList({required this.users});
  final List<Map<String, dynamic>> users;
  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const _EmptyData(message: 'No hay usuarios disponibles.');
    return Column(children: users.map((user) => Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.all(14), decoration: _panelDecoration(),
        child: Row(children: [
          const CircleAvatar(backgroundColor: Color(0xFFFFEEE1),
              child: Icon(Icons.person_rounded, color: _orange)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${user['name'] ?? 'Usuario'}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${user['email'] ?? ''}', maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          )),
          _Tag(text: '${user['role'] ?? '—'}'),
        ]),
      ),
    )).toList());
  }
}

class _OnboardingList extends StatelessWidget {
  const _OnboardingList({required this.control});
  final AdminController control;

  Future<void> _decision(BuildContext context, int id, String status) async {
    final note = TextEditingController();
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(status == 'approved' ? 'Confirmar aprobación'
              : status == 'rejected' ? 'Rechazar solicitud'
              : 'Solicitar información'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Solicitud #$id. Esta decisión se guardará en el backend y '
                'puede afectar el acceso del comercio o repartidor.'),
            const SizedBox(height: 13),
            TextField(
              controller: note,
              maxLength: 300,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: status == 'approved'
                      ? 'Nota interna (opcional)' : 'Motivo obligatorio'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (status != 'approved' && note.text.trim().length < 8) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Explica el motivo (mínimo 8 caracteres).')));
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (accepted != true || !context.mounted) return;
      final ok = await control.decide(id, status, note.text);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Decisión guardada y listado actualizado.'
            : control.error ?? 'No se pudo guardar la decisión.'),
      ));
    } finally {
      note.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (control.applications.isEmpty) {
      return const _EmptyData(message: 'No hay solicitudes para revisar.');
    }
    return Column(children: control.applications.map((item) {
      final id = (item['id'] as num?)?.toInt() ?? 0;
      final state = '${item['status'] ?? 'pending'}';
      final pending = state == 'pending' || state == 'needs_info';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(16), decoration: _panelDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(
                '${item['business_name']?.toString().isNotEmpty == true ? item['business_name'] : item['entity_type'] == 'driver' ? 'Repartidor' : 'Comercio'} · #$id',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              _Tag(text: state),
            ]),
            const SizedBox(height: 6),
            Text('Tipo: ${item['entity_type'] ?? '—'} · Solicitante #${item['user_id'] ?? '—'}',
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
            if ((item['notes'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${item['notes']}', style: const TextStyle(fontSize: 13)),
            ],
            if (pending && id > 0 && control.api.writesEnabled) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.tonal(
                  onPressed: control.busy ? null :
                      () => _decision(context, id, 'approved'),
                  child: const Text('Aprobar'),
                ),
                OutlinedButton(
                  onPressed: control.busy ? null :
                      () => _decision(context, id, 'needs_info'),
                  child: const Text('Pedir datos'),
                ),
                TextButton(
                  onPressed: control.busy ? null :
                      () => _decision(context, id, 'rejected'),
                  child: const Text('Rechazar'),
                ),
              ]),
            ],
            if (pending && !control.api.writesEnabled) ...[
              const SizedBox(height: 10),
              const Text('Decisiones desactivadas en esta compilación de consulta.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ]),
        ),
      );
    }).toList());
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEFE5),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text.toUpperCase(), maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, letterSpacing: 0.5,
                fontWeight: FontWeight.w800, color: Color(0xFFA64B15))),
      );
}

class _EmptyData extends StatelessWidget {
  const _EmptyData({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
        decoration: _panelDecoration(),
        child: Column(children: [
          const Icon(Icons.inbox_outlined, size: 34, color: Colors.black38),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
        ]),
      );
}

class _ErrorLabel extends StatelessWidget {
  const _ErrorLabel({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE9E7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message, style: const TextStyle(
            color: Color(0xFF983B31), fontSize: 13)),
      );
}

BoxDecoration _panelDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE9EBF0)),
      boxShadow: const [
        BoxShadow(color: Color(0x09000000), blurRadius: 16, offset: Offset(0, 5)),
      ],
    );

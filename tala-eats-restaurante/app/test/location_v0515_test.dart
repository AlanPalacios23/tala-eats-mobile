// v0.5.15: ubicación del establecimiento (dirección + GPS) y efectos.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talaeats_restaurant/core/theme.dart';
import 'package:talaeats_restaurant/data/app_services.dart';
import 'package:talaeats_restaurant/data/device_location.dart';
import 'package:talaeats_restaurant/data/local/qa_scenario.dart';
import 'package:talaeats_restaurant/data/location_store.dart';
import 'package:talaeats_restaurant/data/remote/remote_api.dart';
import 'package:talaeats_restaurant/data/repositories.dart';
import 'package:talaeats_restaurant/main.dart';
import 'package:talaeats_restaurant/models/restaurant_location.dart';
import 'package:talaeats_restaurant/screens/more/location_screen.dart';
import 'package:talaeats_restaurant/widgets/motion.dart';

class _FakeMedia implements MediaRepository {
  @override
  Future<String?> pickImage({
    required MediaSource source,
    required MediaPurpose purpose,
  }) async =>
      'test/fixtures/${purpose.name}.jpg';
}

class _FakeDevice extends DeviceLocationProvider {
  _FakeDevice({this.fix, this.issue});

  final GpsFix? fix;
  final LocationIssue? issue;
  int settingsCalls = 0;
  int fixCalls = 0;

  @override
  Future<GpsFix> currentFix() async {
    fixCalls++;
    final failure = issue;
    if (failure != null) throw failure;
    return fix!;
  }

  @override
  Future<bool> openSettings(LocationIssueKind kind) async {
    settingsCalls++;
    return true;
  }
}

class _TestSession extends RemoteSessionStore {
  @override
  Future<String?> accessToken() async => 'fake-token-test';

  @override
  Future<String?> deviceToken() async => null;

  @override
  Future<String> deviceId() async => 'test-device-123456';
}

const GpsFix _goodFix = GpsFix(
  latitude: 20.654412,
  longitude: -103.701223,
  accuracyMeters: 12,
);

const RestaurantLocation _sample = RestaurantLocation(
  street: 'Av. Juárez 184',
  neighborhood: 'Centro',
  city: 'Tala',
  postalCode: '45300',
  references: 'Fachada naranja',
  latitude: 20.654412,
  longitude: -103.701223,
  accuracyMeters: 12,
);

Finder _key(String key) => find.byKey(ValueKey<String>(key));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Abre la pantalla de ubicación desde un botón (para poder cerrarla).
Future<void> _openLocation(
  WidgetTester tester, {
  required RestaurantLocationStore store,
  required DeviceLocationProvider device,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push<String>(
                appRoute<String>(
                  RestaurantLocationScreen(
                    restaurantId: 101,
                    store: store,
                    device: device,
                  ),
                ),
              ),
              child: const Text('abrir ubicación'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir ubicación'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('modelo y guardado', () {
    test('dirección completa, una línea y coordenadas', () {
      expect(_sample.isComplete, isTrue);
      expect(_sample.singleLine, 'Av. Juárez 184, Centro, Tala, 45300');
      expect(_sample.coordinatesLabel, '20.65441, -103.70122');
      const partial = RestaurantLocation(
        street: 'Calle 1',
        neighborhood: '',
        city: 'Tala',
        postalCode: '453',
      );
      expect(partial.isComplete, isFalse);
      expect(partial.hasCoordinates, isFalse);
      final copy = RestaurantLocation.fromJson(_sample.toJson());
      expect(copy.singleLine, _sample.singleLine);
      expect(copy.latitude, _sample.latitude);
      expect(copy.syncedToServer, isFalse);
    });

    test('guardado local: queda en el teléfono como pendiente de enviar',
        () async {
      const store = LocalRestaurantLocationStore();
      expect(store.sendsToServer, isFalse);
      expect(await store.load(101), isNull);
      final saved = await store.save(101, _sample);
      expect(saved.syncedToServer, isFalse);
      final loaded = await store.load(101);
      expect(loaded!.street, 'Av. Juárez 184');
      expect(loaded.longitude, -103.701223);
      expect(await store.load(202), isNull);
    });

    test('envío remoto usa solo los campos configurados', () async {
      final requests = <http.Request>[];
      final api = RemoteApi(
        session: _TestSession(),
        client: MockClient((http.Request request) async {
          requests.add(request);
          // El backend productivo devuelve la ubicación confirmada; un
          // simple HTTP 200 sin dirección/GPS NO permite marcarla como guardada.
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 101,
              'address': _sample.singleLine,
              'lat': _sample.latitude,
              'lng': _sample.longitude,
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
      );
      final store = RemoteRestaurantLocationStore(
        api,
        const LocationServerFields(
          path: '/owner/restaurant',
          address: 'address',
          latitude: 'lat',
          longitude: 'lng',
        ),
        const LocalRestaurantLocationStore(),
      );
      final saved = await store.save(101, _sample);
      expect(saved.syncedToServer, isTrue);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'PATCH');
      expect(requests.single.url.path, '/api/v1/owner/restaurant');
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), <String>{'address', 'lat', 'lng'});
      expect(body['address'], 'Av. Juárez 184, Centro, Tala, 45300');
      expect(body['lat'], _sample.latitude);
      expect(body['lng'], _sample.longitude);
      expect((await store.load(101))!.syncedToServer, isTrue);
    });
  });

  group('pantalla de ubicación', () {
    testWidgets('GPS + dirección se guardan y la pantalla se cierra',
        (tester) async {
      const store = LocalRestaurantLocationStore();
      final device = _FakeDevice(fix: _goodFix);
      await _openLocation(tester, store: store, device: device);

      expect(find.text('Ubicación del establecimiento'), findsOneWidget);
      expect(find.text('Sin punto GPS'), findsOneWidget);
      expect(_key('locationLocalNotice'), findsOneWidget);

      await _tap(tester, _key('useMyLocationButton'));
      expect(device.fixCalls, 1);
      expect(find.text('20.65441, -103.70122'), findsOneWidget);
      expect(find.text('±12 m'), findsOneWidget);
      expect(_key('locationImprecise'), findsNothing);

      await tester.enterText(_key('locationStreetField'), 'Av. Juárez 184');
      await tester.enterText(_key('locationNeighborhoodField'), 'Centro');
      await tester.enterText(_key('locationCityField'), 'Tala');
      await tester.enterText(_key('locationPostalField'), '45300');
      await _tap(tester, _key('saveLocationButton'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Ubicación del establecimiento'), findsNothing);
      final saved = await store.load(101);
      expect(saved!.isComplete, isTrue);
      expect(saved.latitude, closeTo(20.654412, 1e-9));
    });

    testWidgets('sin dirección no guarda y explica qué falta', (tester) async {
      const store = LocalRestaurantLocationStore();
      await _openLocation(tester, store: store, device: _FakeDevice());

      await _tap(tester, _key('saveLocationButton'));
      expect(find.text('Escribe la calle y el número.'), findsOneWidget);
      expect(find.text('5 dígitos.'), findsOneWidget);
      expect(await store.load(101), isNull);
    });

    testWidgets('permiso bloqueado ofrece abrir ajustes', (tester) async {
      final device = _FakeDevice(
        issue: const LocationIssue(LocationIssueKind.deniedForever),
      );
      await _openLocation(
        tester,
        store: const LocalRestaurantLocationStore(),
        device: device,
      );

      await _tap(tester, _key('useMyLocationButton'));
      expect(_key('locationIssue'), findsOneWidget);
      expect(find.text('El permiso de ubicación está bloqueado'), findsOneWidget);
      await _tap(tester, find.text('Abrir ajustes'));
      expect(device.settingsCalls, 1);
    });

    testWidgets('señal imprecisa pide repetir', (tester) async {
      await _openLocation(
        tester,
        store: const LocalRestaurantLocationStore(),
        device: _FakeDevice(
          fix: const GpsFix(
            latitude: 20.6,
            longitude: -103.7,
            accuracyMeters: 240,
          ),
        ),
      );
      await _tap(tester, _key('useMyLocationButton'));
      expect(_key('locationImprecise'), findsOneWidget);
      expect(find.text('Señal imprecisa (±240 m)'), findsOneWidget);
    });
  });

  testWidgets('perfil y Más llevan a la ubicación', (tester) async {
    await tester.pumpWidget(
      TalaEatsRestaurantApp(
        services: AppServices.local(
          latency: const LocalLatency(
            read: Duration(milliseconds: 40),
            write: Duration(milliseconds: 40),
          ),
          scenario: QaScenario.normal,
          media: _FakeMedia(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, _key('alreadyHaveAccountButton'));
    await tester.enterText(_key('loginEmail'), 'propietario@correo.mx');
    await tester.enterText(_key('loginPassword'), 'clave-segura');
    await _tap(tester, _key('loginSubmitButton'));

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Más'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_key('moreLocationRow'), findsOneWidget);

    await _tap(tester, _key('editRestaurantButton'));
    expect(find.text('Agrega la dirección de tu local'), findsOneWidget);
    await _tap(tester, _key('locationSummary'));
    expect(find.text('Ubicación del establecimiento'), findsOneWidget);
    expect(_key('useMyLocationButton'), findsOneWidget);
  });

  testWidgets('importe con conteo animado termina en el valor real',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CountUpMoney(1284.5, style: TextStyle(fontSize: 20)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(r'$1,284.50'), findsOneWidget);
  });
}

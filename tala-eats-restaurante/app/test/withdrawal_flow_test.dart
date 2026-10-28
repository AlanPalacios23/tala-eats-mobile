// Retiros v0.5.11: experiencia completa SIN dinero real.
//
// Verifica: acceso desde Finanzas, estados de cuenta bancaria, saldo nunca
// inventado, CTA final bloqueado, historial honesto, contención de doble
// toque, idempotencia y que el flujo no crea clientes HTTP.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talaeats_restaurant/core/failures.dart';
import 'package:talaeats_restaurant/core/theme.dart';
import 'package:talaeats_restaurant/data/app_services.dart';
import 'package:talaeats_restaurant/data/local/qa_scenario.dart';
import 'package:talaeats_restaurant/data/repositories.dart';
import 'package:talaeats_restaurant/data/withdrawal_gateway.dart';
import 'package:talaeats_restaurant/main.dart';
import 'package:talaeats_restaurant/models/withdrawal.dart';
import 'package:talaeats_restaurant/screens/withdrawals/withdrawal_confirmation.dart';
import 'package:talaeats_restaurant/screens/withdrawals/withdrawals_screen.dart';
import 'package:talaeats_restaurant/state/withdrawal_state.dart';
import 'package:talaeats_restaurant/widgets/buttons.dart';

// ---------------------------------------------------------------------------
// Dobles de prueba
// ---------------------------------------------------------------------------

class _FakeGateway extends WithdrawalGateway {
  _FakeGateway({
    this.overview = const WithdrawalOverview.notConnected(),
    this.records = const <WithdrawalRecord>[],
    this.onboardingError,
    this.onboardingLink,
  });

  WithdrawalOverview overview;
  final List<WithdrawalRecord> records;
  final AppFailure? onboardingError;
  final Uri? onboardingLink;
  Completer<WithdrawalReceipt>? pending;
  int overviewCalls = 0;
  int requestCalls = 0;
  int linkCalls = 0;
  final List<String> keys = <String>[];
  final List<String> codes = <String>[];

  @override
  bool get isConnected => true;

  @override
  Future<WithdrawalOverview> fetchOverview() async {
    overviewCalls++;
    return overview;
  }

  @override
  Future<List<WithdrawalRecord>> fetchHistory() async => records;

  @override
  Future<Uri?> createBankOnboardingLink({String? totp}) async {
    linkCalls++;
    if (onboardingError != null) throw onboardingError!;
    return onboardingLink;
  }

  @override
  Future<WithdrawalReceipt> requestWithdrawal({
    required int amountCents,
    required String totp,
    required String idempotencyKey,
  }) {
    requestCalls++;
    keys.add(idempotencyKey);
    codes.add(totp);
    final waiting = pending;
    if (waiting != null) return waiting.future;
    return Future<WithdrawalReceipt>.error(
      const AppFailure(FailureKind.timeout),
    );
  }
}

/// Cuenta cada cliente HTTP creado dentro de la zona de la prueba.
class _CountingHttpOverrides extends HttpOverrides {
  int created = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    created++;
    return super.createHttpClient(context);
  }
}

const BankAccountSummary _verifiedBank = BankAccountSummary(
  status: BankAccountStatus.verified,
  bankName: 'BBVA',
  last4: '1234',
);

const WithdrawalBalance _balance = WithdrawalBalance(
  currency: 'mxn',
  withdrawableCents: 125000,
  alreadyRequestedCents: 30000,
);

WithdrawalOverview _connected({
  BankAccountSummary bank = _verifiedBank,
  WithdrawalBalance? balance = _balance,
  WithdrawalLimits limits = const WithdrawalLimits(),
}) =>
    WithdrawalOverview(
      integration: WithdrawalIntegration.connected,
      bank: bank,
      balance: balance,
      limits: limits,
      serverAllowsRequests: true,
    );

WithdrawalReceipt _receipt() => WithdrawalReceipt(
      id: 'w_1',
      amountCents: 10000,
      currency: 'mxn',
      receivedAt: DateTime(2026, 10, 12, 14, 5),
    );

Widget _app(Widget home) => MaterialApp(theme: buildAppTheme(), home: home);

/// Monta «Mis retiros» desde cero (sin rutas previas) con [gateway].
Future<void> _pumpScreen(WidgetTester tester, WithdrawalGateway gateway) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    _app(WithdrawalsScreen(key: UniqueKey(), gateway: gateway)),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Completing the security step-up is mandatory even in test doubles.
/// Never expect a bank-onboarding request before the six-digit TOTP.
Future<void> _confirmBankTotp(WidgetTester tester) async {
  final field = find.byKey(const ValueKey<String>('bank-onboarding-totp'));
  expect(field, findsOneWidget);
  await tester.enterText(field, '123456');
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

class _FakeMedia implements MediaRepository {
  @override
  Future<String?> pickImage({
    required MediaSource source,
    required MediaPurpose purpose,
  }) async =>
      'test/fixtures/${purpose.name}.jpg';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // -------------------------------------------------------------------------
  group('modelos de retiro', () {
    test('moneyCents formatea MXN sin pasar por double', () {
      expect(moneyCents(125000), r'$1,250.00 MXN');
      expect(moneyCents(5), r'$0.05 MXN');
      expect(moneyCents(100000000), r'$1,000,000.00 MXN');
    });

    test('parseAmountCents convierte importes escritos a centavos', () {
      expect(parseAmountCents('1500'), 150000);
      expect(parseAmountCents('1500.5'), 150050);
      expect(parseAmountCents('1500,50'), 150050);
      expect(parseAmountCents(r'$ 1,500.50'), 150050);
      expect(parseAmountCents('1.234'), isNull);
      expect(parseAmountCents(''), isNull);
      expect(parseAmountCents('abc'), isNull);
    });

    test('cuenta enmascarada solo si está verificada y con 4 dígitos', () {
      expect(_verifiedBank.maskedLabel, 'BBVA ···· 1234');
      const longNumber = BankAccountSummary(
        status: BankAccountStatus.verified,
        bankName: 'BBVA',
        last4: '012180001234567890',
      );
      expect(longNumber.maskedLabel, 'BBVA ···· 7890');
      expect(longNumber.maskedLabel, isNot(contains('0121800')));
      const pending = BankAccountSummary(
        status: BankAccountStatus.pendingVerification,
        bankName: 'BBVA',
        last4: '1234',
      );
      expect(pending.maskedLabel, isNull);
      expect(const BankAccountSummary.notLinked().maskedLabel, isNull);
    });

    test('«Pagado» solo con estado definitivo del backend', () {
      expect(withdrawalStatusFromBackend('paid'), WithdrawalStatus.paid);
      expect(withdrawalStatusFromBackend('accepted'), WithdrawalStatus.unknown);
      expect(withdrawalStatusFromBackend('202'), WithdrawalStatus.unknown);
      expect(withdrawalStatusFromBackend('processing'),
          WithdrawalStatus.processing);
      expect(_receipt().status, WithdrawalStatus.requested);
    });

    test('saldo incompleto del servidor no se convierte en cero', () {
      expect(
        () => WithdrawalBalance.fromJson(<String, dynamic>{'currency': 'mxn'}),
        throwsFormatException,
      );
      final balance = WithdrawalBalance.fromJson(<String, dynamic>{
        'currency': 'mxn',
        'withdrawable_cents': 5000,
        'already_requested_cents': 0,
        'hold_days': 7,
      });
      expect(balance.withdrawableCents, 5000);
      expect(balance.holdDays, 7);
    });
  });

  // -------------------------------------------------------------------------
  group('controlador de retiros', () {
    test('por defecto los retiros están bloqueados y no llaman al servicio',
        () async {
      expect(kWithdrawalTransfersEnabled, isFalse);
      final gateway = _FakeGateway(overview: _connected());
      final controller = WithdrawalController(gateway);
      await controller.load();
      expect(controller.transfersEnabled, isFalse);
      expect(controller.canRequest, isFalse);
      expect(
        controller.blockers,
        contains(WithdrawalBlocker.transfersDisabled),
      );
      final outcome =
          await controller.submit(amountCents: 10000, totp: '123456');
      expect(outcome.kind, WithdrawalSubmitKind.blocked);
      expect(gateway.requestCalls, 0);
      controller.dispose();
    });

    test('servicio no conectado: sin saldo, sin cuenta, sin historial',
        () async {
      final controller =
          WithdrawalController(const DisconnectedWithdrawalGateway());
      await controller.load();
      final overview = controller.effectiveOverview;
      expect(overview.isConnected, isFalse);
      expect(overview.balance, isNull);
      expect(overview.hasVerifiedBalance, isFalse);
      expect(
        controller.blockers,
        containsAll(<WithdrawalBlocker>[
          WithdrawalBlocker.transfersDisabled,
          WithdrawalBlocker.serviceNotConnected,
          WithdrawalBlocker.balanceUnavailable,
          WithdrawalBlocker.bankNotLinked,
        ]),
      );
      expect(controller.history, isEmpty);
      controller.dispose();
    });

    test('doble toque: un solo envío en curso', () async {
      final gateway = _FakeGateway(overview: _connected())
        ..pending = Completer<WithdrawalReceipt>();
      final controller = WithdrawalController(gateway, transfersEnabled: true);
      await controller.load();
      expect(controller.canRequest, isTrue);

      final first = controller.submit(amountCents: 10000, totp: '123456');
      final second =
          await controller.submit(amountCents: 10000, totp: '123456');
      expect(second.kind, WithdrawalSubmitKind.ignored);
      expect(gateway.requestCalls, 1);

      gateway.pending!.complete(_receipt());
      final result = await first;
      expect(result.kind, WithdrawalSubmitKind.received);
      expect(result.receipt!.status, WithdrawalStatus.requested);
      controller.dispose();
    });

    test('reintento conserva la llave de idempotencia; otro borrador no',
        () async {
      final gateway = _FakeGateway(overview: _connected());
      final controller = WithdrawalController(gateway, transfersEnabled: true);
      await controller.load();

      final a = await controller.submit(amountCents: 10000, totp: '111111');
      final b = await controller.submit(amountCents: 10000, totp: '222222');
      expect(a.kind, WithdrawalSubmitKind.failed);
      expect(b.kind, WithdrawalSubmitKind.failed);
      expect(gateway.keys[0], gateway.keys[1]);
      expect(gateway.keys[0], hasLength(32));

      controller.resetDraft();
      await controller.submit(amountCents: 20000, totp: '333333');
      expect(gateway.keys[2], isNot(gateway.keys[0]));
      controller.dispose();
    });

    test('validación usa solo límites del servidor (sin topes fijos)', () {
      final open = _connected(
        balance: const WithdrawalBalance(
          currency: 'mxn',
          withdrawableCents: 500000,
          alreadyRequestedCents: 0,
        ),
      );
      // Sin límites enviados por el servidor, 2,000 MXN es válido.
      expect(validateWithdrawalAmount('2000', open), isNull);
      expect(
        validateWithdrawalAmount('6000', open),
        WithdrawalAmountIssue.exceedsBalance,
      );
      final limited = _connected(
        balance: open.balance,
        limits: const WithdrawalLimits(
          perRequestCents: 50000,
          dailyRemainingCents: 80000,
        ),
      );
      expect(
        validateWithdrawalAmount('600', limited),
        WithdrawalAmountIssue.exceedsPerRequestLimit,
      );
      expect(
        validateWithdrawalAmount('100', const WithdrawalOverview.notConnected()),
        WithdrawalAmountIssue.cannotValidate,
      );
      expect(
        validateWithdrawalAmount('0', open),
        WithdrawalAmountIssue.invalid,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('pantallas de retiro', () {
    testWidgets('acceso desde Finanzas dentro del panel', (tester) async {
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
      await _tapKey(tester, 'alreadyHaveAccountButton');
      await tester.enterText(
        find.byKey(const ValueKey<String>('loginEmail')),
        'propietario@correo.mx',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('loginPassword')),
        'clave-segura',
      );
      await _tapKey(tester, 'loginSubmitButton');

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Finanzas'),
        ),
      );
      await tester.pumpAndSettle();
      await _tapKey(tester, 'restaurant-withdraw-earnings');
      expect(find.text('Mis retiros'), findsOneWidget);
      expect(find.text('Saldo no disponible'), findsOneWidget);
    });

    testWidgets('sin servicio conectado: nunca muestra un importe',
        (tester) async {
      await _pumpScreen(tester, const DisconnectedWithdrawalGateway());

      expect(find.text('Saldo no disponible'), findsOneWidget);
      expect(find.text('Pendiente de habilitación'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
      expect(find.textContaining('MXN'), findsNothing);
      expect(find.text('No vinculada'), findsOneWidget);
      expect(find.text('Historial pendiente de habilitación'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('withdrawals-disabled-notice')),
        findsOneWidget,
      );
    });

    testWidgets('estados de la cuenta bancaria', (tester) async {
      await _pumpScreen(
        tester,
        _FakeGateway(
          overview: _connected(bank: const BankAccountSummary.notLinked()),
        ),
      );
      expect(find.text('No vinculada'), findsOneWidget);
      expect(find.text('Configurar cuenta bancaria'), findsOneWidget);

      await _pumpScreen(
        tester,
        _FakeGateway(
          overview: _connected(
            bank: const BankAccountSummary(
              status: BankAccountStatus.pendingVerification,
              bankName: 'BBVA',
              last4: '1234',
            ),
          ),
        ),
      );
      expect(find.text('Verificación pendiente'), findsOneWidget);
      expect(find.textContaining('1234'), findsNothing);

      await _pumpScreen(tester, _FakeGateway(overview: _connected()));
      expect(find.text('Verificada'), findsOneWidget);
      expect(find.text('BBVA ···· 1234'), findsOneWidget);
      expect(find.text('Configurar cuenta bancaria'), findsNothing);

      await _pumpScreen(
        tester,
        _FakeGateway(
          overview: _connected(
            bank: const BankAccountSummary(
              status: BankAccountStatus.restricted,
            ),
          ),
        ),
      );
      expect(find.text('Bloqueada / en revisión'), findsOneWidget);
    });

    testWidgets('saldo confirmado por el servicio se muestra tal cual',
        (tester) async {
      await _pumpScreen(tester, _FakeGateway(overview: _connected()));
      expect(find.text(r'$1,250.00 MXN'), findsOneWidget);
      expect(find.text(r'$300.00 MXN'), findsOneWidget);
      expect(find.text('Saldo no disponible'), findsNothing);
    });

    testWidgets('configurar cuenta: explica el registro alojado sin pedir CLABE',
        (tester) async {
      final gateway = _FakeGateway(
        overview: _connected(bank: const BankAccountSummary.notLinked()),
      );
      await _pumpScreen(tester, gateway);
      await _tapKey(tester, 'withdrawals-configure-bank');
      expect(gateway.linkCalls, 0);
      expect(find.text('Verifica tu identidad'), findsOneWidget);
      await _confirmBankTotp(tester);

      expect(gateway.linkCalls, 1);
      expect(find.text('Registro bancario seguro'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await _tapKey(tester, 'bank-info-close');
      expect(find.text('Registro bancario seguro'), findsNothing);
    });

    testWidgets('alta bancaria disponible aunque retiros estén bloqueados',
        (tester) async {
      final gateway = _FakeGateway(
        overview: _connected(bank: const BankAccountSummary.notLinked()),
      );
      await _pumpScreen(tester, gateway);
      expect(find.byKey(const ValueKey<String>('withdrawals-disabled-notice')),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('connect-register-now')),
          findsOneWidget);
      await _tapKey(tester, 'connect-register-now');
      await _confirmBankTotp(tester);
      expect(gateway.linkCalls, 1);
      expect(find.text('Registro bancario seguro'), findsOneWidget);
    });

    testWidgets('al volver de Stripe Android recarga el estado del banco sin mover dinero',
        (tester) async {
      final gateway = _FakeGateway(
        overview: _connected(bank: const BankAccountSummary.notLinked()),
        onboardingLink: Uri.parse('https://connect.stripe.com/setup/test'),
      );
      var opens = 0;
      await tester.pumpWidget(_app(WithdrawalsScreen(
        gateway: gateway,
        openLink: (link) async {
          opens++;
          expect(link.host, 'connect.stripe.com');
          return true;
        },
      )));
      await tester.pumpAndSettle();
      final initial = gateway.overviewCalls;
      await _tapKey(tester, 'connect-register-now');
      await _confirmBankTotp(tester);
      expect(opens, 1);
      expect(gateway.overviewCalls, initial);
      gateway.overview = _connected(bank: _verifiedBank);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(gateway.overviewCalls, greaterThan(initial));
      expect(find.text('Verificada'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('withdrawals-disabled-notice')),
          findsOneWidget);
    });

    testWidgets('un 403 de Connect se muestra sin decir retiros desactivados',
        (tester) async {
      final gateway = _FakeGateway(
        overview: _connected(bank: const BankAccountSummary.notLinked()),
        onboardingError: const AppFailure(FailureKind.twoFactorSetupRequired,
            'Para administrar el banco confirma un código 2FA vigente'),
      );
      await _pumpScreen(tester, gateway);
      await _tapKey(tester, 'connect-register-now');
      await _confirmBankTotp(tester);
      expect(gateway.linkCalls, 1);
      expect(find.byKey(const ValueKey<String>('bank-onboarding-error')),
          findsOneWidget);
      expect(find.textContaining('código 2FA vigente'), findsOneWidget);
      expect(find.text('Registro bancario seguro'), findsNothing);
    });

    testWidgets('cancelar verificación bancaria no genera enlace Stripe',
        (tester) async {
      final gateway = _FakeGateway(
        overview: _connected(bank: const BankAccountSummary.notLinked()),
      );
      await _pumpScreen(tester, gateway);
      await _tapKey(tester, 'withdrawals-configure-bank');
      expect(gateway.linkCalls, 0);
      await tester.tap(find.text('Continuar')); // Sin código: no se avanza.
      await tester.pumpAndSettle();
      expect(find.text('Verifica tu identidad'), findsOneWidget);
      expect(gateway.linkCalls, 0);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(gateway.linkCalls, 0);
      expect(find.text('Registro bancario seguro'), findsNothing);
    });

    testWidgets('nuevo retiro: resumen visible y CTA final bloqueado',
        (tester) async {
      final gateway = _FakeGateway(overview: _connected());
      await _pumpScreen(tester, gateway);
      await _tapKey(tester, 'withdrawals-open-new');

      expect(find.text('Nuevo retiro'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('withdrawal-disabled-banner')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('withdrawal-amount-field')),
        '100',
      );
      await tester.pumpAndSettle();
      expect(find.text('hacia BBVA ···· 1234'), findsOneWidget);

      final submit = find.byKey(const ValueKey<String>('withdrawal-submit'));
      expect(tester.widget<AppButton>(submit).onPressed, isNull);
      expect(find.text('Retiros no habilitados'), findsOneWidget);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(gateway.requestCalls, 0);
      expect(find.byType(WithdrawalTwoFactorSheet), findsNothing);
    });

    testWidgets('nuevo retiro sin saldo verificado: no valida ni inventa',
        (tester) async {
      await _pumpScreen(tester, const DisconnectedWithdrawalGateway());
      await _tapKey(tester, 'withdrawals-open-new');

      expect(find.text('Saldo no disponible'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('withdrawal-amount-field')),
        '250',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No podemos validar este importe'),
          findsOneWidget);
      expect(
        tester
            .widget<AppButton>(
              find.byKey(const ValueKey<String>('withdrawal-submit')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('nuevo retiro: importe mayor al saldo', (tester) async {
      await _pumpScreen(tester, _FakeGateway(overview: _connected()));
      await _tapKey(tester, 'withdrawals-open-new');
      await tester.enterText(
        find.byKey(const ValueKey<String>('withdrawal-amount-field')),
        '5000',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('El importe supera tu saldo disponible para retirar.'),
        findsOneWidget,
      );
    });

    testWidgets('historial: pendiente, vacío y estados del backend',
        (tester) async {
      await _pumpScreen(tester, const DisconnectedWithdrawalGateway());
      await _tapKey(tester, 'withdrawals-open-history');
      expect(find.text('Historial de retiros'), findsOneWidget);
      expect(find.text('Historial pendiente de habilitación'), findsOneWidget);

      await _pumpScreen(tester, _FakeGateway(overview: _connected()));
      await _tapKey(tester, 'withdrawals-open-history');
      expect(find.text('Aún no tienes retiros'), findsOneWidget);

      await _pumpScreen(
        tester,
        _FakeGateway(
          overview: _connected(),
          records: <WithdrawalRecord>[
            WithdrawalRecord.fromJson(<String, dynamic>{
              'id': 1,
              'amount_cents': 50000,
              'currency': 'mxn',
              'status': 'paid',
              'created_at': '2026-10-01T15:00:00Z',
            }),
            WithdrawalRecord.fromJson(<String, dynamic>{
              'id': 2,
              'amount_cents': 30000,
              'currency': 'mxn',
              'status': 'processing',
              'created_at': '2026-10-10T15:00:00Z',
            }),
            WithdrawalRecord.fromJson(<String, dynamic>{
              'id': 3,
              'amount_cents': 10000,
              'currency': 'mxn',
              'status': 'accepted',
              'created_at': '2026-10-11T15:00:00Z',
            }),
          ],
        ),
      );
      await _tapKey(tester, 'withdrawals-open-history');
      expect(find.text('3 retiros'), findsOneWidget);
      expect(find.text('Pagado'), findsOneWidget);
      expect(find.text('En proceso'), findsOneWidget);
      expect(find.text('Por confirmar'), findsOneWidget);
    });

    testWidgets('2FA: formato local, un solo envío y código borrado al fallar',
        (tester) async {
      final completer = Completer<WithdrawalSubmitOutcome>();
      var calls = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: WithdrawalTwoFactorSheet(
              amountLabel: r'$100.00 MXN',
              destinationLabel: 'BBVA ···· 1234',
              onConfirm: (code) {
                calls++;
                return completer.future;
              },
            ),
          ),
        ),
      );
      final field = find.byKey(const ValueKey<String>('withdrawal-otp-field'));
      final confirm =
          find.byKey(const ValueKey<String>('withdrawal-otp-confirm'));

      await tester.enterText(field, '12345');
      await tester.tap(confirm);
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('withdrawal-otp-error')),
          findsOneWidget);
      expect(calls, 0);

      await tester.enterText(field, '123456');
      await tester.tap(confirm);
      await tester.pump();
      await tester.tap(confirm);
      await tester.pump();
      expect(calls, 1);

      completer.complete(
        const WithdrawalSubmitOutcome.failed(AppFailure(FailureKind.timeout)),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('withdrawal-otp-error')),
          findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller!.text, isEmpty);
    });

    testWidgets('todo el flujo de retiros no crea clientes HTTP',
        (tester) async {
      final network = _CountingHttpOverrides();
      await HttpOverrides.runWithHttpOverrides<Future<void>>(() async {
        await _pumpScreen(tester, const DisconnectedWithdrawalGateway());
        await _tapKey(tester, 'withdrawals-configure-bank');
        await _confirmBankTotp(tester);
        await _tapKey(tester, 'bank-info-close');
        await _tapKey(tester, 'withdrawals-open-new');
        await tester.enterText(
          find.byKey(const ValueKey<String>('withdrawal-amount-field')),
          '100',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey<String>('withdrawal-submit')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Volver'));
        await tester.pumpAndSettle();
        await _tapKey(tester, 'withdrawals-open-history');
      }, network);
      expect(network.created, 0);
    });
  });
}

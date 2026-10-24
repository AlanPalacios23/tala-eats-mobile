import 'device_location.dart';
import 'local/local_backend.dart';
import 'local/local_media_repository.dart';
import 'local/local_repositories.dart';
import 'local/qa_scenario.dart';
import 'location_store.dart';
import 'remote/remote_api.dart';
import 'remote/remote_withdrawal_gateway.dart';
import 'remote/remote_repositories.dart';
import 'repositories.dart';
import 'withdrawal_gateway.dart';

class AppServices {
  const AppServices({
    required this.auth,
    required this.onboarding,
    required this.restaurant,
    required this.menu,
    required this.orders,
    required this.finance,
    required this.media,
    this.withdrawals = const DisconnectedWithdrawalGateway(),
    this.locationStore = const LocalRestaurantLocationStore(),
    this.deviceLocation = const GeolocatorLocationProvider(),
    this.financeApi,
    this.isRemote = false,
  });

  factory AppServices.production({
    String baseUrl = kApiBase,
    MediaRepository? media,
  }) {
    final api = RemoteApi(baseUrl: baseUrl);
    final auth = RemoteAuthRepository(api);
    return AppServices(
      auth: auth,
      onboarding: RemoteOnboardingRepository(api, auth),
      restaurant: RemoteRestaurantRepository(api),
      menu: RemoteMenuRepository(api),
      orders: RemoteOrdersRepository(api),
      finance: RemoteFinanceRepository(api),
      financeApi: api,
      media: media ?? LocalMediaRepository(),
      // Always use authenticated, server-authorized withdrawals; no Stripe
      // secrets or independent balance calculation in the mobile application.
      withdrawals: RemoteWithdrawalGateway(api),
      locationStore: RemoteRestaurantLocationStore(
        api,
        const LocationServerFields(
          path: '/owner/restaurant', address: 'address',
          latitude: 'lat', longitude: 'lng',
        ),
        const LocalRestaurantLocationStore(),
      ),
      isRemote: true,
    );
  }

  factory AppServices.local({
    LocalLatency? latency,
    QaScenario? scenario,
    MediaRepository? media,
  }) {
    final activeScenario = scenario ?? configuredQaScenario;
    final backend = LocalBackend(
      latency: latency ??
          (activeScenario == QaScenario.slow
              ? const LocalLatency.slow()
              : const LocalLatency.standard()),
      faults: QaFaults(activeScenario),
    );
    return AppServices(
      auth: LocalAuthRepository(backend),
      onboarding: LocalOnboardingRepository(backend),
      restaurant: LocalRestaurantRepository(backend),
      menu: LocalMenuRepository(backend),
      orders: LocalOrdersRepository(backend),
      finance: LocalFinanceRepository(backend),
      media: media ?? LocalMediaRepository(),
    );
  }

  final AuthRepository auth;
  final OnboardingRepository onboarding;
  final RestaurantRepository restaurant;
  final MenuRepository menu;
  final OrdersRepository orders;
  final FinanceRepository finance;
  /// Authenticated API used only for server-ledger balances and Connect status.
  final RemoteApi? financeApi;
  final MediaRepository media;

  /// Retiros: gateway autenticado en producción, desconectado en QA local.
  final WithdrawalGateway withdrawals;

  /// Ubicación: backend canónico en producción, almacenamiento local en QA.
  final RestaurantLocationStore locationStore;

  /// GPS del teléfono para «Usar mi ubicación».
  final DeviceLocationProvider deviceLocation;
  final bool isRemote;
}

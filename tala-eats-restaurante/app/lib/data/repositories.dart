import '../models/entities.dart';

abstract class AuthRepository {
  Future<UserSession?> restoreSession();

  Future<UserSession> signIn({
    required String email,
    required String password,
    String otp = '',
  });

  /// Solicita el mismo correo de recuperación para los tres roles.\n  Future<void> requestPasswordRecovery(String email) async =>\n      throw UnimplementedError('Recuperación no configurada');\n\n  Future<void> signOut();

  Future<TwoFactorSetup> beginTwoFactorSetup();

  Future<UserSession> confirmTwoFactor(String code);
}

abstract class OnboardingRepository {
  Future<bool> isSetupComplete();

  /// En producción crea/recupera la cuenta, sube documentos/fotos de alta y
  /// envía la solicitud de restaurante. El restaurante queda pendiente de
  /// aprobación ADMIN antes de poder operar.
  Future<UserSession> createRestaurant(OnboardingDraft draft);

  Future<OnboardingApplication?> latestApplication();

  /// Sincroniza el primer producto guardado como borrador local una vez que la
  /// cuenta ya fue aprobada como restaurante. Es idempotente.
  Future<void> syncPendingProductIfNeeded();
}

abstract class RestaurantRepository {
  Future<RestaurantInfo> fetchRestaurant();

  Future<RestaurantInfo> updateProfile(RestaurantProfileInput input);

  Future<bool> setRestaurantOpen(bool open);

  Future<List<EmployeeInfo>> fetchTeam();

  Future<EmployeeInfo> inviteEmployee({
    required String email,
    required String role,
  });
}

abstract class MenuRepository {
  Future<List<MenuProduct>> fetchMenu();

  Future<MenuProduct> saveProduct(ProductDraft draft);

  Future<MenuProduct> setProductAvailability(int productId, bool available);

  Future<void> deleteProduct(int productId);
}

abstract class OrdersRepository {
  Future<List<RestaurantOrder>> fetchOrders();

  Future<RestaurantOrder> acceptOrder(int orderId);

  Future<RestaurantOrder> startPreparation(int orderId);

  Future<RestaurantOrder> markReady(int orderId);

  Future<RestaurantOrder> rejectOrder(int orderId);
}

abstract class FinanceRepository {
  Future<FinanceSummary> fetchSummary(FinancePeriod period);
}

enum MediaSource { camera, gallery }

enum MediaPurpose { restaurantCover, product }

abstract class MediaRepository {
  Future<String?> pickImage({
    required MediaSource source,
    required MediaPurpose purpose,
  });
}

/// Supported Tala Eats markets. Codes must match backend restaurant.market_code.
/// Tala is the pilot. Other markets are options, not claims of active coverage.
class TalaMarket {
  const TalaMarket(this.code, this.label);

  final String code;
  final String label;

  static const List<TalaMarket> supported = <TalaMarket>[
    TalaMarket('TALA-JAL', 'Tala'),
    TalaMarket('CUISILLOS-JAL', 'Cuisillos'),
    TalaMarket('AMECA-JAL', 'Ameca'),
    TalaMarket('AHUALULCO-JAL', 'Ahualulco de Mercado'),
    TalaMarket('TEQUILA-JAL', 'Tequila'),
    TalaMarket('AMATITAN-JAL', 'Amatitán'),
  ];

  static const String pilot = 'TALA-JAL';

  static bool valid(String code) =>
      supported.any((TalaMarket market) => market.code == code);

  static String labelFor(String code) {
    for (final TalaMarket market in supported) {
      if (market.code == code) return market.label;
    }
    return 'Tala';
  }

  /// A pre-filter legacy API may ignore market_code. Fail CLOSED instead of
  /// showing another city's merchants. Never silently replace with Tala.
  static void verifyPage(
      String requestedCode, List<dynamic> rows, Set<int> seenIds) {
    if (!valid(requestedCode)) {
      throw StateError('Mercado no reconocido');
    }
    for (final dynamic raw in rows) {
      if (raw is! Map) throw const FormatException('Catálogo inválido');
      final String code = (raw['market_code'] ?? '').toString().trim().toUpperCase();
      if (code != requestedCode) {
        throw const FormatException('El servidor no separó los comercios por localidad');
      }
      final dynamic number = raw['id'];
      final int? id = int.tryParse(number?.toString() ?? '');
      if (id == null || id <= 0 || !seenIds.add(id)) {
        throw const FormatException('Catálogo duplicado o sin identificador');
      }
    }
  }
}

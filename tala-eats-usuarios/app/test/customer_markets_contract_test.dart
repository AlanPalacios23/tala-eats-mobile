import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/local_markets.dart';
import 'package:talaeats_users/production_api.dart';

class _MarketApi extends TalaApi {
  _MarketApi(this.dataset, {this.ignoreFilter = false});
  final List<Map<String, dynamic>> dataset;
  final bool ignoreFilter;
  final List<String> calls = <String>[];

  @override
  Future<dynamic> get(String path) async {
    calls.add(path);
    final uri = Uri.parse('https://test.invalid' + path);
    expect(uri.path, '/restaurants');
    final code = uri.queryParameters['market_code'];
    final int offset = int.parse(uri.queryParameters['offset']!);
    final int limit = int.parse(uri.queryParameters['limit']!);
    final rows = ignoreFilter ? dataset
        : dataset.where((r) => r['market_code'] == code).toList();
    return rows.skip(offset).take(limit).toList();
  }
}

Map<String, dynamic> merchant(int id, String code) =>
    <String, dynamic>{'id': id, 'name': 'Comercio $id', 'market_code': code};

void main() {
  test('Solo seis códigos regionales configurados y Tala piloto', () {
    expect(TalaMarket.pilot, 'TALA-JAL');
    expect(TalaMarket.supported.length, 6);
    expect(TalaMarket.valid('AMECA-JAL'), true);
    expect(TalaMarket.valid('tala-jal'), false);
    expect(TalaMarket.valid('OUTSIDE-JAL'), false);
  });

  test('Paginación conserva mercado en TODAS las páginas', () async {
    final input = <Map<String, dynamic>>[
      ...List<Map<String, dynamic>>.generate(
          201, (i) => merchant(i + 1, 'TALA-JAL')),
      merchant(400, 'AMECA-JAL'),
    ];
    final api = _MarketApi(input);
    final rows = await api.restaurantsForMarket('TALA-JAL');
    expect(rows.length, 201);
    expect(api.calls, <String>[
      '/restaurants?market_code=TALA-JAL&limit=100&offset=0',
      '/restaurants?market_code=TALA-JAL&limit=100&offset=100',
      '/restaurants?market_code=TALA-JAL&limit=100&offset=200',
    ]);
    expect(rows.every((r) => (r as Map)['market_code'] == 'TALA-JAL'), true);
  });

  test('Backend sin filtro ignora market_code: FALLA CERRADO', () async {
    final api = _MarketApi(<Map<String, dynamic>>[
      merchant(1, 'TALA-JAL'), merchant(2, 'AMECA-JAL'),
    ], ignoreFilter: true);
    await expectLater(api.restaurantsForMarket('AMECA-JAL'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'HTTP', 503)));
  });

  test('Zonas sin comercios quedan vacías, sin fallback a Tala', () async {
    final api = _MarketApi(<Map<String, dynamic>>[merchant(1, 'TALA-JAL')]);
    final rows = await api.restaurantsForMarket('CUISILLOS-JAL');
    expect(rows, isEmpty);
    expect(api.calls.single, contains('market_code=CUISILLOS-JAL'));
  });

  test('ID duplicado y datos sin market_code no contaminan resultados', () async {
    final broken = _MarketApi(<Map<String, dynamic>>[
      merchant(3, 'TALA-JAL'), merchant(3, 'TALA-JAL'),
    ]);
    await expectLater(broken.restaurantsForMarket('TALA-JAL'), throwsA(isA<ApiException>()));
    final missing = _MarketApi(<Map<String, dynamic>>[
      <String, dynamic>{'id': 1, 'name': 'Sin localidad'},
    ]);
    await expectLater(missing.restaurantsForMarket('TALA-JAL'), throwsA(isA<ApiException>()));
  });
}

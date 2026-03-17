import 'package:flutter_test/flutter_test.dart';
import 'package:laravel_rest_api_flutter/data/core/http_client/rest_api_http_client.dart';
import 'package:laravel_rest_api_flutter/data/core/models/laravel_rest_api/body/laravel_rest_api_search_body.dart';
import 'package:laravel_rest_api_flutter/data/core/rest_api_factories/laravel_rest_api/laravel_rest_api_search_factory.dart';
import 'package:mockito/mockito.dart';
import 'package:dio/dio.dart';

import '../mock/item_model.dart';
import '../mock/mock_http_client.dart';
import '../mock/mock_http_client.mocks.dart';

/// Repository standard pour les tests de base
class ItemRepository with SearchFactory<ItemModel> {
  final MockDio mockDio;
  ItemRepository(this.mockDio);

  @override
  String get baseRoute => '/items';

  @override
  RestApiClient get httpClient => MockApiHttpClient(dio: mockDio);

  @override
  ItemModel fromJson(Map<String, dynamic> item) => ItemModel.fromJson(item);

  @override
  void onCatchError(
    RestApiResponse? response,
    Object exception,
    StackTrace stacktrace,
  ) {}
}

/// Repository avec configuration par défaut pour tester le merge des paramètres
class ItemRepositoryWithDefaultBody with SearchFactory<ItemModel> {
  final MockDio mockDio;
  ItemRepositoryWithDefaultBody(this.mockDio);

  @override
  String get baseRoute => '/items';

  @override
  RestApiClient get httpClient => MockApiHttpClient(dio: mockDio);

  @override
  LaravelRestApiSearchBody? get defaultSearchBody => LaravelRestApiSearchBody(
    filters: [Filter(field: "field", operator: "operator", value: "value")],
  );

  @override
  ItemModel fromJson(Map<String, dynamic> item) => ItemModel.fromJson(item);

  @override
  void onCatchError(
    RestApiResponse? response,
    Object exception,
    StackTrace stacktrace,
  ) {}
}

void main() {
  late MockDio mockDio;
  late ItemRepository repository;
  late ItemRepositoryWithDefaultBody repositoryWithDefault;

  setUp(() {
    mockDio = MockDio();
    repository = ItemRepository(mockDio);
    repositoryWithDefault = ItemRepositoryWithDefaultBody(mockDio);
  });

  group('Search Factory - Response Handling', () {
    // TEST 1
    test('[200] Successful API call with valid JSON', () async {
      when(
        mockDio.post(
          '/items/search',
          data: anyNamed('data'),
          options: anyNamed('options'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/items/search'),
          statusCode: 200,
          data: {
            'data': [
              {'id': 1, 'name': 'Lou West'},
              {'id': 2, 'name': 'Bridget Wilderman'},
            ],
          },
        ),
      );

      final result = await repository.search();

      expect(result.statusCode, 200);
      expect(result.data, isNotNull);
      expect(result.data!.length, 2);
      expect(result.data!.first.name, 'Lou West');
    });

    // TEST 2
    test('[200] Successful API call with bad JSON (Model mismatch)', () async {
      when(
        mockDio.post(
          '/items/search',
          data: anyNamed('data'),
          options: anyNamed('options'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/items/search'),
          statusCode: 200,
          data: {
            'data': [
              {'idd': 1, 'name': 'Lou West'}, // Mauvaise clé 'idd'
            ],
          },
        ),
      );

      final result = await repository.search();

      expect(result.statusCode, 200);
      expect(result.data, isNull);
    });

    // TEST 3
    test('[404] With common laravel error message', () async {
      when(
        mockDio.post(
          '/items/search',
          data: anyNamed('data'),
          options: anyNamed('options'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/items/search'),
          statusCode: 404,
          data: {
            "message": "Not Found",
            "exception":
                "Symfony\\Component\\HttpKernel\\Exception\\NotFoundHttpException",
          },
        ),
      );

      final result = await repository.search();

      expect(result.statusCode, 404);
      expect(result.message, "Not Found");
    });

    // TEST 4
    test('[500] With custom object error message returned', () async {
      when(
        mockDio.post(
          '/items/search',
          data: anyNamed('data'),
          options: anyNamed('options'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/items/search'),
          statusCode: 500,
          data: {"error": "error"},
        ),
      );

      final result = await repository.search();

      expect(result.statusCode, 500);
      expect(result.body?["error"], "error"); // Ajout du safe call ?
    });

    // TEST 5
    test('[500] With custom list error message returned', () async {
      when(
        mockDio.post(
          '/items/search',
          data: anyNamed('data'),
          options: anyNamed('options'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/items/search'),
          statusCode: 500,
          data: [
            {"error": "error"},
          ],
        ),
      );

      final result = await repository.search();

      expect(result.statusCode, 500);
      expect(result.body?[0]["error"], "error"); // Ajout du safe call ?
    });
  });

  group('Search Factory - Request Construction', () {
    // TEST 6
    test('Check if all attributes filter can be send in body', () async {
      when(
        mockDio.post(
          '/items/search',
          data: anyNamed('data'),
          options: anyNamed('options'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/items/search'),
          statusCode: 200,
          data: {'data': []},
        ),
      );

      await repositoryWithDefault.search(
        text: TextSearch(value: "my text search"),
        filters: [Filter(field: "field", type: "type", value: null)],
        aggregates: [
          Aggregate(relation: "relation", type: "type", field: "field"),
        ],
        includes: [
          Include(
            relation: "relation",
            includes: [Include(relation: "relationIncludes")],
            selects: [Select(field: "relationField")],
            filters: [Filter(field: "relationFilter", value: null)],
          ),
        ],
        instructions: [
          Instruction(
            name: "name",
            fields: [InstructionField(name: "name", value: "value")],
          ),
        ],
        limit: 1,
        page: 1,
        scopes: [Scope(name: "name")],
        selects: [Select(field: "field")],
        sorts: [Sort(field: "field", direction: "direction")],
      );

      final capturedArgs = verify(
        mockDio.post(
          '/items/search',
          data: captureAnyNamed('data'),
          options: anyNamed('options'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).captured.first;

      final search = capturedArgs['search'];
      expect(search.containsKey('text'), isTrue);
      expect(search.containsKey('filters'), isTrue);
      expect(search.containsKey('aggregates'), isTrue);
      expect(search.containsKey('includes'), isTrue);
      expect(search.containsKey('instructions'), isTrue);
      expect(search['limit'], 1);

      // Profondeur des includes
      expect(
        search["includes"][0]["includes"][0]["relation"],
        "relationIncludes",
      );
      expect(search["includes"][0]["selects"][0]["field"], "relationField");
    });

    // TEST 7
    test('Check if defaultSearchBody is correctly send to api', () async {
      when(
        mockDio.post(
          '/items/search',
          data: anyNamed('data'),
          options: anyNamed('options'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/items/search'),
          statusCode: 200,
          data: {'data': []},
        ),
      );

      await repositoryWithDefault.search(
        aggregates: [
          Aggregate(relation: "relation", type: "type", field: "field"),
        ],
      );

      final capturedArgs = verify(
        mockDio.post(
          '/items/search',
          data: captureAnyNamed('data'),
          options: anyNamed('options'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).captured.first;

      expect(
        capturedArgs['search'].containsKey('filters'),
        isTrue,
      ); // Vient du defaultSearchBody
      expect(
        capturedArgs['search'].containsKey('aggregates'),
        isTrue,
      ); // Vient de l'appel
    });
  });
}

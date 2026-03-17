import 'package:flutter_test/flutter_test.dart';
import 'package:laravel_rest_api_flutter/data/core/http_client/rest_api_http_client.dart';
import 'package:laravel_rest_api_flutter/data/core/models/laravel_rest_api/body/laravel_rest_api_mutate_body.dart';
import 'package:laravel_rest_api_flutter/data/core/rest_api_factories/laravel_rest_api/laravel_rest_api_mutate_factory.dart';
import 'package:mockito/mockito.dart';
import 'package:dio/dio.dart';

import 'mock/item_model.dart';
import 'mock/mock_http_client.dart';
import 'mock/mock_http_client.mocks.dart';

/// Repository de test utilisant le mixin MutateFactory
class ItemMutateRepository with MutateFactory {
  final MockDio mockDio;

  ItemMutateRepository(this.mockDio);

  @override
  String get baseRoute => '/items';

  @override
  RestApiClient get httpClient => MockApiHttpClient(dio: mockDio);
}

void main() {
  late MockDio mockDio;
  late ItemMutateRepository repository;

  setUp(() {
    mockDio = MockDio();
    repository = ItemMutateRepository(mockDio);
  });

  group('Mutate Factory - API Calls', () {
    // TEST 1 : Succès 200
    test('[200] Successful API call with valid JSON', () async {
      final item = ItemModel(id: 1, name: "name");

      when(
        mockDio.post(
          '/items/mutate',
          data: anyNamed('data'),
          options: anyNamed('options'), // <-- LA CORRECTION EST ICI
          queryParameters: anyNamed('queryParameters'), // Par sécurité
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/items/mutate'),
          statusCode: 200,
          data: {
            "created": [1],
            "updated": [],
          },
        ),
      );

      final result = await repository.mutate(
        body: LaravelRestApiMutateBody(
          mutate: [
            Mutation(
              operation: MutationOperation.create,
              attributes: item.toJson(),
            ),
          ],
        ),
      );

      expect(result.statusCode, 200);
      expect(result.data, isNotNull);
      expect(result.data?.created.contains(1), true);
      expect(result.data?.updated.isEmpty, true);

      verify(
        mockDio.post(
          '/items/mutate',
          data: anyNamed('data'),
          options: anyNamed('options'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).called(1);
    });

    // TEST 2 : Erreur 500 standard Laravel
    test('[500] With common laravel error message', () async {
      when(
        mockDio.post(
          '/items/mutate',
          data: anyNamed('data'),
          options: anyNamed('options'), // <-- LA CORRECTION EST ICI
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/items/mutate'),
          statusCode: 500,
          data: {
            "message": "Server error",
            "exception":
                "Symfony\\Component\\HttpKernel\\Exception\\NotFoundHttpException",
          },
        ),
      );

      final result = await repository.mutate(
        body: LaravelRestApiMutateBody(
          mutate: [
            Mutation(
              operation: MutationOperation.create,
              attributes: {"name": "test"},
            ),
          ],
        ),
      );

      expect(result.statusCode, 500);
      expect(result.message, "Server error");
    });

    // TEST 3 : Erreur 500 avec objet custom
    test('[500] With custom object error message returned', () async {
      when(
        mockDio.post(
          '/items/mutate',
          data: anyNamed('data'),
          options: anyNamed('options'), // <-- LA CORRECTION EST ICI
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/items/mutate'),
          statusCode: 500,
          data: {"error": "custom_error_code"},
        ),
      );

      final result = await repository.mutate(
        body: LaravelRestApiMutateBody(
          mutate: [
            Mutation(
              operation: MutationOperation.create,
              attributes: {"name": "test"},
            ),
          ],
        ),
      );

      expect(result.statusCode, 500);
      expect(result.body["error"], "custom_error_code");
    });
  });

  group('Mutate Factory - Serialization (.toJson)', () {
    // TEST 4 : Sérialisation simple
    test('Mutation update existing item without relation', () {
      final ItemModel item = ItemModel(id: 1, name: "updated name");

      final json = LaravelRestApiMutateBody(
        mutate: [
          Mutation(
            key: item.id,
            withoutDetaching: true,
            operation: MutationOperation.update,
            attributes: item.toJson(),
          ),
        ],
      ).toJson();

      final mutateMap = json['mutate'].first;
      expect(mutateMap['key'], item.id);
      expect(mutateMap['without_detaching'], true);
      expect(mutateMap['operation'], MutationOperation.update.name);
      expect(mutateMap['attributes']['name'], item.name);
    });

    // TEST 5 : Sérialisation complexe (Relations & Pivots)
    test('Mutation complex: two relations and a pivot', () {
      final item = ItemModel(id: 1, name: "parent");
      final child = ItemModel(id: 2, name: "child");
      final pivot = ItemModel(id: 3, name: "pivot_data");
      final secondChild = ItemModel(id: 4, name: "second_child");

      final json = LaravelRestApiMutateBody(
        mutate: [
          Mutation(
            operation: MutationOperation.create,
            attributes: item.toJson(),
            relations: [
              MutationRelation(
                table: 'tags',
                key: child.id,
                withoutDetaching: false,
                pivot: pivot.toJson(),
                attributes: child.toJson(),
                relationType: RelationType.singleRelation,
                operation: MutationRelationOperation.toggle,
              ),
              MutationRelation(
                table: 'categories',
                key: secondChild.id,
                attributes: secondChild.toJson(),
                relationType: RelationType.multipleRelation,
                operation: MutationRelationOperation.sync,
              ),
            ],
          ),
        ],
      ).toJson();

      final rootMutation = json['mutate'].first;

      // Vérification Relation Single (Object)
      final tagRelation = rootMutation['relations']['tags'];
      expect(tagRelation['operation'], MutationRelationOperation.toggle.name);
      expect(tagRelation['key'], child.id);
      expect(tagRelation['pivot']['id'], pivot.id);

      // Vérification Relation Multiple (List)
      final catRelation = rootMutation['relations']['categories'].first;
      expect(catRelation['operation'], MutationRelationOperation.sync.name);
      expect(catRelation['key'], secondChild.id);
    });
  });
}

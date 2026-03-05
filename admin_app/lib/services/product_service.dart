import '../core/api_client.dart';
import '../models/coverage.dart';
import '../models/quote_field.dart';

class ProductService {
  final ApiClient _client;

  ProductService(this._client);

  Future<List<Coverage>> getCoverages(String productId) async {
    final response = await _client.get('products/$productId/coverages');
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .map((json) => Coverage.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<QuoteField>> getQuoteFields(String productId) async {
    final response = await _client.get('products/$productId/quote-fields');
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .map((json) => QuoteField.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}

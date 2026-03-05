import '../core/api_client.dart';
import '../models/quote.dart';

class QuoteService {
  final ApiClient _client;

  QuoteService(this._client);

  Future<Quote> createQuote(Map<String, dynamic> payload) async {
    final response = await _client.post('quotes', data: payload);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Quote.fromJson(response.data as Map<String, dynamic>);
    } else {
      throw Exception('Failed to generate quote: ${response.statusMessage}');
    }
  }
}

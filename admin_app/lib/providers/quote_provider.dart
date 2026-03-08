import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/quote.dart';
import '../services/quote_service.dart';

final quoteServiceProvider = Provider<QuoteService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return QuoteService(apiClient);
});

class QuoteNotifier extends StateNotifier<AsyncValue<List<Quote>>> {
  final ApiClient _apiClient;

  QuoteNotifier(this._apiClient) : super(const AsyncValue.loading());

  Future<void> fetchQuotes() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get('quotes');
      final List<dynamic> data = response.data;
      final quotes = data.map((json) => Quote.fromJson(json)).toList();
      state = AsyncValue.data(quotes);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<Quote> createQuote(Map<String, dynamic> quoteData) async {
    try {
      final response = await _apiClient.post('quotes', data: quoteData);
      final quote = Quote.fromJson(response.data);
      // Append to existing list without triggering a full reload (avoids loading flash)
      final currentList = state.valueOrNull ?? [];
      state = AsyncValue.data([...currentList, quote]);
      return quote;
    } catch (e) {
      rethrow;
    }
  }

  Future<Quote> fetchQuoteDetails(String id) async {
    try {
      final response = await _apiClient.get('quotes/$id');
      return Quote.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> submitQuote(String id) async {
    try {
      await _apiClient.post('quotes/$id/submit');
      final currentList = state.valueOrNull ?? [];
      // Update status in list
      state = AsyncValue.data(
        currentList.map((q) {
          if (q.id == id) {
            return q.copyWith(status: 'SUBMITTED');
          }
          return q;
        }).toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Directly set a quote's decision status (APPROVED/REJECTED) for manual UW decisions.
  Future<void> submitQuoteDecision(
    String id,
    String decision,
    String decidedBy,
  ) async {
    try {
      await _apiClient.post(
        'quotes/$id/decision',
        data: {'status': decision, 'decidedBy': decidedBy},
      );
      final currentList = state.valueOrNull ?? [];
      state = AsyncValue.data(
        currentList.map((q) {
          if (q.id == id) {
            return q.copyWith(status: decision);
          }
          return q;
        }).toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelQuote(
    String id, [
    String userId = 'admin-user',
    String reason = 'User requested',
  ]) async {
    try {
      await _apiClient.post(
        'quotes/$id/cancel',
        data: {'cancelledBy': userId, 'reason': reason},
      );
      await fetchQuotes();
    } catch (e) {
      rethrow;
    }
  }
}

final quoteProvider =
    StateNotifierProvider.autoDispose<QuoteNotifier, AsyncValue<List<Quote>>>((
      ref,
    ) {
      final notifier = QuoteNotifier(ref.watch(apiClientProvider));
      notifier.fetchQuotes();
      return notifier;
    });

final quoteDetailsProvider = FutureProvider.family<Quote, String>((ref, id) {
  return ref.watch(quoteProvider.notifier).fetchQuoteDetails(id);
});

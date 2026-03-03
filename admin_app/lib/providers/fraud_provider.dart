import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/claim.dart';

class FraudNotifier extends StateNotifier<AsyncValue<List<Claim>>> {
  final ApiClient _apiClient;

  FraudNotifier(this._apiClient) : super(const AsyncValue.loading());

  Future<void> fetchPendingReviews() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get('/fraud');
      final List<dynamic> data = response.data;
      final claims = data.map((json) => Claim.fromJson(json)).toList();
      state = AsyncValue.data(claims);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> submitReview(
    String claimId,
    Map<String, dynamic> reviewData,
  ) async {
    try {
      await _apiClient.post('/fraud/$claimId/review', data: reviewData);
      await fetchPendingReviews();
    } catch (e) {
      rethrow;
    }
  }
}

final fraudProvider =
    StateNotifierProvider<FraudNotifier, AsyncValue<List<Claim>>>((ref) {
      final notifier = FraudNotifier(ref.watch(apiClientProvider));
      notifier.fetchPendingReviews();
      return notifier;
    });

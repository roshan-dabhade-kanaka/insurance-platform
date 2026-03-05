import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/payout.dart';

class FinanceNotifier extends StateNotifier<AsyncValue<List<PayoutRequest>>> {
  final ApiClient _apiClient;

  FinanceNotifier(this._apiClient) : super(const AsyncValue.loading());

  Future<void> fetchPendingPayouts() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get('payouts');
      final List<dynamic> data = response.data;
      final requests = data
          .map((json) => PayoutRequest.fromJson(json))
          .toList();
      state = AsyncValue.data(requests);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> approvePayout(
    String claimId,
    Map<String, dynamic> approvalData,
  ) async {
    try {
      await _apiClient.post('payouts/$claimId/approve', data: approvalData);
      await fetchPendingPayouts();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> processPayment(
    String payoutRequestId,
    String claimId,
    Map<String, dynamic> paymentData,
  ) async {
    try {
      await _apiClient.post(
        'payouts/$payoutRequestId/pay',
        data: {...paymentData, 'claimId': claimId},
      );
      await fetchPendingPayouts();
    } catch (e) {
      rethrow;
    }
  }
}

final financeProvider =
    StateNotifierProvider<FinanceNotifier, AsyncValue<List<PayoutRequest>>>((
      ref,
    ) {
      final notifier = FinanceNotifier(ref.watch(apiClientProvider));
      notifier.fetchPendingPayouts();
      return notifier;
    });

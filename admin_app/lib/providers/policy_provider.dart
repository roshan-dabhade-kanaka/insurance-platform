import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/policy.dart';

class PolicyNotifier extends StateNotifier<AsyncValue<List<Policy>>> {
  final ApiClient _apiClient;

  PolicyNotifier(this._apiClient) : super(const AsyncValue.loading());

  Future<void> fetchPolicies() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get('/policies');
      final List<dynamic> data = response.data;
      final policies = data.map((json) => Policy.fromJson(json)).toList();
      state = AsyncValue.data(policies);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<Policy> issuePolicy(
    String quoteId, [
    Map<String, dynamic> issueData = const {},
  ]) async {
    try {
      final response = await _apiClient.post(
        '/policies/$quoteId/issue',
        data: issueData,
      );
      final policy = Policy.fromJson(response.data);
      await fetchPolicies();
      return policy;
    } catch (e) {
      rethrow;
    }
  }
}

final policyProvider =
    StateNotifierProvider<PolicyNotifier, AsyncValue<List<Policy>>>((ref) {
      final notifier = PolicyNotifier(ref.watch(apiClientProvider));
      notifier.fetchPolicies();
      return notifier;
    });

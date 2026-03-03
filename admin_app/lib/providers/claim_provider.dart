import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/claim.dart';

class ClaimNotifier extends StateNotifier<AsyncValue<List<Claim>>> {
  final ApiClient _apiClient;

  ClaimNotifier(this._apiClient) : super(const AsyncValue.loading());

  Future<void> fetchClaims() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get('/claims');
      final List<dynamic> data = response.data;
      final claims = data.map((json) => Claim.fromJson(json)).toList();
      state = AsyncValue.data(claims);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<Claim> submitClaim(Map<String, dynamic> claimData) async {
    try {
      final response = await _apiClient.post('/claims', data: claimData);
      final claim = Claim.fromJson(response.data);
      await fetchClaims();
      return claim;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> investigateClaim(
    String id,
    Map<String, dynamic> investigationData,
  ) async {
    try {
      await _apiClient.post('/claims/$id/investigate', data: investigationData);
      await fetchClaims();
    } catch (e) {
      rethrow;
    }
  }

  /// Submit claim assessment (Claims Officer / Admin). Refreshes list after.
  Future<Map<String, dynamic>> submitAssessment(
    String claimId,
    Map<String, dynamic> assessmentData,
  ) async {
    try {
      final response = await _apiClient.post(
        '/claims/$claimId/assess',
        data: assessmentData,
      );
      await fetchClaims();
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }
}

final claimProvider =
    StateNotifierProvider<ClaimNotifier, AsyncValue<List<Claim>>>((ref) {
      final notifier = ClaimNotifier(ref.watch(apiClientProvider));
      notifier.fetchClaims();
      return notifier;
    });

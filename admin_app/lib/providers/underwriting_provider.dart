import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/underwriting.dart';

class UnderwritingNotifier
    extends StateNotifier<AsyncValue<List<UnderwritingCase>>> {
  final ApiClient _apiClient;

  UnderwritingNotifier(this._apiClient) : super(const AsyncValue.loading());

  Future<void> fetchCases() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get('underwriting');
      final List<dynamic> data = response.data;
      final cases = data
          .map((json) => UnderwritingCase.fromJson(json))
          .toList();
      state = AsyncValue.data(cases);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> approveCase(String id, Map<String, dynamic> decisionData) async {
    try {
      await _apiClient.post('underwriting/$id/approve', data: decisionData);
      await fetchCases();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectCase(String id, Map<String, dynamic> decisionData) async {
    try {
      await _apiClient.post('underwriting/$id/reject', data: decisionData);
      await fetchCases();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> escalateCase(
    String id,
    String escalatedFrom,
    String reason,
  ) async {
    try {
      await _apiClient.post(
        'underwriting/$id/escalate',
        data: {'escalatedFrom': escalatedFrom, 'reason': reason},
      );
      await fetchCases();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> acquireLock(
    String id,
    String underwriterId,
  ) async {
    try {
      final response = await _apiClient.post(
        'underwriting/$id/lock',
        data: {'underwriterId': underwriterId},
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }
}

final underwritingProvider =
    StateNotifierProvider<
      UnderwritingNotifier,
      AsyncValue<List<UnderwritingCase>>
    >((ref) {
      final notifier = UnderwritingNotifier(ref.watch(apiClientProvider));
      notifier.fetchCases();
      return notifier;
    });

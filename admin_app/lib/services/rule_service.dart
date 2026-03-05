import '../core/api_client.dart';

class RuleService {
  final ApiClient _client;

  RuleService(this._client);

  Future<Map<String, dynamic>> createRule({
    required String ruleName,
    required String ruleType, // 'Eligibility' or 'Pricing'
    required String versionId,
    required Map<String, dynamic> logic,
  }) async {
    // Map internal UI types to backend endpoints and fields
    final bool isEligibility = ruleType.toLowerCase() == 'eligibility';
    final String endpoint = isEligibility
        ? 'rules/eligibility'
        : 'rules/pricing';

    final Map<String, dynamic> payload = {
      'name': ruleName,
      'productVersionId': versionId,
      'isActive': true,
    };

    if (isEligibility) {
      payload['ruleLogic'] = logic;
      payload['priority'] = 0;
    } else {
      payload['ruleExpression'] = logic;
    }

    final response = await _client.post(endpoint, data: payload);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.data is Map<String, dynamic>
          ? response.data
          : {'id': response.data.toString()};
    } else {
      throw Exception('Failed to create rule: ${response.statusMessage}');
    }
  }

  Future<void> updateRule({
    required String ruleId,
    required String ruleName,
    required String ruleType,
    required String versionId,
    required Map<String, dynamic> logic,
  }) async {
    final bool isEligibility = ruleType.toLowerCase() == 'eligibility';
    final String endpoint = isEligibility
        ? 'rules/eligibility/$ruleId'
        : 'rules/pricing/$ruleId';

    final Map<String, dynamic> payload = {
      'name': ruleName,
      'productVersionId': versionId,
      'isActive': true,
    };

    if (isEligibility) {
      payload['ruleLogic'] = logic;
    } else {
      payload['ruleExpression'] = logic;
    }

    final response = await _client.put(endpoint, data: payload);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to update rule: ${response.statusMessage}');
    }
  }
}

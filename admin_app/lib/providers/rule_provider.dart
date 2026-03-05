import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../services/rule_service.dart';

final ruleServiceProvider = Provider<RuleService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RuleService(apiClient);
});

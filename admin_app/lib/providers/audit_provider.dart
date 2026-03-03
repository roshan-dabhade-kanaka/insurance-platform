import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/audit.dart';

/// Filters for audit log list (Entity, User, Date range).
class AuditFilters {
  const AuditFilters({
    this.entityType,
    this.changedBy,
    this.fromDate,
    this.toDate,
  });

  final String? entityType;
  final String? changedBy;
  final DateTime? fromDate;
  final DateTime? toDate;

  AuditFilters copyWith({
    String? entityType,
    String? changedBy,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearEntityType = false,
    bool clearChangedBy = false,
    bool clearFromDate = false,
    bool clearToDate = false,
  }) {
    return AuditFilters(
      entityType: clearEntityType ? null : (entityType ?? this.entityType),
      changedBy: clearChangedBy ? null : (changedBy ?? this.changedBy),
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
    );
  }
}

/// Paginated audit state: list + total + page index + filters.
class AuditListState {
  const AuditListState({
    required this.logs,
    required this.totalElements,
    required this.page,
    required this.pageSize,
    required this.filters,
  });

  final List<AuditLog> logs;
  final int totalElements;
  final int page;
  final int pageSize;
  final AuditFilters filters;

  int get totalPages => pageSize > 0
      ? (totalElements / pageSize).ceil().clamp(1, totalElements)
      : 1;
}

/// Notifier that fetches paginated audit logs from backend with filters.
/// API: GET /audit/logs?page=&size=&entityType=&changedBy=&from=&to=
class AuditNotifier extends StateNotifier<AsyncValue<AuditListState>> {
  AuditNotifier(this._apiClient)
    : super(
        AsyncValue.data(
          AuditListState(
            logs: [],
            totalElements: 0,
            page: 0,
            pageSize: 20,
            filters: const AuditFilters(),
          ),
        ),
      );

  final ApiClient _apiClient;
  static const int defaultPageSize = 20;

  AsyncValue<AuditListState> get currentState => state;

  Future<void> fetchPage({
    int? page,
    int? pageSize,
    String? entityType,
    String? changedBy,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final prev = state.valueOrNull;
    final filters = prev?.filters ?? const AuditFilters();
    final nextFilters = AuditFilters(
      entityType: entityType ?? filters.entityType,
      changedBy: changedBy ?? filters.changedBy,
      fromDate: fromDate ?? filters.fromDate,
      toDate: toDate ?? filters.toDate,
    );
    final pageIndex = page ?? prev?.page ?? 0;
    final size = pageSize ?? prev?.pageSize ?? defaultPageSize;

    state = AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{'page': pageIndex, 'size': size};
      if (nextFilters.entityType != null &&
          nextFilters.entityType!.isNotEmpty) {
        queryParams['entityType'] = nextFilters.entityType;
      }
      if (nextFilters.changedBy != null &&
          nextFilters.changedBy!.trim().isNotEmpty) {
        queryParams['changedBy'] = nextFilters.changedBy!.trim();
      }
      if (nextFilters.fromDate != null) {
        queryParams['from'] = _formatDate(nextFilters.fromDate!);
      }
      if (nextFilters.toDate != null) {
        queryParams['to'] = _formatDate(nextFilters.toDate!);
      }

      final response = await _apiClient.get(
        '/audit/logs',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data.containsKey('content')) {
        final logs = (data['content'] as List)
            .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
            .toList();
        final total = data['total'] as int? ?? logs.length;

        state = AsyncValue.data(
          AuditListState(
            logs: logs,
            totalElements: total,
            page: pageIndex,
            pageSize: size,
            filters: nextFilters,
          ),
        );
        return;
      }
      // Legacy or other format
      if (data is Map<String, dynamic> && data.containsKey('totalElements')) {
        final pageResult = AuditLogPage.fromJson(data);
        state = AsyncValue.data(
          AuditListState(
            logs: pageResult.content,
            totalElements: pageResult.totalElements,
            page: pageResult.number,
            pageSize: pageResult.size,
            filters: nextFilters,
          ),
        );
        return;
      }
      // Backend may return a plain list (no pagination wrapper).
      if (data is List<dynamic>) {
        final logs = data
            .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
            .toList();
        state = AsyncValue.data(
          AuditListState(
            logs: logs,
            totalElements: logs.length,
            page: 0,
            pageSize: logs.length,
            filters: nextFilters,
          ),
        );
        return;
      }
      state = AsyncValue.data(
        AuditListState(
          logs: [],
          totalElements: 0,
          page: pageIndex,
          pageSize: size,
          filters: nextFilters,
        ),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Apply filters and load first page.
  Future<void> applyFilters({
    String? entityType,
    String? changedBy,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return fetchPage(
      page: 0,
      entityType: entityType,
      changedBy: changedBy,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  /// Go to a specific page (keeps current filters).
  Future<void> goToPage(int page) async {
    final prev = state.valueOrNull;
    if (prev == null) return;
    return fetchPage(
      page: page,
      pageSize: prev.pageSize,
      entityType: prev.filters.entityType,
      changedBy: prev.filters.changedBy,
      fromDate: prev.filters.fromDate,
      toDate: prev.filters.toDate,
    );
  }

  /// Legacy: fetch by entity ID and type (single-entity history).
  Future<void> fetchEntityHistory(String entityId, String entityType) async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get(
        '/audit/$entityId',
        queryParameters: {'entityType': entityType},
      );
      final List<dynamic> data = response.data is List
          ? response.data as List<dynamic>
          : [];
      final logs = data
          .map((json) => AuditLog.fromJson(json as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(
        AuditListState(
          logs: logs,
          totalElements: logs.length,
          page: 0,
          pageSize: logs.length,
          filters: const AuditFilters(),
        ),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  static String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

final auditProvider =
    StateNotifierProvider<AuditNotifier, AsyncValue<AuditListState>>((ref) {
      return AuditNotifier(ref.watch(apiClientProvider));
    });

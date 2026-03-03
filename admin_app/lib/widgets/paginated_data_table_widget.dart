import 'package:flutter/material.dart';

/// Generic paginated data table. Columns and rows are passed as DataColumn/DataRow;
/// no hardcoded layout logic.
class PaginatedDataTableWidget extends StatelessWidget {
  const PaginatedDataTableWidget({
    super.key,
    required this.columns,
    required this.rows,
    this.rowsPerPage = 10,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.title,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final int rowsPerPage;
  final int? sortColumnIndex;
  final bool sortAscending;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final end = rows.length.clamp(0, rowsPerPage);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: columns,
              rows: rows.take(rowsPerPage).toList(),
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
            ),
          ),
          if (rows.length > rowsPerPage)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '1–$end of ${rows.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

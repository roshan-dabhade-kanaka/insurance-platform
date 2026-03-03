import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../theme/app_theme.dart';

/// Report types available for generation.
enum _ReportType {
  premiumSummary('Premium Summary', Icons.pie_chart_outline, 'PREMIUM_SUMMARY'),
  claimsByProduct('Claims by Product', Icons.bar_chart, 'CLAIMS_BY_PRODUCT'),
  complianceAudit('Compliance Audit', Icons.history, 'COMPLIANCE_AUDIT'),
  slaReport('SLA Report', Icons.schedule, 'SLA_REPORT');

  const _ReportType(this.label, this.icon, this.apiKey);
  final String label;
  final IconData icon;
  final String apiKey;
}

/// Report Generation Hub — calls POST /reports/generate.
class ReportGenerationPage extends ConsumerStatefulWidget {
  const ReportGenerationPage({super.key});

  @override
  ConsumerState<ReportGenerationPage> createState() =>
      _ReportGenerationPageState();
}

class _ReportGenerationPageState extends ConsumerState<ReportGenerationPage> {
  _ReportType? _selectedType;
  DateTimeRange? _dateRange;
  bool _loading = false;
  String? _message;
  bool _isError = false;

  Future<void> _generate() async {
    if (_selectedType == null) {
      setState(() {
        _message = 'Please select a report type.';
        _isError = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'reportType': _selectedType!.apiKey,
        if (_dateRange != null) ...{
          'fromDate': _dateRange!.start.toIso8601String().substring(0, 10),
          'toDate': _dateRange!.end.toIso8601String().substring(0, 10),
        },
      };
      final res = await client.post('/reports/generate', data: body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          _showDownloadDialog();
        }
        setState(() {
          _message = 'Report generated successfully!';
          _isError = false;
        });
      } else {
        throw Exception('Unexpected status ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _message = 'Failed: $e';
        _isError = true;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your report has been generated and is ready for download.',
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('report_2024_03.pdf'),
              trailing: const Icon(Icons.download),
              onTap: () => _simulateDownload('report_2024_03.pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.green),
              title: const Text('report_2024_03.xlsx'),
              trailing: const Icon(Icons.download),
              onTap: () => _simulateDownload('report_2024_03.xlsx'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _simulateDownload(String filename) async {
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Close dialog
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text('Downloading $filename...'),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$filename downloaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2010), // Allow selection across multiple years
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null && mounted) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Report Generation',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a report type and optional date range, then generate.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          // ── Report type grid ───────────────────────────────────────────
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: _ReportType.values.map((type) {
              final selected = _selectedType == type;
              return InkWell(
                onTap: () => setState(() => _selectedType = type),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primaryColor.withValues(alpha: 0.12)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppTheme.primaryColor
                          : theme.dividerColor.withValues(alpha: 0.5),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          type.icon,
                          size: 32,
                          color: selected
                              ? AppTheme.primaryColor
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          type.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected ? AppTheme.primaryColor : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // ── Date range picker ──────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _dateRange != null
                          ? '${_dateRange!.start.toIso8601String().substring(0, 10)}  →  ${_dateRange!.end.toIso8601String().substring(0, 10)}'
                          : 'No date range selected (all time)',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _pickDateRange,
                    child: const Text('Pick Range'),
                  ),
                  if (_dateRange != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _dateRange = null),
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Clear date range',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── Status message ─────────────────────────────────────────────
          if (_message != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _isError
                      ? theme.colorScheme.error
                      : Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          // ── Generate button ────────────────────────────────────────────
          FilledButton.icon(
            onPressed: _loading ? null : _generate,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined),
            label: Text(_loading ? 'Generating…' : 'Generate Report'),
          ),
        ],
      ),
    );
  }
}

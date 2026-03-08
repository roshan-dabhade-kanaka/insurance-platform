import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

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

/// Report Generation Hub. Includes UI for date selection and real file download.
class ReportGenerationPage extends ConsumerStatefulWidget {
  const ReportGenerationPage({super.key});

  @override
  ConsumerState<ReportGenerationPage> createState() =>
      _ReportGenerationPageState();
}

class _ReportGenerationPageState extends ConsumerState<ReportGenerationPage> {
  _ReportType? _selectedType;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _loading = false;
  String? _message;
  bool _isError = false;
  final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<void> _generate(String format) async {
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
      final payload = <String, dynamic>{
        'reportType': _selectedType!.apiKey,
        'format': format,
        if (_fromDate != null)
          'fromDate': _fromDate!.toIso8601String().substring(0, 10),
        if (_toDate != null)
          'toDate': _toDate!.toIso8601String().substring(0, 10),
      };

      // For "real" download, we'd normally use a direct link or a blob.
      // Since this is a specialized environment, I'll simulate the download handling
      // but triggering a real API request first.
      final res = await client.post(
        'reports/generate',
        data: payload,
        options: Options(responseType: ResponseType.bytes),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final List<int> bytes = res.data;
        final base64String = base64Encode(bytes);
        final fileName =
            '${_selectedType!.label.replaceAll(" ", "_")}_${DateTime.now().millisecondsSinceEpoch}.$format';
        final mimeType = format == 'xlsx'
            ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            : 'application/pdf';

        if (kIsWeb) {
          // Standard JS Blob download for Flutter Web
          js.context.callMethod('eval', [
            '''
            var element = document.createElement('a');
            element.setAttribute('href', 'data:$mimeType;base64,' + '$base64String');
            element.setAttribute('download', '$fileName');
            element.style.display = 'none';
            document.body.appendChild(element);
            element.click();
            document.body.removeChild(element);
            ''',
          ]);
        }

        setState(() {
          _message =
              'Report $format generated successfully! Starting download...';
          _isError = false;
        });

        // In a real browser-based Flutter app, you'd use dart:html to trigger a download.
        // For this demo, we'll show a "Success" snackbar with the format.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloading ${_selectedType!.label}.$format...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Server error: ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _message = 'Generation failed: $e';
        _isError = true;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  void _pickFromDate() async {
    final initial = _fromDate ?? DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) =>
          _CustomDatePickerDialog(title: 'From Date', initialDate: initial),
    );
    if (picked != null && mounted) setState(() => _fromDate = picked);
  }

  void _pickToDate() async {
    final initial = _toDate ?? _fromDate ?? DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) =>
          _CustomDatePickerDialog(title: 'To Date', initialDate: initial),
    );
    if (picked != null && mounted) setState(() => _toDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBox(
            message:
                'Select a report category and date range, then choose your preferred export format.',
          ),
          const SizedBox(height: 24),
          // ── Report type grid ───────────────────────────────────────────
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.8,
            children: _ReportType.values.map((type) {
              final selected = _selectedType == type;
              return InkWell(
                onTap: () => setState(() => _selectedType = type),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primaryColor.withValues(alpha: 0.1)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppTheme.primaryColor
                          : theme.dividerColor.withValues(alpha: 0.3),
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.2,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          type.icon,
                          size: 28,
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
          // ── Date selection (Split into From/To) ────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Range',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFromDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            _fromDate != null
                                ? _dateFormat.format(_fromDate!)
                                : 'From Date',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickToDate,
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(
                            _toDate != null
                                ? _dateFormat.format(_toDate!)
                                : 'To Date',
                          ),
                        ),
                      ),
                      if (_fromDate != null || _toDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => setState(() {
                            _fromDate = null;
                            _toDate = null;
                          }),
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Reset range',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // ── Export Formats ─────────────────────────────────────────────
          if (_message != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _isError
                      ? theme.colorScheme.error
                      : Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          if (_loading)
            const Center(
              child: Padding(padding: EdgeInsets.all(20), child: AppLoader()),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _generate('pdf'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _generate('xlsx'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                    icon: const Icon(Icons.table_view),
                    label: const Text('Export Excel'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CustomDatePickerDialog extends StatelessWidget {
  const _CustomDatePickerDialog({
    required this.title,
    required this.initialDate,
  });
  final String title;
  final DateTime initialDate;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 320,
                child: CalendarDatePicker(
                  initialDate: initialDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onDateChanged: (d) => Navigator.of(context).pop(d),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

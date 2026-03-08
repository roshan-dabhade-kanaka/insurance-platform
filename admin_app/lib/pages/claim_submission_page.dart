import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../widgets/widgets.dart';
import '../providers/claim_provider.dart';
import '../providers/policy_provider.dart';
import '../models/policy.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_model.dart';

class ClaimSubmissionPage extends ConsumerStatefulWidget {
  const ClaimSubmissionPage({super.key});

  @override
  ConsumerState<ClaimSubmissionPage> createState() =>
      _ClaimSubmissionPageState();
}

class _ClaimSubmissionPageState extends ConsumerState<ClaimSubmissionPage> {
  Policy? _selectedPolicy;
  PolicyCoverage? _selectedCoverage;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final claimState = ref.watch(claimProvider);
    final policyState = ref.watch(policyProvider);
    final authState = ref.watch(authNotifierProvider).state;

    String? userId;
    if (authState is AuthAuthenticated) {
      userId = authState.user.id;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBox(
            message:
                'Select an IN FORCE policy to submit a new claim. Choose the coverage that applies to the incident.',
          ),
          const SizedBox(height: 24),
          if (claimState.isLoading || policyState.isLoading)
            const AppLoader()
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      policyState.when(
                        data: (policies) {
                          final inForcePolicies = policies
                              .where((p) => p.status == 'IN_FORCE')
                              .toList();
                          return DropdownButtonFormField<Policy>(
                            decoration: const InputDecoration(
                              labelText: 'Select Policy',
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedPolicy,
                            items: inForcePolicies.map((p) {
                              return DropdownMenuItem(
                                value: p,
                                child: Text(
                                  '${p.policyNumber} (Premium: ₹${p.totalPremium})',
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedPolicy = val;
                                _selectedCoverage = null;
                              });
                            },
                            validator: (v) =>
                                v == null ? 'Must select a policy' : null,
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (err, stack) =>
                            Text('Error loading policies: $err'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<PolicyCoverage>(
                        decoration: const InputDecoration(
                          labelText: 'Select Coverage Option',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedCoverage,
                        items:
                            _selectedPolicy?.coverages.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(c.name),
                              );
                            }).toList() ??
                            [],
                        onChanged: (val) {
                          setState(() {
                            _selectedCoverage = val;
                          });
                        },
                        validator: (v) =>
                            v == null ? 'Must select a coverage' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Claimed Amount (₹)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Loss Date (YYYY-MM-DD)',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            _dateController.text = date
                                .toIso8601String()
                                .split('T')
                                .first;
                          }
                        },
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Incident Description',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;

                                setState(() {
                                  _isSubmitting = true;
                                });

                                try {
                                  await ref
                                      .read(claimProvider.notifier)
                                      .submitClaim({
                                        'policyId': _selectedPolicy!.id,
                                        'policyCoverageId':
                                            _selectedCoverage!.id,
                                        'claimedAmount': double.parse(
                                          _amountController.text,
                                        ),
                                        'lossDate': _dateController.text,
                                        'lossDescription': _descController.text,
                                        'claimantData': {},
                                        'submittedBy': userId ?? 'unknown',
                                      });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Claim submitted successfully!',
                                        ),
                                      ),
                                    );
                                    // Reset form
                                    setState(() {
                                      _selectedPolicy = null;
                                      _selectedCoverage = null;
                                      _amountController.clear();
                                      _dateController.clear();
                                      _descController.clear();
                                    });
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    String errorText = e.toString();
                                    if (e is DioException) {
                                      errorText =
                                          e.response?.data['message']
                                              ?.toString() ??
                                          e.response?.data?.toString() ??
                                          e.message ??
                                          errorText;
                                    } else {
                                      errorText = errorText.replaceFirst(
                                        RegExp(r'^Exception:\s*'),
                                        '',
                                      );
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed: $errorText'),
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isSubmitting = false;
                                    });
                                  }
                                }
                              },
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(
                          _isSubmitting ? 'Submitting...' : 'Submit Claim',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/widgets.dart';
import '../core/api_client.dart';

/// Document template manager (from document_template_manager).
class DocumentTemplateManagerPage extends ConsumerStatefulWidget {
  const DocumentTemplateManagerPage({super.key});

  @override
  ConsumerState<DocumentTemplateManagerPage> createState() =>
      _DocumentTemplateManagerPageState();
}

class _DocumentTemplateManagerPageState
    extends ConsumerState<DocumentTemplateManagerPage> {
  final List<DocumentTemplateItem> _templates = [
    const DocumentTemplateItem(
      id: '1',
      name: 'Policy schedule',
      description: 'PDF',
      type: 'Policy',
    ),
    const DocumentTemplateItem(
      id: '2',
      name: 'Claim form',
      description: 'PDF',
      type: 'Claim',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Document templates',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              FilledButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add),
                label: const Text('New Template'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          DocumentTemplateMapper(
            templates: _templates,
            onEdit: (item) => _showEditDialog(item),
            // Removed duplicate onAdd
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    _showAddEditDialog(null);
  }

  void _showEditDialog(DocumentTemplateItem item) {
    _showAddEditDialog(item);
  }

  void _showAddEditDialog(DocumentTemplateItem? item) {
    final nameController = TextEditingController(text: item?.name);
    final descController = TextEditingController(text: item?.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Add Template' : 'Edit Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Template Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text;
              final desc = descController.text;
              if (name.isEmpty) return;

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                final client = ref.read(apiClientProvider);
                final payload = {
                  'name': name,
                  'description': desc,
                  'type': item?.type ?? 'Custom',
                };

                if (item == null) {
                  await client.post('/documents/templates', data: payload);
                } else {
                  await client.put(
                    '/documents/templates/${item.id}',
                    data: payload,
                  );
                }

                if (mounted) {
                  Navigator.pop(context); // Close loading
                  Navigator.pop(context); // Close add/edit dialog
                  setState(() {
                    if (item == null) {
                      _templates.add(
                        DocumentTemplateItem(
                          id: DateTime.now().toString(),
                          name: name,
                          description: desc,
                          type: 'Custom',
                        ),
                      );
                    } else {
                      final idx = _templates.indexWhere((t) => t.id == item.id);
                      if (idx != -1) {
                        _templates[idx] = DocumentTemplateItem(
                          id: item.id,
                          name: name,
                          description: desc,
                          type: item.type,
                        );
                      }
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Template saved successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error saving template: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

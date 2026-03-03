import 'package:flutter/material.dart';

/// One template mapping for [DocumentTemplateMapper].
class DocumentTemplateItem {
  const DocumentTemplateItem({
    required this.id,
    required this.name,
    this.description,
    this.type = 'Policy',
  });

  final String id;
  final String name;
  final String? description;
  final String type;
}

/// List/cards of document templates with type and edit. Used in document template manager.
class DocumentTemplateMapper extends StatelessWidget {
  const DocumentTemplateMapper({
    super.key,
    required this.templates,
    this.onEdit,
    this.onAdd,
  });

  final List<DocumentTemplateItem> templates;
  final void Function(DocumentTemplateItem item)? onEdit;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...templates.map(
          (t) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.description_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(t.name),
              subtitle: t.description != null ? Text(t.description!) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(label: Text(t.type, style: theme.textTheme.labelSmall)),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onEdit != null ? () => onEdit!(t) : null,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onAdd != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add template'),
            ),
          ),
      ],
    );
  }
}

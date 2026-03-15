import 'package:flutter/material.dart';

class FeaturesSection extends StatelessWidget {
  final TextEditingController promptsController;
  final Set<String> selectedFeatureIds;
  final String featureSummaryText;
  final bool loadingFeatures;
  final VoidCallback onOpenFeatureSelector;
  final VoidCallback onClearSelection;

  const FeaturesSection({
    super.key,
    required this.promptsController,
    required this.selectedFeatureIds,
    required this.featureSummaryText,
    required this.loadingFeatures,
    required this.onOpenFeatureSelector,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loadingFeatures)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.list_alt),
            label: const Text('Seleccionar características'),
            onPressed: onOpenFeatureSelector,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              featureSummaryText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (selectedFeatureIds.isNotEmpty)
            TextButton(
              onPressed: onClearSelection,
              child: const Text('Limpiar selección'),
            ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: promptsController,
          decoration: const InputDecoration(
            labelText: 'Prompts / Descripciones adicionales para IA',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/global_data_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  static const _prefsKey = 'route_planner_selected_ids';

  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey) ?? [];
    if (!mounted) return;
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(saved);
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _selectedIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    final globalData = context.read<GlobalDataService>();
    final route = globalData.residentialComplexes
        .where((c) => _selectedIds.contains(c['id']?.toString()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Rutero')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ruta 1',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.primaryColor),
                  iconSize: 32,
                  tooltip: 'Agregar residenciales',
                  onPressed: () => _openPicker(globalData),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: route.isEmpty
                ? const Center(
                    child: Text(
                      'No hay residenciales en la ruta',
                      style: TextStyle(color: AppColors.textColor2),
                    ),
                  )
                : ListView.separated(
                    itemCount: route.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _buildTile(globalData, route[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(GlobalDataService globalData, Map<String, dynamic> c) {
    final address = c['address']?.toString() ?? '';
    final cityName = lookupNameById(globalData.cities, c['id_city']?.toString());
    final zoneName = lookupNameById(globalData.zones, c['id_zone']?.toString());
    final stratum = c['stratum']?.toString();

    final meta = [
      if (cityName != null) cityName,
      if (zoneName != null) zoneName,
      if (stratum != null && stratum.isNotEmpty) 'Estrato $stratum',
    ].join(' · ');

    return ListTile(
      isThreeLine: address.isNotEmpty && meta.isNotEmpty,
      leading: const Icon(Icons.apartment, color: AppColors.primaryColor),
      title: Text(c['name']?.toString() ?? ''),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (address.isNotEmpty) Text(address),
          if (meta.isNotEmpty)
            Text(meta, style: const TextStyle(color: AppColors.textColor2)),
        ],
      ),
      trailing: OutlinedButton(
        onPressed: () {}, // ponytail: sin función aún
        child: const Text('Visitado'),
      ),
    );
  }

  void _openPicker(GlobalDataService globalData) {
    final complexes = globalData.residentialComplexes
        .where((c) => c['active'] != false)
        .toList();
    final temp = Set<String>.from(_selectedIds);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.backgroundLevel1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) => Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Agregar residenciales',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textColor,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: complexes.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay residenciales',
                            style: TextStyle(color: AppColors.textColor2),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: complexes.length,
                          itemBuilder: (context, index) {
                            final c = complexes[index];
                            final id = c['id']?.toString();
                            return CheckboxListTile(
                              value: temp.contains(id),
                              activeColor: AppColors.primaryColor,
                              title: Text(c['name']?.toString() ?? ''),
                              subtitle: (c['address']?.toString().isNotEmpty ?? false)
                                  ? Text(c['address'].toString())
                                  : null,
                              onChanged: id == null
                                  ? null
                                  : (checked) => setSheetState(() {
                                        if (checked == true) {
                                          temp.add(id);
                                        } else {
                                          temp.remove(id);
                                        }
                                      }),
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedIds
                              ..clear()
                              ..addAll(temp);
                          });
                          _persist();
                          Navigator.pop(context);
                        },
                        child: const Text('Listo'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/client.dart';
import '../providers/client_provider.dart';
import 'add_client_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientProvider>().ensureLoaded();
    });
  }

  Future<void> _createNew() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddClientScreen()),
    );
    if (created == true && mounted) {
      // La lista ya se refrescó dentro de createClient
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cliente creado'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_client_fab',
        backgroundColor: AppColors.primaryColor,
        onPressed: _createNew,
        tooltip: 'Nuevo cliente',
        child: const Icon(Icons.add, color: AppColors.pureWhite),
      ),
      body: Consumer<ClientProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      'Referencia de asesor: ${provider.advisorPropertyId ?? ''}',
                      style: const TextStyle(color: AppColors.textColor2),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody(provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(ClientProvider provider) {
    if (provider.isLoading && provider.clients.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }
    if (provider.error != null && provider.clients.isEmpty) {
      return _buildErrorWidget(provider);
    }
    return RefreshIndicator(
            onRefresh: provider.refresh,
            color: AppColors.primaryColor,
            child: provider.clients.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'No hay clientes',
                          style: TextStyle(color: AppColors.textColor2),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: provider.clients.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _buildClientTile(provider.clients[index]),
                  ),
    );
  }

  Color _statusColor(int? status) {
    switch (status) {
      case 1: // Nuevo
        return AppColors.info;
      case 2: // En Proceso
        return AppColors.warning;
      case 3: // Convertido
        return AppColors.success;
      case 4: // Recuperado
        return Colors.teal;
      case 5: // Perdido
        return AppColors.error;
      default:
        return AppColors.textColor2;
    }
  }

  Widget _statusChip(Client client) {
    final color = _statusColor(client.idClientStatus);
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        client.statusLabel,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildClientTile(Client client) {
    final statusColor = _statusColor(client.idClientStatus);
    return ListTile(
      isThreeLine: true,
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Icon(Icons.person, color: statusColor),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(client.fullName, overflow: TextOverflow.ellipsis),
          ),
          _statusChip(client),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            client.query ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textColor2),
          ),
          // Placeholder: se reemplaza con la última entrada real de la bitácora
          const Text(
            'Última entrada: (bitácora próximamente)',
            style: TextStyle(
              color: AppColors.textColor2,
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.info_outline, color: AppColors.textColor2),
        tooltip: 'Ver información',
        onPressed: () => _showDetails(client),
      ),
    );
  }

  void _showDetails(Client client) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundLevel1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              client.fullName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textColor,
                              ),
                            ),
                          ),
                          _statusChip(client),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cliente #${client.idClientWasi}',
                        style: const TextStyle(
                            color: AppColors.textColor2, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      if (client.cellPhone != null)
                        _detailRow(Icons.phone_android, 'Celular', client.cellPhone!),
                      if (client.phone != null)
                        _detailRow(Icons.phone, 'Teléfono', client.phone!),
                      if (client.email != null)
                        _detailRow(Icons.email, 'Correo', client.email!),
                      if (client.cityLabel != null)
                        _detailRow(Icons.location_city, 'Ciudad', client.cityLabel!),
                      if (client.address != null)
                        _detailRow(Icons.location_on, 'Dirección', client.address!),
                      if (client.identification != null)
                        _detailRow(Icons.badge, 'Identificación', client.identification!),
                      if (client.query != null)
                        _detailRow(Icons.search, 'Consulta', client.query!),
                      if (client.createdAt != null)
                        _detailRow(Icons.calendar_today, 'Creado', client.createdAt!),
                      const SizedBox(height: 12),
                      const Divider(),
                      Row(
                        children: [
                          const Text(
                            'Bitácora',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textColor,
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            // Placeholder: conectar al crear-nota del backend
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Próximamente')),
                              );
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nueva entrada'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Las entradas de la bitácora aparecerán aquí.',
                        style: TextStyle(
                          color: AppColors.textColor2,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textColor2),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textColor2, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textColor, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(ClientProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.textColor2),
            const SizedBox(height: 16),
            const Text(
              'No se pudieron cargar los clientes',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textColor),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: provider.refresh,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

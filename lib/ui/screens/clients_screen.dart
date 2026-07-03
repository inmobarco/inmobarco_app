import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../providers/client_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: Consumer<ClientProvider>(
        builder: (context, provider, _) {
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
                    itemBuilder: (context, index) {
                      final client = provider.clients[index];
                      return ListTile(
                        leading: const Icon(Icons.person, color: AppColors.primaryColor),
                        title: Text(client.fullName),
                        trailing: IconButton(
                          icon: const Icon(Icons.info_outline, color: AppColors.textColor2),
                          tooltip: 'Ver información',
                          onPressed: () {}, // Ficha del cliente: próximamente
                        ),
                      );
                    },
                  ),
          );
        },
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

import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../models/nota_lenha.dart';
import '../services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<NotaLenha>> _recentNotasFuture;

  @override
  void initState() {
    super.initState();
    _recentNotasFuture = _loadRecentNotas();
  }

  Future<List<NotaLenha>> _loadRecentNotas() async {
    final all = await SupabaseService.instance.listNotas();
    return all.take(5).toList();
  }

  void _refresh() {
    setState(() {
      _recentNotasFuture = _loadRecentNotas();
    });
  }

  // ─── Navigation helpers ──────────────────────────────────────────────────────

  void _goToCamera() {
    Navigator.pushNamed(context, AppRoutes.camera).then((_) => _refresh());
  }

  void _goToDashboard() {
    Navigator.pushNamed(context, AppRoutes.dashboard);
  }

  void _goToFechamento() {
    Navigator.pushNamed(context, AppRoutes.fechamento);
  }

  void _goToBusca() {
    Navigator.pushNamed(context, AppRoutes.busca);
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Controle de Lenha TRBJ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32), // dark green
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCamera,
        backgroundColor: const Color(0xFF2E7D32),
        tooltip: 'Nova Nota',
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          children: [
            // ── Action grid ────────────────────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ActionCard(
                  label: 'Nova Nota',
                  icon: Icons.camera_alt,
                  color: const Color(0xFF2E7D32),
                  onTap: _goToCamera,
                ),
                _ActionCard(
                  label: 'Dashboard',
                  icon: Icons.bar_chart,
                  color: const Color(0xFF1565C0),
                  onTap: _goToDashboard,
                ),
                _ActionCard(
                  label: 'Fechamento',
                  icon: Icons.calendar_month,
                  color: const Color(0xFF6A1B9A),
                  onTap: _goToFechamento,
                ),
                _ActionCard(
                  label: 'Buscar Notas',
                  icon: Icons.search,
                  color: const Color(0xFFE65100),
                  onTap: _goToBusca,
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Recent notas section ────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.history, size: 20, color: Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                Text(
                  'Notas Recentes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B5E20),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<NotaLenha>>(
              future: _recentNotasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _ErrorWidget(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }

                final notas = snapshot.data ?? [];

                if (notas.isEmpty) {
                  return _EmptyNotasWidget(onAddTap: _goToCamera);
                }

                return Column(
                  children: notas
                      .map((nota) => _RecentNotaCard(nota: nota))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action Card ────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Recent Nota Card ────────────────────────────────────────────────────────

class _RecentNotaCard extends StatelessWidget {
  final NotaLenha nota;

  const _RecentNotaCard({required this.nota});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E7D32).withOpacity(0.12),
          child: const Icon(Icons.receipt_long, color: Color(0xFF2E7D32)),
        ),
        title: Text(
          'Nota: ${nota.numeroNota.isNotEmpty ? nota.numeroNota : "—"}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              nota.dataNotaFormatada.isNotEmpty
                  ? nota.dataNotaFormatada
                  : 'Data não informada',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            if (nota.motorista.isNotEmpty)
              Text(
                nota.motorista,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              nota.totalM3Formatado,
              style: theme.textTheme.titleSmall?.copyWith(
                color: const Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'm³',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper widgets ──────────────────────────────────────────────────────────

class _EmptyNotasWidget extends StatelessWidget {
  final VoidCallback onAddTap;

  const _EmptyNotasWidget({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Nenhuma nota cadastrada',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Adicionar primeira nota'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorWidget({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'Erro ao carregar notas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

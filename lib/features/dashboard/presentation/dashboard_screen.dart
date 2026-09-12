import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/work_provider.dart';
import '../../../models/academic_work.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final worksAsync = ref.watch(userWorksProvider);

    return userProfileAsync.when(
      data: (profile) {
        final name = profile?.name ?? 'Usuário';
        final cyberName = profile?.cyberName ?? 'Cyber';
        final credits = profile?.credits ?? 0;

        final isMobile = MediaQuery.of(context).size.width < 600;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Olá, $name',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(cyberName),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/create-work'),
                        icon: const Icon(Icons.add),
                        label: const Text('Novo trabalho'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Olá, $name',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(cyberName),
                        const SizedBox(height: 8),
                        const Text('O que você deseja fazer hoje?'),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/create-work'),
                      icon: const Icon(Icons.add),
                      label: const Text('Novo trabalho'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRecentWorksSection(context, worksAsync),
                    const SizedBox(height: 32),
                    _buildStatsSection(context, worksAsync, credits),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildRecentWorksSection(context, worksAsync),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 1,
                      child: _buildStatsSection(context, worksAsync, credits),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro ao carregar perfil: $err')),
    );
  }

  Widget _buildRecentWorksSection(BuildContext context, AsyncValue<List<AcademicWork>> worksAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trabalhos recentes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        worksAsync.when(
          data: (works) {
            if (works.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Nenhum trabalho recente.'),
              );
            }
            final recent = works.take(5).toList();
            return Column(
              children: recent.map((work) {
                Color statusColor = Colors.green;
                String statusText = 'Concluído';
                if (work.status == WorkStatus.processing) {
                  statusColor = Colors.orange;
                  statusText = 'Processando';
                } else if (work.status == WorkStatus.failed) {
                  statusColor = Colors.red;
                  statusText = 'Falha';
                }
                
                final dateStr = "${work.createdAt.day}/${work.createdAt.month}/${work.createdAt.year}";
                
                return _RecentWorkCard(
                  title: work.title,
                  date: dateStr,
                  status: statusText,
                  statusColor: statusColor,
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Text('Erro ao carregar trabalhos: $e'),
        ),
      ],
    );
  }

  Widget _buildStatsSection(BuildContext context, AsyncValue<List<AcademicWork>> worksAsync, int credits) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumo',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        worksAsync.when(
          data: (works) => _StatCard(
            label: 'Total de trabalhos',
            value: works.length.toString(),
            icon: Icons.assignment,
            color: Colors.blue,
          ),
          loading: () => const _StatCard(label: 'Total de trabalhos', value: '...', icon: Icons.assignment, color: Colors.blue),
          error: (e, s) => const _StatCard(label: 'Total de trabalhos', value: 'Erro', icon: Icons.assignment, color: Colors.red),
        ),
        const SizedBox(height: 16),
        _StatCard(
          label: 'Créditos disponíveis',
          value: credits.toString(),
          icon: Icons.stars,
          color: Colors.amber,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/credits'),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Adicionar créditos'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentWorkCard extends StatelessWidget {
  final String title;
  final String date;
  final String status;
  final Color statusColor;

  const _RecentWorkCard({
    required this.title,
    required this.date,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.description, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(date),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor),
          ),
          child: Text(
            status,
            style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

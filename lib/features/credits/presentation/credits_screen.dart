import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/credit_provider.dart';
import '../../../models/credit.dart';

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  Future<void> _buyCredits(CreditPackage package) async {
    const whatsappNumber = '245969217939';
    final message = Uri.encodeComponent(
      'Olá! Gostaria de comprar o ${package.name} (${package.credits} créditos) para o Kriol Academic AI.'
    );
    final url = Uri.parse('https://wa.me/$whatsappNumber?text=$message');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(userCreditsProvider);
    final historyAsync = ref.watch(creditHistoryProvider);
    final packagesAsync = ref.watch(creditPackagesProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Créditos',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            
            // Destaque de Créditos
            creditsAsync.when(
              data: (credits) => _buildCreditsCard(context, credits),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Text('Erro: $e'),
            ),
            
            const SizedBox(height: 24),
            
            // Botão Resgatar Código
            Center(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/credits/redeem'),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Tenho um código de recarga'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 48),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pacotes de Créditos
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comprar Créditos',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      packagesAsync.when(
                        data: (packages) => GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.5,
                          ),
                          itemCount: packages.length,
                          itemBuilder: (context, index) => _buildPackageCard(context, packages[index]),
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Text('Erro ao carregar pacotes: $e'),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 32),
                
                // Histórico de Transações
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Histórico Recente',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      historyAsync.when(
                        data: (history) {
                          if (history.isEmpty) {
                            return const Center(child: Text('Nenhuma transação registrada.'));
                          }
                          return Card(
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: history.length > 5 ? 5 : history.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) => _buildHistoryItem(history[index]),
                            ),
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Text('Erro: $e'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditsCard(BuildContext context, int credits) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        child: Column(
          children: [
            Text(
              'Créditos Disponíveis',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              credits.toString(),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cada crédito permite gerar um trabalho acadêmico completo.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard(BuildContext context, CreditPackage package) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              package.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              '${package.credits} Créditos',
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${package.price.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: () => _buyCredits(package),
                  child: const Text('Comprar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(CreditTransaction transaction) {
    final isUsage = transaction.type == CreditTransactionType.usage;
    return ListTile(
      leading: Icon(
        isUsage ? Icons.remove_circle_outline : Icons.add_circle_outline,
        color: isUsage ? Colors.red : Colors.green,
      ),
      title: Text(transaction.description),
      subtitle: Text(
        '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
      ),
      trailing: Text(
        '${isUsage ? "" : "+"}${transaction.amount}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isUsage ? Colors.red : Colors.green,
        ),
      ),
    );
  }
}

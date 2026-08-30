import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/support_ticket.dart';
import '../data/support_repository.dart';

final ticketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  final result = await ref.watch(supportRepositoryProvider).tickets();
  return result.valueOrNull ?? const [];
});

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  static const _faq = [
    (
      'How do I go online?',
      'Tap the toggle at the top of the Home screen. If it is disabled, the Home screen lists what needs sorting first.'
    ),
    (
      'When do I get paid?',
      'Your operator issues payouts on their usual schedule. You can see your balance and past payouts on the Earnings screen.'
    ),
    (
      'Why was my document rejected?',
      'Open the Documents tab — a rejected document shows the reviewer’s reason so you know what to change.'
    ),
    (
      'How do I dispute a charge?',
      'Open your Statement, find the charge, and tap Dispute. Your ticket will cite that exact entry.'
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ticketsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      // Fixed sections, not a feed: a lazy list would leave the tickets
      // section out of the tree entirely behind the FAQ.
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Common questions', style: AppText.heading),
            ),
            ..._faq.map((entry) => ExpansionTile(
                  title: Text(entry.$1, style: AppText.body),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(entry.$2, style: AppText.bodySecondary),
                    ),
                  ],
                )),
            const Divider(color: AppColors.border),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Your tickets', style: AppText.heading),
            ),
            async.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(32), child: AppLoading()),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Tickets are unavailable right now.'),
              ),
              data: (tickets) => tickets.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: AppEmptyState(
                        icon: Icons.support_agent,
                        title: 'No tickets yet',
                      ),
                    )
                  : Column(children: tickets.map(_ticketTile).toList()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ticketTile(SupportTicket t) {
    final (label, colour) = switch (t.status) {
      TicketStatus.resolved => ('Resolved', AppColors.positive),
      TicketStatus.rejected => ('Rejected', AppColors.negative),
      TicketStatus.pending => ('In progress', AppColors.warning),
      TicketStatus.open => ('Open', AppColors.info),
    };

    return ListTile(
      title: Text(t.subject, style: AppText.body),
      subtitle: Text(
        '${DateFormat('d MMM yyyy').format(t.createdAt.toLocal())}'
        '${t.resolutionNotes == null ? '' : '\n${t.resolutionNotes}'}',
        style: AppText.caption,
      ),
      isThreeLine: t.resolutionNotes != null,
      trailing: Text(label, style: AppText.caption.copyWith(color: colour)),
    );
  }
}

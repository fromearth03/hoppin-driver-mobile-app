import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../features/profile/ui/widgets/settings_card.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/support_ticket.dart';
import '../data/support_repository.dart';

final ticketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  final result = await ref.watch(supportRepositoryProvider).tickets();
  return result.valueOrNull ?? const [];
});

/// The issue reasons the server accepts. Fetched, not hardcoded: `type_code`
/// is validated against a table and an unknown code is rejected outright.
final complaintTypesProvider =
    FutureProvider<List<ComplaintType>>((ref) async {
  final result = await ref.watch(supportRepositoryProvider).complaintTypes();
  return result.valueOrNull ?? const [];
});

/// Help & Support: the FAQ card, the ticket form, the contact card, the
/// legal card, and the driver's own recent issues.
///
/// The design's "Preferred Resolution: Generate Payout" dropdown is not
/// built — `POST /me/support-tickets` has no such field, so the choice would
/// be collected and silently discarded. What the driver wants goes in the
/// description, which a human reads.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  static const _supportEmail = 'support@hoppin.com';

  static const _faq = [
    (
      'How do I go online?',
      'Tap the toggle at the top of the Home screen. If it is disabled, the '
          'Home screen lists what needs sorting first.'
    ),
    (
      'When do I get paid?',
      'Your operator issues payouts on their usual schedule. You can see your '
          'balance and past payouts on the Earnings screen.'
    ),
    (
      'What if any of my document expires?',
      'Open the Documents tab — an expiring or rejected document shows what '
          'needs replacing and by when.'
    ),
    (
      'How do I dispute a charge?',
      'Open your Statement, find the charge, and tap Dispute. Your ticket '
          'will cite that exact entry.'
    ),
  ];

  final _description = TextEditingController();
  String? _category;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit(List<ComplaintType> types) async {
    final code = _category;
    if (code == null || _description.text.trim().isEmpty) {
      setState(() => _error = 'Pick a category and describe the issue.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final subject = types.firstWhere((c) => c.code == code).label;
    final result = await ref.read(supportRepositoryProvider).create(
          subject: subject,
          category: code,
          typeCode: code,
          ticketBody: _description.text.trim(),
        );
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      ok: (_) {
        _description.clear();
        setState(() => _category = null);
        ref.invalidate(ticketsProvider);
      },
      err: (e) => setState(() => _error = errorCopy(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ticketsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: settingsAppBar(context, 'Help & Support'),
      // Fixed sections, not a feed: a lazy list would leave the tickets
      // section out of the tree entirely behind the FAQ.
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsCard(
              title: 'Frequently Asked Questions (FAQs)',
              children: _faq.map((e) => _FaqRow(question: e.$1, answer: e.$2)).toList(),
            ),
            _openTicketCard(ref.watch(complaintTypesProvider).valueOrNull ??
                const <ComplaintType>[]),
            const SettingsCard(
              title: 'Contact to Support',
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ContactTile(
                          icon: Icons.receipt_long_outlined,
                          title: 'Open Ticket',
                          subtitle:
                              'Representative will respond in 24 Hours',
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: _ContactTile(
                          icon: Icons.mail_outline,
                          title: 'Email',
                          subtitle: _supportEmail,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SettingsCard(
              title: 'Legal',
              children: [
                _FaqRow(
                  question: 'Terms of Services',
                  answer:
                      'Your agreement with your operator governs your work on '
                      'the platform. Contact support for a copy of the terms '
                      'that apply to you.',
                ),
                _FaqRow(
                  question: 'Privacy Policy',
                  answer:
                      'We hold your personal details to run the service and to '
                      'meet licensing rules. You can ask us to erase them from '
                      'Settings, under Delete account.',
                ),
              ],
            ),
            _recentIssues(async),
          ],
        ),
      ),
    );
  }

  Widget _openTicketCard(List<ComplaintType> types) => SettingsCard(
        title: 'Open a Ticket',
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Issue category',
                    style: AppText.body.copyWith(fontSize: 17)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: const Key('category'),
                  initialValue: _category,
                  hint: Text('Select an issue category',
                      style: AppText.body
                          .copyWith(color: AppColors.textDisabled)),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary),
                  decoration: _outlined(),
                  items: types
                      .map((c) => DropdownMenuItem(
                            value: c.code,
                            child: Text(c.label, style: AppText.body),
                          ))
                      .toList(),
                  onChanged: (_busy || types.isEmpty)
                      ? null
                      : (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 18),
                Text('Description', style: AppText.body.copyWith(fontSize: 17)),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('description'),
                  controller: _description,
                  enabled: !_busy,
                  maxLines: 5,
                  style: AppText.body,
                  decoration: _outlined().copyWith(
                    hintText: 'Please describe the issue...',
                    hintStyle:
                        AppText.body.copyWith(color: AppColors.textDisabled),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!,
                      style:
                          AppText.body.copyWith(color: AppColors.negative)),
                ],
                const SizedBox(height: 20),
                AppButton(
                  label: 'Submit',
                  busy: _busy,
                  onPressed: types.isEmpty ? null : () => _submit(types),
                ),
              ],
            ),
          ),
        ],
      );

  InputDecoration _outlined() => InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.primary),
        disabledBorder: _border(AppColors.border),
      );

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c),
      );

  Widget _recentIssues(AsyncValue<List<SupportTicket>> async) => SettingsCard(
        title: 'Recent Issues',
        children: [
          async.when(
            loading: () =>
                const Padding(padding: EdgeInsets.all(32), child: AppLoading()),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Tickets are unavailable right now.',
                  style: AppText.bodySecondary),
            ),
            data: (tickets) => tickets.isEmpty
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 28),
                    child: Text('No tickets yet',
                        style: AppText.bodySecondary,
                        textAlign: TextAlign.center),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Column(
                      children:
                          tickets.map((t) => _TicketCard(ticket: t)).toList(),
                    ),
                  ),
          ),
        ],
      );
}

/// A question that expands in place, drawn as the design has it: a bullet, the
/// question, and a chevron that flips.
class _FaqRow extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqRow({required this.question, required this.answer});

  @override
  State<_FaqRow> createState() => _FaqRowState();
}

class _FaqRowState extends State<_FaqRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8, right: 12),
                    child: CircleAvatar(
                        radius: 3, backgroundColor: AppColors.textPrimary),
                  ),
                  Expanded(
                    child: Text(widget.question,
                        style: AppText.body.copyWith(fontSize: 17)),
                  ),
                  const SizedBox(width: 8),
                  Icon(_open ? Icons.expand_less : Icons.expand_more,
                      size: 24, color: AppColors.textSecondary),
                ],
              ),
              if (_open) ...[
                const SizedBox(height: 10),
                Text(widget.answer, style: AppText.body),
              ],
            ],
          ),
        ),
      );
}

/// One of the two grey tiles under "Contact to Support".
class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: AppColors.textPrimary),
            const SizedBox(height: 22),
            Text(title, style: AppText.body.copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            Text(subtitle, style: AppText.caption),
          ],
        ),
      );
}

/// A recent issue, tinted by its outcome the way the design tints them:
/// green resolved, amber in progress, red rejected.
class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final (label, colour, icon) = switch (ticket.status) {
      TicketStatus.resolved => (
          'Resolved by the team',
          AppColors.positive,
          Icons.check_circle
        ),
      TicketStatus.rejected => (
          'This issue was rejected',
          AppColors.negative,
          Icons.cancel
        ),
      TicketStatus.pending => (
          'Your issue is under process',
          AppColors.accent,
          Icons.access_time_filled
        ),
      TicketStatus.open => ('Open', AppColors.info, Icons.schedule),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ticket.subject,
              style: AppText.title.copyWith(fontSize: 20)),
          const SizedBox(height: 6),
          Text(
            ticket.resolutionNotes ??
                (ticket.ticketBody.isNotEmpty
                    ? ticket.ticketBody
                    : DateFormat('d MMM yyyy')
                        .format(ticket.createdAt.toLocal())),
            style: AppText.bodySecondary,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(icon, size: 22, color: colour),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(
                      color: colour, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

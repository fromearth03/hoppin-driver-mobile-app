import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'driver_support_categories.dart';
import 'support_router.dart';

/// My tickets — `GET /me/support-tickets`. BOUND.
final driverTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>((
  ref,
) {
  return ref.watch(supportRepositoryProvider).myTickets();
});

final driverComplaintTypesProvider =
    FutureProvider.autoDispose<List<ComplaintTypeOption>>((ref) {
      return ref.watch(ridesRepositoryProvider).complaintTypes();
    });

final driverSupportRidesProvider = FutureProvider.autoDispose<List<Ride>>((ref) {
  return ref.watch(ridesRepositoryProvider).history(limit: 20);
});

/// The driver's support hub (PS-03) — over three BOUND endpoints.
///
/// `POST | GET /me/support-tickets`, `GET /me/support-tickets/:id` and
/// `POST /me/support-tickets/:id/messages` are all bound and fully typed in
/// `SupportRepository` — and until this screen existed the driver had **zero UI
/// for any of them**. A driver with a problem had no route to a human inside
/// this app at all. Everything on this screen is real.
///
/// One deliberate inclusion: the disclosure that a **person** reads every
/// ticket. It is a virtue, not an apology — and it is what makes the ticket
/// route credible, because the driver must believe a human will act.
class DriverSupportScreen extends ConsumerWidget {
  /// Creates the driver support hub.
  const DriverSupportScreen({super.key});

  /// The §3.2 human-tickets disclosure.
  static const String humanSupportDisclosure =
      'A person reads every ticket. We aim to reply within 24 hours.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final tickets = ref.watch(driverTicketsProvider);

    // Every inset comes off the spacing scale — no raw pixels in this feature.
    final gutter = EdgeInsets.symmetric(
      horizontal: hoppin.spacing.gutter,
      vertical: hoppin.spacing.gutter,
    );

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HopTopBar(
              title: 'Support',
              // NEVER a null back intent. Null HIDES the chevron entirely, and
              // `context.go` REPLACES rather than pushes — so there is nothing
              // to pop and the driver is stranded. Pop when there is a stack;
              // otherwise fall back to the dashboard, which is home.
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                hoppin.spacing.gutter,
                hoppin.spacing.sm,
                hoppin.spacing.gutter,
                hoppin.spacing.sm,
              ),
              child: const HopBanner.notice(message: humanSupportDisclosure),
            ),
            Expanded(
              child: RefreshIndicator(
                color: colors.accent,
                backgroundColor: colors.card,
                onRefresh: () async => ref.invalidate(driverTicketsProvider),
                // 🔴 ERROR IS ASKED FIRST — deliberately, and NOT a `.when`
                // ladder.
                //
                // Riverpod 3 delivers a failed future as AsyncLoading CARRYING
                // the error: `isLoading` stays TRUE. A loading-first ladder
                // therefore routes a FAILURE into the spinner branch, and the
                // driver watches a spinner that never resolves. That reads as a
                // hang, not a failure — so they never learn the call died and
                // they never retry. `GET /me/support-tickets` is BOUND and can
                // genuinely be down; this is the branch that says so.
                child: switch (tickets) {
                  AsyncValue(:final error?) => ListView(
                    padding: gutter,
                    children: [
                      HopBanner.error(
                        message: friendlyErrorMessage(error),
                        actionLabel: 'Retry',
                        onAction: () => ref.invalidate(driverTicketsProvider),
                      ),
                    ],
                  ),
                  AsyncValue(:final value?) =>
                    value.isEmpty
                        ? ListView(
                            padding: gutter,
                            children: [
                              SizedBox(height: hoppin.spacing.xl),
                              // Honest, and provably so: `GET /me/support-tickets`
                              // is BOUND, so an empty list is a FACT the server
                              // told us — not the ignorance the notification
                              // centre has to disclose. 🔴 DO NOT "unify" this
                              // with the centre's rung. Two empty lists, two
                              // completely different truths.
                              const HopEmptyState(
                                headline: 'No tickets yet',
                                supporting:
                                    'Stuck on a trip, short on pay, or something '
                                    'not working? Open a ticket and a person '
                                    'will pick it up.',
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: gutter,
                            itemCount: value.length,
                            separatorBuilder: (_, _) =>
                                SizedBox(height: hoppin.spacing.sm),
                            itemBuilder: (context, i) =>
                                _DriverTicketCard(ticket: value[i]),
                          ),
                  _ => Center(
                    child: CircularProgressIndicator(color: colors.accent),
                  ),
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                hoppin.spacing.gutter,
                hoppin.spacing.sm,
                hoppin.spacing.gutter,
                hoppin.spacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HopButton.primary(
                    label: 'File a complaint',
                    icon: Icons.add,
                    expand: true,
                    onPressed: () => showDriverNewTicketSheet(
                      context,
                      complaint: true,
                    ),
                  ),
                  SizedBox(height: hoppin.spacing.sm),
                  HopButton.secondary(
                    label: 'New support ticket',
                    icon: Icons.support_agent_outlined,
                    expand: true,
                    onPressed: () => showDriverNewTicketSheet(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the new-ticket sheet, optionally with [category] pre-selected.
///
/// The help hub calls this with a category already chosen, so a driver who
/// tapped "Pay or earnings" does not have to say so twice.
void showDriverNewTicketSheet(
  BuildContext context, {
  String category = DriverSupportCategories.general,
  bool complaint = false,
}) {
  final colors = context.hoppin.colors;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    elevation: 0,
    backgroundColor: Colors.transparent,
    barrierColor: colors.scrim,
    builder: (_) => HopSheet(
      child: _NewTicketSheet(category: category, complaint: complaint),
    ),
  );
}

/// One ticket in the list. Open tickets carry the lane accent; settled ones sit
/// back in textMid — the driver's eye should land on what is still live.
class _DriverTicketCard extends StatelessWidget {
  const _DriverTicketCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final open = ticket.status != 'closed' && ticket.status != 'resolved';
    final accent = open ? colors.accent : colors.textMid;

    final subtitle = ticket.createdAt == null
        ? ticket.status
        : '${ticket.status} · ${formatShortDateTime(ticket.createdAt!)}';

    return HopCard(
      onTap: () => context.go('$kDriverSupportRoute/${ticket.id}'),
      child: Row(
        children: [
          Icon(
            open
                ? Icons.mark_email_unread_outlined
                : Icons.mark_email_read_outlined,
            color: accent,
          ),
          SizedBox(width: hoppin.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.subject ?? 'Ticket',
                  style: hoppin.type.bodyMedium.copyWith(color: colors.textHi),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: hoppin.spacing.xs),
                Text(
                  subtitle,
                  style: hoppin.type.metaSmall.copyWith(color: colors.textMid),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.textMid),
        ],
      ),
    );
  }
}

class _NewTicketSheet extends ConsumerStatefulWidget {
  const _NewTicketSheet({required this.category, this.complaint = false});

  final String category;
  final bool complaint;

  @override
  ConsumerState<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends ConsumerState<_NewTicketSheet> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String? _typeCode;
  String? _rideId;

  /// The picked category — ALWAYS a value from the single-source taxonomy.
  late String _category = widget.category;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final colors = context.hoppin.colors;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      barrierColor: colors.scrim,
      builder: (_) => _CategorySheet(selected: _category),
    );
    if (picked != null && mounted) setState(() => _category = picked);
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    // A local validation message, and NO POST. An empty subject is the one
    // thing the endpoint requires.
    if (subject.isEmpty) {
      setState(() => _error = 'Give your ticket a subject.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = _bodyCtrl.text.trim();
      final id = await ref
          .read(supportRepositoryProvider)
          .createTicket(
            subject: subject,
            category: _category,
            typeCode: _typeCode,
            rideId: _rideId,
            body: body.isEmpty ? null : body,
          );
      ref.invalidate(driverTicketsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go('$kDriverSupportRoute/$id');
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final types = ref.watch(driverComplaintTypesProvider);
    final rides = ref.watch(driverSupportRidesProvider).value ?? const <Ride>[];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.complaint ? 'File a complaint' : 'New support ticket',
            style: hoppin.type.section.copyWith(color: colors.textHi),
          ),
          SizedBox(height: hoppin.spacing.md),
          TextField(
            key: const Key('driverSupport.newTicket.subject'),
            controller: _subjectCtrl,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            style: hoppin.type.body.copyWith(color: colors.textHi),
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          SizedBox(height: hoppin.spacing.sm),
          _CategoryField(
            key: const Key('driverSupport.newTicket.category'),
            category: _category,
            onTap: _busy ? null : _pickCategory,
          ),
          if (types.hasValue && types.requireValue.isNotEmpty) ...[
            SizedBox(height: hoppin.spacing.sm),
            _ComplaintTypeField(
              selected: _typeCode,
              types: types.requireValue,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _typeCode = value),
            ),
          ],
          if (rides.isNotEmpty) ...[
            SizedBox(height: hoppin.spacing.sm),
            _RideAttachmentField(
              selected: _rideId,
              rides: rides,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _rideId = value),
            ),
          ],
          SizedBox(height: hoppin.spacing.sm),
          TextField(
            key: const Key('driverSupport.newTicket.body'),
            controller: _bodyCtrl,
            enabled: !_busy,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: hoppin.type.body.copyWith(color: colors.textHi),
            decoration: const InputDecoration(
              labelText: 'Describe the problem (optional)',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: hoppin.spacing.sm),
            HopBanner.error(message: _error!),
          ],
          SizedBox(height: hoppin.spacing.md),
          HopButton.primary(
            key: const Key('driverSupport.newTicket.submit'),
            label: widget.complaint ? 'Submit complaint' : 'Open ticket',
            expand: true,
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _RideAttachmentField extends StatelessWidget {
  const _RideAttachmentField({
    required this.selected,
    required this.rides,
    required this.onChanged,
  });

  final String? selected;
  final List<Ride> rides;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: selected,
    decoration: const InputDecoration(labelText: 'Attach a ride (optional)'),
    items: [
      const DropdownMenuItem<String>(
        value: null,
        child: Text('No ride attached'),
      ),
      for (final ride in rides.take(20))
        DropdownMenuItem(
          value: ride.id,
          child: Text(
            '${ride.status} · ${ride.id.substring(0, 8)}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: onChanged,
  );
}

class _ComplaintTypeField extends StatelessWidget {
  const _ComplaintTypeField({
    required this.selected,
    required this.types,
    required this.onChanged,
  });
  final String? selected;
  final List<ComplaintTypeOption> types;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: selected,
    decoration: const InputDecoration(labelText: 'Complaint type'),
    items: [
      const DropdownMenuItem<String>(value: null, child: Text('Select a type')),
      for (final type in types)
        DropdownMenuItem(value: type.code, child: Text(type.label)),
    ],
    onChanged: onChanged,
  );
}

/// The category control — a tappable token-styled field, not a raw dropdown.
/// It reads its label from [DriverSupportCategories]; it never restates one.
class _CategoryField extends StatelessWidget {
  const _CategoryField({required this.category, this.onTap, super.key});

  final String category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(hoppin.radii.input),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Category'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                DriverSupportCategories.labelFor(category),
                style: hoppin.type.body.copyWith(color: colors.textHi),
              ),
            ),
            Icon(Icons.expand_more, color: colors.textMid),
          ],
        ),
      ),
    );
  }
}

/// The category selector sheet. Every row comes from the single-source
/// taxonomy.
class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return HopSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What is it about?',
            style: hoppin.type.section.copyWith(color: colors.textHi),
          ),
          SizedBox(height: hoppin.spacing.sm),
          for (final value in DriverSupportCategories.values)
            HopListRow(
              icon: driverSupportCategoryIcon(value),
              label: DriverSupportCategories.labelFor(value),
              divider: value != DriverSupportCategories.values.last,
              trailing: value == selected
                  ? Icon(Icons.check, color: colors.accent)
                  : null,
              onTap: () => Navigator.of(context).pop(value),
            ),
        ],
      ),
    );
  }
}

/// The icon for a support category. Shared with the help hub so the two
/// surfaces cannot drift.
IconData driverSupportCategoryIcon(String value) => switch (value) {
  DriverSupportCategories.trip => Icons.route_outlined,
  DriverSupportCategories.earnings => Icons.payments_outlined,
  DriverSupportCategories.documents => Icons.description_outlined,
  DriverSupportCategories.account => Icons.person_outline,
  DriverSupportCategories.app => Icons.phone_iphone_outlined,
  _ => Icons.help_outline,
};

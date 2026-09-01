import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app_router.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../features/profile/ui/widgets/settings_card.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../trips/data/models/driver_trip.dart';
import '../../trips/data/trips_repository.dart';
import '../data/support_repository.dart';
import 'support_screen.dart';

/// The Complaints tab: what went wrong, in the driver's words, optionally
/// pinned to the exact trip it happened on.
///
/// A complaint is a support ticket wearing a typed reason — `type_code` from
/// the server's complaint vocabulary and, when attached, the ride's id. The
/// admin side already reads both; this tab just stops hiding the fields.
class ComplaintsTab extends ConsumerStatefulWidget {
  const ComplaintsTab({super.key});

  @override
  ConsumerState<ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends ConsumerState<ComplaintsTab> {
  final _description = TextEditingController();
  String? _typeCode;
  DriverTrip? _trip;
  bool _busy = false;
  String? _error;
  String? _saved;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool get _valid => _typeCode != null && _description.text.trim().isNotEmpty;

  Future<void> _file(List<ComplaintType> types) async {
    if (!_valid) {
      setState(() => _error = 'Pick what went wrong and describe it.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _saved = null;
    });
    final subject = types.firstWhere((t) => t.code == _typeCode).label;
    final result = await ref.read(supportRepositoryProvider).create(
          subject: subject,
          category: _typeCode!,
          typeCode: _typeCode,
          rideId: _trip?.id,
          ticketBody: _description.text.trim(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      ok: (_) {
        _description.clear();
        setState(() {
          _typeCode = null;
          _trip = null;
          _saved = 'Complaint filed. The team will reply in its thread.';
        });
        ref.invalidate(ticketsProvider);
      },
      err: (e) => setState(() => _error = errorCopy(e)),
    );
  }

  /// Recent trips, newest first, for "the trip this is about". Server-backed
  /// list — a driver cannot attach a ride that is not theirs.
  Future<void> _pickTrip() async {
    final result = await ref.read(tripsRepositoryProvider).page();
    if (!mounted) return;
    final trips = result.valueOrNull?.trips ?? const <DriverTrip>[];
    if (trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No trips to attach yet.')));
      return;
    }
    final chosen = await showModalBottomSheet<DriverTrip>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text('Which trip is this about?', style: AppText.heading),
            ),
            for (final t in trips.take(15))
              ListTile(
                leading: const Icon(Icons.directions_car_outlined,
                    color: AppColors.textPrimary),
                title: Text(
                  '${t.pickupLabel} → ${t.dropoffLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body,
                ),
                subtitle: Text(
                  [
                    if (t.ref != null) t.ref!,
                    if (t.completedAt != null)
                      DateFormat('d MMM, HH:mm').format(t.completedAt!.toLocal()),
                  ].join(' · '),
                  style: AppText.caption,
                ),
                onTap: () => Navigator.of(sheet).pop(t),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => _trip = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final types =
        ref.watch(complaintTypesProvider).valueOrNull ?? const <ComplaintType>[];
    final tickets = ref.watch(ticketsProvider);
    final codes = types.map((t) => t.code).toSet();

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      children: [
        SettingsCard(
          title: 'File a Complaint',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: const Key('complaint_type'),
                    initialValue: _typeCode,
                    hint: Text('What went wrong?',
                        style: AppText.body
                            .copyWith(color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis),
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary),
                    decoration: _outlined(),
                    isExpanded: true,
                    items: types
                        .map((t) => DropdownMenuItem(
                              value: t.code,
                              child: Text(t.label,
                                  style: AppText.body,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (_busy || types.isEmpty)
                        ? null
                        : (v) => setState(() => _typeCode = v),
                  ),
                  const SizedBox(height: 18),
                  Text('Description', style: AppText.body.copyWith(fontSize: 17)),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('complaint_description'),
                    controller: _description,
                    enabled: !_busy,
                    maxLines: 5,
                    style: AppText.body,
                    onChanged: (_) => setState(() {}),
                    decoration: _outlined().copyWith(
                      hintText: 'Please describe the issue...',
                      hintStyle:
                          AppText.body.copyWith(color: AppColors.textDisabled),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('About a ride (optional)',
                      style: AppText.body.copyWith(fontSize: 17)),
                  const SizedBox(height: 10),
                  // The design's car-icon field. Tapping opens the driver's
                  // own recent trips; the chosen ride's id goes on the
                  // ticket so the team sees exactly which job it was.
                  InkWell(
                    key: const Key('attach_trip'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: _busy ? null : _pickTrip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_car_outlined,
                              size: 22, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _trip == null
                                  ? 'Attach the trip this is about'
                                  : '${_trip!.ref ?? 'Trip'} · '
                                      '${_trip!.pickupLabel} → ${_trip!.dropoffLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body.copyWith(
                                color: _trip == null
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (_trip != null)
                            InkWell(
                              onTap: _busy
                                  ? null
                                  : () => setState(() => _trip = null),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close,
                                    size: 18, color: AppColors.textSecondary),
                              ),
                            )
                          else
                            const Icon(Icons.keyboard_arrow_down,
                                color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!,
                        style:
                            AppText.body.copyWith(color: AppColors.negative)),
                  ],
                  if (_saved != null) ...[
                    const SizedBox(height: 14),
                    Text(_saved!,
                        style:
                            AppText.body.copyWith(color: AppColors.positive)),
                  ],
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'File Complaint',
                    busy: _busy,
                    onPressed: _valid ? () => _file(types) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsCard(
          title: 'Your Complaints',
          children: [
            tickets.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(32), child: AppLoading()),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Complaints are unavailable right now.',
                    style: AppText.bodySecondary),
              ),
              data: (all) {
                final complaints = all
                    .where((t) => t.category != null &&
                        codes.contains(t.category))
                    .toList();
                if (complaints.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 26),
                    child:
                        Text('No complaints filed.', style: AppText.bodySecondary),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    children: complaints
                        .map((t) => TicketCard(
                              ticket: t,
                              onTap: () => context
                                  .push('${Routes.supportTicket}/${t.id}'),
                            ))
                        .toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

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
}

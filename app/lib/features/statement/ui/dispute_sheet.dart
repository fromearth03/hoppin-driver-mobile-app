import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../support/data/support_repository.dart';
import '../../support/ui/support_screen.dart' show complaintTypesProvider;
import '../data/models/ledger_entry.dart';

/// The design's "Raise a Dispute" modal.
///
/// There is no dispute endpoint. A dispute is a support ticket citing the
/// exact ledger entry, so this posts through the existing
/// [SupportRepository] rather than growing a second, parallel path.
///
/// Departures from the Figma, each because the field has no source:
///
///  * "Your Name" / "Account ID (DRV - 00169)" — the driver profile carries a
///    name but no such account number; nothing on the ledger or the ticket
///    endpoint issues one. Both rows are omitted rather than shown with a
///    fabricated identifier, and the ticket already arrives attached to the
///    authenticated driver, so support does not need the driver to restate
///    who they are.
///  * "Select item to dispute" is a dropdown in the design (its sample value,
///    "VAT deduction", is not an entry type the ledger emits). The disputed
///    charge is the row the driver tapped, so it is STATED here, in the
///    server's own `display_title`, rather than offered as a choice that
///    would let them file against the wrong charge.
///
/// The reason vocabulary is fetched, never hardcoded: `type_code` is
/// validated server-side and an unknown code is a 400.
class DisputeSheet extends ConsumerStatefulWidget {
  final LedgerEntry entry;

  const DisputeSheet({super.key, required this.entry});

  /// Returns true when a dispute was filed.
  static Future<bool> show(BuildContext context, LedgerEntry entry) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DisputeSheet(entry: entry),
      ) ??
      false;

  @override
  ConsumerState<DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends ConsumerState<DisputeSheet> {
  final _description = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _typeCode;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit(List<ComplaintType> types) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final code = _typeCode;
    final result = await ref.read(supportRepositoryProvider).create(
          // The subject is the server's own words for the charge, so the
          // ticket queue names the same thing the driver saw.
          subject: widget.entry.displayTitle,
          category: code ?? 'fare_dispute',
          typeCode: code,
          ticketBody: _description.text.trim(),
          rideId: widget.entry.rideId,
          ledgerEntryId: widget.entry.id,
        );
    if (!mounted) return;

    result.when(
      ok: (_) => Navigator.of(context).pop(true),
      err: (e) => setState(() {
        _busy = false;
        _error = errorCopy(e);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final types = ref.watch(complaintTypesProvider).valueOrNull ??
        const <ComplaintType>[];

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Raise a Dispute', style: AppText.title),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Charge being disputed',
                          style: AppText.heading),
                      const SizedBox(height: 8),
                      _charge(),
                      const SizedBox(height: 16),
                      const Text('Reason', style: AppText.heading),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: const Key('dispute_reason'),
                        initialValue: _typeCode,
                        isExpanded: true,
                        hint: Text('Select a reason',
                            style: AppText.body
                                .copyWith(color: AppColors.textDisabled),
                            overflow: TextOverflow.ellipsis),
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: AppColors.textSecondary),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          border: _outline(),
                          enabledBorder: _outline(),
                          focusedBorder: _outline(AppColors.primary, 1.4),
                          disabledBorder: _outline(),
                        ),
                        items: types
                            .map((c) => DropdownMenuItem(
                                  value: c.code,
                                  child: Text(c.label,
                                      style: AppText.body,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (_busy || types.isEmpty)
                            ? null
                            : (v) => setState(() => _typeCode = v),
                      ),
                      const SizedBox(height: 16),
                      const Text('Description', style: AppText.heading),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const Key('dispute_description'),
                        controller: _description,
                        maxLines: 5,
                        enabled: !_busy,
                        style: AppText.body,
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Tell us why you think this charge is wrong.'
                            : null,
                        decoration: InputDecoration(
                          hintText: 'Explain your dispute...',
                          hintStyle: AppText.body
                              .copyWith(color: AppColors.textDisabled),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.all(14),
                          border: _outline(),
                          enabledBorder: _outline(),
                          focusedBorder: _outline(AppColors.primary, 1.4),
                          errorBorder: _outline(AppColors.negative),
                          focusedErrorBorder:
                              _outline(AppColors.negative, 1.4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // States what happens, not when: no endpoint or
                      // contract commits to a review deadline.
                      const Text(
                        'A reviewer reads every dispute. You can follow it '
                        'under Recent Issues in Help & Support.',
                        style: AppText.caption,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!,
                            style: AppText.caption
                                .copyWith(color: AppColors.negative)),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Cancel',
                              style: AppButtons.outlined().copyWith(
                                backgroundColor: const WidgetStatePropertyAll(
                                    AppColors.background),
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppButton(
                              label: 'Submit',
                              busy: _busy,
                              onPressed: () => _submit(types),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The disputed charge, in the server's words and at its own amount.
  Widget _charge() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(widget.entry.displayTitle, style: AppText.body),
            ),
            const SizedBox(width: 12),
            Text(widget.entry.amount.format(),
                style: AppText.body.copyWith(
                    color: AppColors.negative, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  OutlineInputBorder _outline([Color c = AppColors.border, double w = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );
}

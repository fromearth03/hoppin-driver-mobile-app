import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../data/appeals_repository.dart';
import '../data/models/penalty.dart';

/// The design's "Appeal Penalty" modal.
///
/// Two departures from the Figma, both deliberate:
///
///  * The Subject row in the design is a chevron that opens a "Document
///    Selection" picker. A penalty appeal is filed against the penalty the
///    driver tapped, not against a document they choose, so the subject is
///    shown as the penalty itself rather than as a control that would let
///    them file against the wrong thing.
///  * The design's footnote reads "Note: Appeals are reviewd with 48 hours."
///    Beyond the two typos, no endpoint or contract states a review SLA, so
///    the note says what we can stand behind instead of inventing a
///    deadline the operations team has not agreed to.
class AppealSheet extends ConsumerStatefulWidget {
  final Penalty penalty;

  const AppealSheet({super.key, required this.penalty});

  /// Returns true when an appeal was filed.
  static Future<bool> show(BuildContext context, Penalty penalty) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AppealSheet(penalty: penalty),
      ) ??
      false;

  @override
  ConsumerState<AppealSheet> createState() => _AppealSheetState();
}

class _AppealSheetState extends ConsumerState<AppealSheet> {
  final _description = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref.read(appealsRepositoryProvider).file(
          reason: _description.text.trim(),
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
                        child: Text('Appeal Penalty', style: AppText.title),
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
                      const Text('Subject', style: AppText.heading),
                      const SizedBox(height: 8),
                      _subject(),
                      const SizedBox(height: 16),
                      const Text('Description', style: AppText.heading),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _description,
                        maxLines: 6,
                        enabled: !_busy,
                        style: AppText.body,
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Tell us what happened so we can review it.'
                            : null,
                        decoration: InputDecoration(
                          hintText: 'Write a brief...',
                          hintStyle: AppText.body
                              .copyWith(color: AppColors.textDisabled),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.all(14),
                          border: _outline(),
                          enabledBorder: _outline(),
                          focusedBorder: _outline(AppColors.primary, 1.4),
                          errorBorder: _outline(AppColors.negative),
                          focusedErrorBorder: _outline(AppColors.negative, 1.4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // No SLA is stated anywhere in the contract, so this
                      // says what happens rather than when.
                      const Text(
                        'Note: A reviewer reads every appeal and you will get '
                        'their decision and reasons here.',
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
                              label: 'Back',
                              style: AppButtons.outlined().copyWith(
                                backgroundColor: WidgetStatePropertyAll(
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
                              onPressed: _submit,
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

  /// What is being appealed, stated rather than chosen.
  Widget _subject() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(widget.penalty.displayTitle, style: AppText.body),
            ),
            Text(widget.penalty.amount.format(),
                style: AppText.body.copyWith(color: AppColors.negative)),
          ],
        ),
      );

  OutlineInputBorder _outline([Color c = AppColors.border, double w = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );
}

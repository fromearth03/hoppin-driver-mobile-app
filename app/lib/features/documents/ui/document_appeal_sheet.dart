import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../stats/data/appeals_repository.dart';
import '../data/models/driver_document.dart';

/// The design's "Document Appeal" flow, reached from the dark grid tile.
///
/// It posts to `/drivers/me/compliance-appeals`, the only appeal endpoint
/// the service exposes. That endpoint takes a `document_type` and a reason,
/// so the Subject row is a real picker here — unlike the penalty appeal,
/// where there is no document to choose.
class DocumentAppealSheet extends ConsumerStatefulWidget {
  /// The types the driver could appeal about — the same catalogue the grid
  /// is built from, so they can only pick a type the service recognises.
  final List<DocumentType> types;

  /// Preselected when the driver came from a specific document.
  final DocumentType? initial;

  const DocumentAppealSheet({super.key, required this.types, this.initial});

  /// Returns true when an appeal was filed.
  static Future<bool> show(
    BuildContext context, {
    required List<DocumentType> types,
    DocumentType? initial,
  }) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DocumentAppealSheet(types: types, initial: initial),
      ) ??
      false;

  @override
  ConsumerState<DocumentAppealSheet> createState() =>
      _DocumentAppealSheetState();
}

class _DocumentAppealSheetState extends ConsumerState<DocumentAppealSheet> {
  final _description = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DocumentType? _subject;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subject = widget.initial;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_subject == null) {
      setState(() => _error = 'Choose which document this is about.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref.read(appealsRepositoryProvider).file(
          documentType: _subject!.code,
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

  Future<void> _pickSubject() async {
    final chosen = await showModalBottomSheet<DocumentType>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final type in widget.types)
              ListTile(
                title: Text(type.label, style: AppText.body),
                trailing: type.code == _subject?.code
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(sheet).pop(type),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) setState(() => _subject = chosen);
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
                        child: Text('Document Appeal', style: AppText.title),
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
                      InkWell(
                        onTap: _busy ? null : _pickSubject,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _subject?.label ?? 'Document Selection',
                                  style: _subject == null
                                      ? AppText.body.copyWith(
                                          color: AppColors.textDisabled)
                                      : AppText.body,
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
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
                      // The design reads "Note: Appeals are reviewd with 48
                      // hours." Beyond the two typos, nothing in the service
                      // states a review SLA, so this promises what we can
                      // keep rather than a deadline nobody has agreed to.
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
                                backgroundColor:
                                    const WidgetStatePropertyAll(
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

  OutlineInputBorder _outline([Color c = AppColors.border, double w = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/nav/app_shell.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/driver_document.dart';
import '../logic/documents_controller.dart';
import '../logic/upload_controller.dart';
import 'document_appeal_sheet.dart';
import 'upload_sheet.dart';
import 'widgets/document_card.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(documentsControllerProvider);
    final controller = ref.read(documentsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document'),
        actions: [
          // The design's dark circular upload button in the header. It picks
          // the document first, because the service presigns per type — a
          // file with no type has nowhere to go.
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _HeaderUploadButton(
              onPressed: () => _chooseAndUpload(context, ref),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorState(
          error: e is ApiException ? e : ApiException('INTERNAL', '', 500),
          onRetry: controller.refresh,
        ),
        data: (slots) {
          final needsAction = slots.where((s) => s.needsAction).toList();
          final types = slots.map((s) => s.type).toList();

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (needsAction.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _ActionBanner(count: needsAction.length),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      16, 12, 16, AppShell.bottomClearance),
                  // Sized by extent, not aspect ratio: the card's content is
                  // a fixed stack (icon, two text lines), so its height is a
                  // constant — an aspect ratio would squash it on narrow
                  // phones and balloon it on tablets. The max tile width
                  // adds columns as the screen grows instead of stretching
                  // two tiles to fill it.
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 230,
                      mainAxisExtent: 148,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    delegate: SliverChildListDelegate([
                      ...slots.map((slot) => DocumentCard(
                            slot: slot,
                            onTap: () =>
                                _upload(context, ref, slot.type.code),
                          )),
                      // Last cell, as in the design.
                      DocumentAppealCard(
                        onTap: () async {
                          final filed = await DocumentAppealSheet.show(
                            context,
                            types: types,
                          );
                          if (!context.mounted || !filed) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Appeal submitted. You will see the decision here.'),
                            ),
                          );
                        },
                      ),
                    ]),
                  ),
                ),
                // Rejections are the one thing a tile cannot hold — the
                // admin's reason is a sentence, and truncating it is what
                // leaves a driver re-uploading the same bad file. They get
                // their own full-width rows below the grid.
                if (slots.any((s) => s.document?.rejectionReason != null))
                  SliverList.list(
                    children: [
                      for (final slot in slots)
                        if (slot.document?.rejectionReason != null)
                          _RejectionNote(slot: slot),
                      const SizedBox(height: 24),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Header upload: pick the type, then the file.
  Future<void> _chooseAndUpload(BuildContext context, WidgetRef ref) async {
    final slots = ref.read(documentsControllerProvider).valueOrNull;
    if (slots == null) return;

    final uploadable =
        slots.where((s) => s.type.uploadable).map((s) => s.type).toList();
    if (uploadable.isEmpty) return;

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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Select Document', style: AppText.heading),
            ),
            for (final type in uploadable)
              ListTile(
                title: Text(type.label, style: AppText.body),
                onTap: () => Navigator.of(sheet).pop(type),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    await _upload(context, ref, chosen.code);
  }

  Future<void> _upload(
      BuildContext context, WidgetRef ref, String documentType) async {
    final file = await UploadSheet.pick(context);
    if (file == null || !context.mounted) return;

    final bytes = await file.readAsBytes();
    if (!context.mounted) return;

    final result = await ref
        .read(uploadControllerProvider.notifier)
        .upload(documentType, bytes, file.name);
    if (!context.mounted) return;

    result.when(
      ok: (_) {
        ref.read(documentsControllerProvider.notifier).refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Uploaded — we will review it shortly.')));
      },
      err: (e) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorCopy(e)))),
    );
  }
}

class _HeaderUploadButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _HeaderUploadButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Upload a document',
        child: Material(
          color: AppColors.textPrimary,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(Icons.cloud_upload_outlined,
                  color: AppColors.surface, size: 21),
            ),
          ),
        ),
      );
}

class _ActionBanner extends StatelessWidget {
  final int count;
  const _ActionBanner({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.negative.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                size: 20, color: AppColors.negative),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                count == 1
                    ? 'One document needs your attention'
                    : '$count documents need your attention',
                style: AppText.body.copyWith(color: AppColors.negative),
              ),
            ),
          ],
        ),
      );
}

/// A rejection reason, rendered verbatim and in full. That single field is
/// the difference between a driver fixing the problem and re-uploading the
/// same file until they call support.
class _RejectionNote extends StatelessWidget {
  final DocumentSlot slot;
  const _RejectionNote({required this.slot});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.negative.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${slot.type.label} was not accepted',
                style: AppText.heading.copyWith(fontSize: 15)),
            const SizedBox(height: 4),
            Text(slot.document!.rejectionReason!, style: AppText.body),
          ],
        ),
      );
}

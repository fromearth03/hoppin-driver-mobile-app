import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../logic/documents_controller.dart';
import '../logic/upload_controller.dart';
import 'upload_sheet.dart';
import 'widgets/document_card.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(documentsControllerProvider);
    final controller = ref.read(documentsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorState(
          error: e is ApiException ? e : ApiException('INTERNAL', '', 500),
          onRetry: controller.refresh,
        ),
        data: (slots) {
          final needsAction = slots.where((s) => s.needsAction).length;
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (needsAction > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      needsAction == 1
                          ? 'One document needs your attention'
                          : '$needsAction documents need your attention',
                      style: AppText.heading,
                    ),
                  ),
                const SizedBox(height: 8),
                ...slots.map((slot) => DocumentCard(
                      slot: slot,
                      onUpload: () => _upload(context, ref, slot.type.code),
                    )),
              ],
            ),
          );
        },
      ),
    );
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

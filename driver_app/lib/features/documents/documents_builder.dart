import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'documents_interactor.dart';
import 'documents_state.dart';
import 'documents_view.dart';

/// Assembly point of the documents riblet (DOCS/05): declares the interactor's
/// provider so the view and the router both import the builder, never each
/// other.
///
/// Deliberately NOT autoDispose. The driver bounces between `/documents` and
/// `/` (and, in wave 2, into the upload sheet and back); a disposed interactor
/// would re-fetch the whole wallet on every return, and the state must survive
/// the offer takeover being pushed over the top.
final documentsInteractorProvider =
    NotifierProvider<DocumentsInteractor, DocumentsState>(
  DocumentsInteractor.new,
);

/// The riblet's public entry widget — what `/documents` builds.
///
/// This is the FRONT DOOR. `POST /drivers/me/online` is compliance-gated, so a
/// brand-new driver cannot reach a single other screen in this app until they
/// have been here. `GET /drivers/me/documents` was bound and typed at
/// `driver_repository.dart:229` and shipped with ZERO UI over it.
class DocumentsRiblet extends ConsumerWidget {
  /// Creates the documents riblet.
  const DocumentsRiblet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const DocumentsView();
}

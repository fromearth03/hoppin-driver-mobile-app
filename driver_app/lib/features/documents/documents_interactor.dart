import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'documents_state.dart';

/// THE BRAIN of the documents riblet (DOCS/05): reads
/// `GET /drivers/me/documents` into [DocumentsState] and owns the refresh
/// intent.
///
/// No `BuildContext`, no navigation, no widget imports — the router navigates,
/// the view renders.
///
/// This surface is the FRONT DOOR: `POST /drivers/me/online` is
/// compliance-gated, so a brand-new driver cannot reach a single other screen
/// in this app until they can see and manage their documents.
class DocumentsInteractor extends Notifier<DocumentsState> {
  @override
  DocumentsState build() {
    unawaited(refresh());
    return const DocumentsState();
  }

  /// Re-reads `GET /drivers/me/documents`. LANE B (13-02) fires this after
  /// every successful confirm.
  Future<void> refresh() async {
    try {
      final docs = await ref.read(driverRepositoryProvider).documents();
      state = state.copyWith(
        phase: DocumentsPhase.ready,
        documents: docs,
        error: null,
      );
    } on ApiException catch (e) {
      // 🔴 BRANCH ON THE CODE, NEVER ON THE BARE STATUS. A status number is not
      // a contract — the code is. (Inherited and non-negotiable: 409 is both
      // CHAT_CLOSED and ACTIVE_TRIP_EXISTS, and the app once acted on the
      // wrong one.)
      if (e.code == 'STORAGE_DISABLED') {
        state = state.copyWith(
          phase: DocumentsPhase.storageDisabled,
          error: null,
        );
        return;
      }
      state = state.copyWith(
        phase: DocumentsPhase.error,
        error: friendlyErrorMessage(e),
      );
    } on Exception catch (e) {
      // 🔴 A transport failure is IGNORANCE. It is NOT "you have no documents":
      // rendering eight cheerful empty rows over a dead network tells a driver
      // their wallet is empty when we have no idea what is in it.
      state = state.copyWith(
        phase: DocumentsPhase.error,
        error: friendlyErrorMessage(e),
      );
    }
  }

  /// The FORWARD EXIT from both rungs — `POST /me/support-tickets` (a bound,
  /// live endpoint; `DOCS/04` `[either]`).
  ///
  /// 🔴 A DISCLOSURE THAT STRANDS THE DRIVER IS ONLY HALF-HONEST. Telling a
  /// driver "we cannot tell you whether you may work" and then giving them
  /// nowhere to go is worse than useless — it is the rider's
  /// `CallUnavailableState` lesson, and the exit there is the same one: a real
  /// ticket, read by a real person.
  ///
  /// There is no driver support SCREEN yet, and this deliberately does not
  /// pretend there is. It opens a ticket and says so.
  Future<void> contactSupport(String subject) async {
    state = state.copyWith(supportPhase: SupportPhase.sending, error: null);
    try {
      await ref.read(supportRepositoryProvider).createTicket(
            subject: subject,
            category: 'documents',
          );
      state = state.copyWith(supportPhase: SupportPhase.sent);
    } on Exception catch (e) {
      state = state.copyWith(
        supportPhase: SupportPhase.failed,
        error: friendlyErrorMessage(e),
      );
    }
  }

  /// Opens a real, reviewable support ticket for a document decision. Appeals
  /// carry the document id and server status so support can act without asking
  /// the driver to repeat the compliance context.
  Future<void> appealDocument(DriverDocument document) async {
    state = state.copyWith(supportPhase: SupportPhase.sending, error: null);
    try {
      await ref.read(supportRepositoryProvider).createTicket(
            subject: 'Appeal document review: ${document.documentType}',
            category: 'documents',
            priority: 'high',
            body: 'I would like to appeal the review decision for document '
                '${document.documentType} (id: ${document.id}). Current status: '
                '${document.verificationStatus}. Please review this document '
                'and tell me what correction or replacement is required.',
          );
      state = state.copyWith(supportPhase: SupportPhase.sent);
    } on Exception catch (e) {
      state = state.copyWith(
        supportPhase: SupportPhase.failed,
        error: friendlyErrorMessage(e),
      );
    }
  }
}

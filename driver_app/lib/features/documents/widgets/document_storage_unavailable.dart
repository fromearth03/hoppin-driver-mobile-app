import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The designed `503 STORAGE_DISABLED` state (OD-11).
///
/// `GET /drivers/me/documents` and the upload chain both answer
/// `503 STORAGE_DISABLED` when object storage is not configured on the
/// deployment. Without this rung the driver gets a blank pane or a raw
/// exception — on the ONE screen that stands between them and their first
/// shift, because `POST /drivers/me/online` is compliance-gated.
///
/// 🔴 A DISCLOSURE THAT STRANDS THE DRIVER IS ONLY HALF-HONEST. The rider's
/// `CallUnavailableState` set this precedent: a degraded state must carry a
/// real forward exit. Here that is Retry (re-runs the read — the outage may be
/// transient) and a route to support (it may not be, and the driver cannot fix
/// object storage from a phone).
class DocumentStorageUnavailable extends StatelessWidget {
  /// Creates the 503 STORAGE_DISABLED rung.
  const DocumentStorageUnavailable({
    required this.onRetry,
    this.onContactSupport,
    super.key,
  });

  /// Re-runs `GET /drivers/me/documents`.
  final VoidCallback onRetry;

  /// The way out when retrying does not help. Null hides the exit.
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(hoppin.spacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HopEmptyState(
              headline: 'Document upload is temporarily unavailable',
              // Names the ONE thing that is broken, and is explicit that the
              // driver's existing standing is untouched — a driver reading this
              // must not conclude they have been deactivated.
              supporting:
                  'Document storage is not switched on right now, so we cannot '
                  'show or accept documents. Nothing you have already sent us '
                  'has been lost, and your account is unaffected.',
              actionLabel: 'Try again',
              onAction: onRetry,
            ),
            if (onContactSupport != null) ...[
              SizedBox(height: hoppin.spacing.md),
              HopButton.ghost(
                label: 'Contact support',
                onPressed: onContactSupport,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

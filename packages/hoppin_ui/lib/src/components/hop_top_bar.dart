import 'package:flutter/material.dart';

import '../theme/context_extension.dart';
import '../tokens/spacing.dart';
import 'hop_glass.dart';

/// The rider top bar: a FLOATING FROSTED PILL.
///
/// It is not welded to the top of the page. It is a detached stadium that
/// hovers over the content with a margin on the left, the right and above (the
/// last measured from the status bar, not from the physical screen edge — it
/// floats BELOW the notch, never under it), it casts, and the page scrolls
/// UNDERNEATH it and blurs through it.
///
/// It carries what it always carried: an optional back chevron, the [title],
/// the notification bell with its unread badge, and the avatar.
///
/// 🔴 **The concentric avatar.** The avatar is a perfect circle nested inside
/// the pill's own curvature — the two arcs share a centre-line and the gap
/// between them is uniform all the way round, so the avatar reads as cut from
/// the same arc rather than dropped on top of it. Every number is derived in
/// [HoppinChrome]; `hop_top_bar_test` asserts the identity
/// `pillRadius - avatarRadius == avatarInset` and that the inset is the same on
/// the top, bottom and trailing edges. Do not hardcode any of them here.
///
/// It still `implements PreferredSizeWidget` so the ~10 off-shell screens that
/// hand it to a `Scaffold.appBar` keep compiling — but note [preferredSize] now
/// reports the FULL floating footprint (pill + its top and bottom margins), not
/// the bare bar height, because the pill occupies more vertical space than it
/// paints. Screens that want content to pass beneath it should layer it in a
/// `Stack` (see `RiderShell`) rather than reserve a slot for it.
class HopTopBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates the rider top bar.
  const HopTopBar({
    this.title,
    this.onBack,
    this.onBell,
    this.onAvatarTap,
    this.avatarTooltip,
    this.notificationCount = 0,
    this.avatarImage,
    super.key,
  });

  /// Header title. Null renders a title-less bar.
  final String? title;

  /// Back intent. Null hides the chevron.
  final VoidCallback? onBack;

  /// Bell tap intent (notifications).
  final VoidCallback? onBell;

  /// Avatar tap intent (profile).
  final VoidCallback? onAvatarTap;

  /// Accessible label for the avatar control.
  ///
  /// The bell and the chevron carry tooltips; the avatar did not, so it read to
  /// a screen reader as an unlabelled tappable circle — and what it DOES varies
  /// by app (the driver's opens sign-out, the rider's opens the profile hub),
  /// so no single hardcoded label would be honest. Callers name their own.
  ///
  /// Null keeps the bare [InkResponse] — no tooltip, no semantics wrapper — so
  /// existing call sites render byte-identically.
  final String? avatarTooltip;

  /// Unread notification count — a red badge on the bell. 0 hides the badge.
  final int notificationCount;

  /// Optional avatar image; falls back to a person glyph.
  final ImageProvider? avatarImage;

  /// The floating footprint: the pill plus the air above and below it.
  @override
  Size get preferredSize => const Size.fromHeight(
    HoppinChrome.barHeight + HoppinChrome.pillMargin * 2,
  );

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final chrome = hoppin.chrome;
    final topInset = MediaQuery.paddingOf(context).top;

    return HopGlass(
      // The pill DETACHES: equal air left and right, and above it the status-bar
      // inset PLUS the same margin — so on a notched phone it floats clear of
      // the notch instead of tucking under it.
      margin: EdgeInsets.fromLTRB(
        chrome.pillMargin,
        topInset + chrome.pillMargin,
        chrome.pillMargin,
        chrome.pillMargin,
      ),
      borderRadius: BorderRadius.circular(chrome.pillRadius),
      child: SizedBox(
        height: chrome.barHeight,
        child: Padding(
          // The trailing inset is the CONCENTRIC gap — the same 8pt that sits
          // above and below the avatar, so the ring of air around it closes.
          // The leading inset is the pill radius: content inside a stadium must
          // clear the arc, and a pill's arc eats a full radius at the ends.
          // (Halved when a chevron is present — an IconButton brings its own
          // 48pt hit box, which already holds the glyph off the curve.)
          padding: EdgeInsets.only(
            left: onBack != null ? chrome.pillRadius / 2 : chrome.pillRadius,
            right: chrome.avatarInset,
          ),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: Icon(Icons.chevron_left, color: colors.textHi),
                  iconSize: 28,
                  onPressed: onBack,
                  tooltip: 'Back',
                ),
              if (title != null)
                Expanded(
                  child: Text(
                    title!,
                    style: hoppin.type.h1.copyWith(color: colors.textHi),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              _bell(context),
              SizedBox(width: hoppin.spacing.xs),
              _avatar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bell(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_none, color: colors.textHi),
          iconSize: 26,
          onPressed: onBell,
          tooltip: 'Notifications',
        ),
        if (notificationCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: notificationCount > 9 ? 4 : 0,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.error,
                shape: notificationCount > 9
                    ? BoxShape.rectangle
                    : BoxShape.circle,
                borderRadius: notificationCount > 9
                    ? BorderRadius.circular(hoppin.radii.pill)
                    : null,
                // The badge is the one thing allowed to break the glass plane —
                // it must survive being read against a blurred street map.
                border: Border.all(color: colors.glassEdge, width: 1.5),
              ),
              child: Text(
                '$notificationCount',
                style: hoppin.type.metaSmall.copyWith(
                  color: colors.onAccent,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The concentric avatar. Sized [HoppinChrome.avatarSize] and centred in the
  /// pill's [HoppinChrome.barHeight], which is what puts an identical
  /// [HoppinChrome.avatarInset] above it, below it, and (via the Row's trailing
  /// padding) outboard of it — the uniform ring that makes the two arcs read as
  /// one piece of geometry.
  Widget _avatar(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final chrome = hoppin.chrome;
    final avatar = InkResponse(
      key: const Key('hop_top_bar_avatar'),
      onTap: onAvatarTap,
      radius: chrome.avatarRadius + HoppinSpacing.xs,
      child: Container(
        width: chrome.avatarSize,
        height: chrome.avatarSize,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.accentSubtle,
          // The avatar gets the glass rim too, so the inner arc catches the
          // same light as the outer one. Without it the circle looks pasted on.
          border: Border.all(color: colors.glassEdge),
          image: avatarImage == null
              ? null
              : DecorationImage(image: avatarImage!, fit: BoxFit.cover),
        ),
        child: avatarImage == null
            ? Icon(Icons.person, color: colors.accent, size: 26)
            : null,
      ),
    );

    final label = avatarTooltip;
    if (label == null) return avatar;
    return Tooltip(message: label, child: avatar);
  }
}

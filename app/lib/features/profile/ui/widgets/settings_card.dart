import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

/// The white rounded panel the profile, settings and support designs group
/// their rows into: one card, hairline dividers between rows, nothing
/// between the card and the page ground but a 20pt gutter.
class SettingsCard extends StatelessWidget {
  final List<Widget> children;

  /// A heading rendered inside the card above the first row, with the same
  /// hairline under it that separates the rows. Support and Delete Account
  /// use it; Settings has no headings.
  final String? title;

  final EdgeInsetsGeometry margin;

  const SettingsCard({
    super.key,
    required this.children,
    this.title,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (title != null) {
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Text(title!, style: AppText.title.copyWith(fontSize: 20)),
      ));
      rows.add(const SettingsDivider(inset: 0));
    }
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const SettingsDivider());
      rows.add(children[i]);
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }
}

/// The hairline between two rows. Inset from the card edge, as the design
/// draws it — it separates the rows without cutting the card in half.
class SettingsDivider extends StatelessWidget {
  final double inset;
  const SettingsDivider({super.key, this.inset = 20});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: const Divider(height: 1, thickness: 1, color: AppColors.border),
      );
}

/// One row inside a [SettingsCard]: an outline icon, a label, and a trailing
/// control — a switch, a chevron, or nothing.
class SettingsRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? labelColor;
  final String? subtitle;

  const SettingsRow({
    super.key,
    required this.label,
    this.icon,
    this.trailing,
    this.onTap,
    this.labelColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 24, color: labelColor ?? AppColors.textPrimary),
                const SizedBox(width: 18),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.body.copyWith(
                        fontSize: 17,
                        color: labelColor ?? AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppText.caption),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      );
}

/// The pill switch the settings design uses — orange track when on.
class SettingsSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) => Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.accent,
        inactiveThumbColor: AppColors.accent,
        inactiveTrackColor: AppColors.border,
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      );
}

/// The centred-title app bar every one of these screens opens with: a bare
/// back arrow on the page ground, no elevation, no fill of its own.
PreferredSizeWidget settingsAppBar(BuildContext context, String title) => AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleSpacing: 0,
      // Always drawn. Settings is opened from Home's gear with `go`, which
      // replaces rather than pushes, so canPop() was false and the screen
      // had no way back at all — the driver's only exit was the bottom bar,
      // which Settings does not show.
      leading: IconButton(
        icon: const Icon(Icons.arrow_back,
            color: AppColors.textPrimary, size: 26),
        // Pop when there is a stack to pop, otherwise fall back to Home:
        // both are "the way I came in" from the driver's side.
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(Routes.home),
      ),
      title: Text(title, style: AppText.title.copyWith(fontSize: 24)),
    );

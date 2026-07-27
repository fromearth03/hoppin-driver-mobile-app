import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'driver_support_categories.dart';
import 'support_router.dart';
import 'support_screen.dart';

/// The Help & Support hub (PS-05, Figma `Help & Support.jpg`).
///
/// FAQ-SHAPED, BUT NOT AN FAQ. Every row here opens a real support ticket in
/// the category it names. Not one of them renders an answer.
///
/// 🔴 NO FAQ CONTENT IS INVENTED, AND THAT IS THE WHOLE DESIGN OF THIS SCREEN.
/// There is no help-article endpoint and no approved copy deck. An invented
/// answer to "When do I get paid?" is an **invented policy statement** — it
/// would be the app telling a driver something about their money that nobody at
/// Hoppin has agreed to, and a driver would act on it. A row that opens a ticket
/// to a human who actually knows is worth more than a plausible paragraph that
/// might be wrong.
///
/// When a real, owned help corpus exists, these rows body-swap to it with no
/// change to the shape of this screen.
class DriverHelpSupportScreen extends ConsumerWidget {
  /// Creates the help hub.
  const DriverHelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    // Each row is a QUESTION and the category the ticket is filed under. There
    // is no `answer` field, deliberately — there is nowhere honest to get one.
    const topics = <({String question, String category})>[
      (
        question: 'A problem on a trip',
        category: DriverSupportCategories.trip,
      ),
      (
        question: 'My pay looks wrong',
        category: DriverSupportCategories.earnings,
      ),
      (
        question: 'A document or licence question',
        category: DriverSupportCategories.documents,
      ),
      (
        question: 'My account or vehicle details',
        category: DriverSupportCategories.account,
      ),
      (
        question: 'Something in the app is broken',
        category: DriverSupportCategories.app,
      ),
      (
        question: 'Something else',
        category: DriverSupportCategories.general,
      ),
    ];

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HopTopBar(
              title: 'Help & Support',
              // NEVER null — a null back intent hides the chevron entirely and
              // `context.go` replaces rather than pushes, so there is nothing
              // to pop and the driver is stranded.
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: hoppin.spacing.gutter,
                  vertical: hoppin.spacing.gutter,
                ),
                children: [
                  const HopBanner.notice(
                    message: DriverSupportScreen.humanSupportDisclosure,
                  ),
                  SizedBox(height: hoppin.spacing.md),
                  Text(
                    'What do you need help with?',
                    style:
                        hoppin.type.section.copyWith(color: colors.textHi),
                  ),
                  SizedBox(height: hoppin.spacing.sm),
                  HopCard(
                    child: Column(
                      children: [
                        for (final topic in topics)
                          HopListRow(
                            icon: driverSupportCategoryIcon(topic.category),
                            label: topic.question,
                            divider: topic != topics.last,
                            // Opens a ticket in this category — pre-selected, so
                            // a driver who tapped "My pay looks wrong" does not
                            // have to say so twice. It does NOT open an article,
                            // because there is no true one to open.
                            onTap: () => showDriverNewTicketSheet(
                              context,
                              category: topic.category,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: hoppin.spacing.md),
                  HopButton.secondary(
                    label: 'View my tickets',
                    expand: true,
                    onPressed: () => context.go(kDriverSupportRoute),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

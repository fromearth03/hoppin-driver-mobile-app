import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/widgets/app_buttons.dart';

/// How many steps the self-registration wizard has, end to end.
///
/// Four, as the design draws it: details, licences, vehicle, and the approval
/// gate. The gate is a real step — the driver is not finished until an admin
/// says so — so it earns its dot even though the driver does nothing on it.
const kWizardSteps = 4;

/// The 1-2-3-4 dot rail the design puts under the header of every wizard step.
///
/// Three states per dot, all of which the design draws:
///  * done — solid indigo, no ring
///  * current — solid indigo with a ring floating off it
///  * upcoming — flat grey, grey numeral
///
/// The rail between two dots is indigo only when the left dot is already
/// behind the driver, which is how the design shows progress travelling.
class WizardSteps extends StatelessWidget {
  /// 1-based, so it reads the same as the numeral the driver sees.
  final int current;
  final int total;

  const WizardSteps({super.key, required this.current, this.total = kWizardSteps});

  static const _diameter = 54.0;
  static const _ringGap = 5.0;

  @override
  Widget build(BuildContext context) => SizedBox(
        // Room for the current step's ring, which sits outside the dot.
        height: _diameter + (_ringGap + 2) * 2,
        child: Row(
          children: [
            for (var step = 1; step <= total; step++) ...[
              if (step > 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: step <= current ? AppColors.primary : AppColors.border,
                  ),
                ),
              _dot(step),
            ],
          ],
        ),
      );

  Widget _dot(int step) {
    final done = step <= current;
    final isCurrent = step == current;
    return Container(
      height: _diameter,
      width: _diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? AppColors.primary : AppColors.border,
        shape: BoxShape.circle,
        // The ring is drawn as a spread-less shadow so it floats clear of the
        // dot instead of thickening it, which is how the design has it.
        boxShadow: isCurrent
            ? const [
                BoxShadow(
                  color: AppColors.primary,
                  spreadRadius: _ringGap + 2,
                ),
                BoxShadow(
                  color: AppColors.background,
                  spreadRadius: _ringGap,
                ),
              ]
            : null,
      ),
      child: Text(
        '$step',
        style: AppText.title.copyWith(
          fontSize: 24,
          color: done ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// The indigo pill the design floats above every wizard step: a round back
/// button and the step's title, on the brand gradient.
class WizardHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const WizardHeader({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) => Container(
        height: 84,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.primaryDark, AppColors.primaryLight],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            if (onBack != null)
              Material(
                color: Colors.white.withValues(alpha: 0.16),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBack,
                  child: const SizedBox(
                    height: 44,
                    width: 44,
                    child:
                        Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                ),
              )
            else
              const SizedBox(width: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
}

/// The reassurance line the design closes every wizard step with.
class WizardFooterNote extends StatelessWidget {
  const WizardFooterNote({super.key});

  @override
  Widget build(BuildContext context) => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined,
              size: 16, color: AppColors.textSecondary),
          SizedBox(width: 8),
          Flexible(
            child: Text('Your data is encrypted & secure',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySecondary),
          ),
        ],
      );
}

/// The Back / Save & Continue pair the design pins to the bottom of steps 2-4.
class WizardActions extends StatelessWidget {
  final String continueLabel;
  final VoidCallback? onBack;
  final VoidCallback? onContinue;
  final bool busy;

  const WizardActions({
    super.key,
    required this.onContinue,
    this.onBack,
    this.continueLabel = 'Save & Continue',
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          if (onBack != null) ...[
            Expanded(
              child: AppOutlinedButton(
                key: const Key('wizard_back'),
                label: 'Back',
                onPressed: busy ? null : onBack,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: AppButton(
              key: const Key('wizard_continue'),
              label: continueLabel,
              busy: busy,
              onPressed: onContinue,
            ),
          ),
        ],
      );
}

/// The frame every wizard step shares: header pill, step rail, the step's own
/// content, then the actions and the encryption note.
///
/// [card] wraps the content in the white panel steps 2 and 4 sit on; steps 1
/// and 3 lay their fields straight onto the page ground, as the design does.
class WizardScaffold extends StatelessWidget {
  final String title;
  final int step;
  final Widget child;
  final Widget? actions;
  final VoidCallback? onBack;
  final bool card;

  const WizardScaffold({
    super.key,
    required this.title,
    required this.step,
    required this.child,
    this.actions,
    this.onBack,
    this.card = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          WizardSteps(current: step),
          const SizedBox(height: 28),
          if (card)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  child,
                  if (actions != null) ...[
                    const SizedBox(height: 28),
                    actions!,
                  ],
                ],
              ),
            )
          else ...[
            child,
            if (actions != null) ...[
              const SizedBox(height: 32),
              actions!,
            ],
          ],
          const SizedBox(height: 20),
          const WizardFooterNote(),
          const SizedBox(height: 24),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WizardHeader(title: title, onBack: onBack),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: content,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

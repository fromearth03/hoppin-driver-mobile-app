import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_interactor.dart';
import 'dashboard_router.dart';
import 'dashboard_state.dart';
import 'dashboard_view.dart';

/// Assembly point of the dashboard riblet (DOCS/05): declares the
/// interactor's provider so the view and the router both import the
/// builder, never each other.
final dashboardInteractorProvider =
    NotifierProvider<DashboardInteractor, DashboardState>(
  DashboardInteractor.new,
);

/// The riblet's public entry widget — what the route builds and what other
/// riblets attach: the router's navigation listener wrapped around the
/// dumb view.
class DashboardRiblet extends ConsumerWidget {
  const DashboardRiblet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const DashboardRouterListener(child: DashboardView());
}

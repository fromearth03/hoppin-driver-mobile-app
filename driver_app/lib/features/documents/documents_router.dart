import 'package:go_router/go_router.dart';

import 'documents_builder.dart';

/// ALL documents navigation lives in this file (riblet rule, DOCS/05).
///
/// `/documents` is the compliance wallet — the surface a brand-new driver must
/// pass through before `POST /drivers/me/online` will let them work at all.
final documentsRoutes = <RouteBase>[
  GoRoute(path: '/documents', builder: (_, _) => const DocumentsRiblet()),
];

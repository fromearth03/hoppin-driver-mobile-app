/// Hoppin shared mobile core.
///
/// The single public surface both apps import:
///   import 'package:hoppin_shared/hoppin_shared.dart';
///
/// It bundles the ride-service (`:8080`) API client, Supabase auth, the typed
/// domain models, the feature repositories, and the Riverpod composition root.
library;

// Config
export 'src/config/env.dart';

// Auth
export 'src/auth/auth_service.dart';
export 'src/auth/auth_validators.dart';

// API
export 'src/api/api_client.dart';
export 'src/api/api_exception.dart';

// Models
export 'src/models/ad.dart';
export 'src/models/cancellation_reason_option.dart';
export 'src/models/destination_filter.dart';
export 'src/models/driver_document.dart';
export 'src/models/ride.dart';
export 'src/models/ride_driver_info.dart';
export 'src/models/driver_position.dart';
export 'src/models/ride_geo.dart';
export 'src/models/fare_estimate.dart';
export 'src/models/ride_offer.dart';
export 'src/models/receipt.dart';
export 'src/models/saved_location.dart';
export 'src/models/place_suggestion.dart';
export 'src/models/promo_offer.dart';
export 'src/models/platform_contacts.dart';
export 'src/models/app_status.dart';
export 'src/models/vehicle_type.dart';
export 'src/models/payout_account.dart';
export 'src/avatar/avatar_picker.dart';
export 'src/avatar/avatar_upload_state.dart';
export 'src/avatar/avatar_upload_controller.dart';
export 'src/models/promo_result.dart';
export 'src/models/sos_event.dart';
export 'src/models/support_ticket.dart';
export 'src/models/emergency_contact.dart';
export 'src/models/payment_method.dart';
export 'src/models/transaction.dart';
export 'src/models/ride_message.dart';
export 'src/models/scheduled_ride.dart';

// Repositories
export 'src/repositories/ads_repository.dart';
export 'src/repositories/rides_repository.dart';
export 'src/repositories/driver_repository.dart';
export 'src/repositories/profile_repository.dart';
export 'src/repositories/safety_repository.dart';
export 'src/repositories/support_repository.dart';
export 'src/repositories/payments_repository.dart';

// Widgets
export 'src/widgets/status_banner.dart';

// Geo
export 'src/geo/service_area.dart';

// Utils
export 'src/utils/stream_listenable.dart';
export 'src/utils/error_messages.dart';
export 'src/utils/money.dart';
export 'src/utils/dates.dart';

// Riverpod providers (composition root)
export 'src/providers.dart';
export 'src/launch/launch_gate_provider.dart';

// DS-04 scope-trace enforcement registry
export 'src/seam_registry.dart';

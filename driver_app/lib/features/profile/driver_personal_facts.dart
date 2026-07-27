import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// The WHOLE list of things the app can honestly say it knows about a driver.
///
/// Not "the fields the Figma drew". Not "the fields a driver profile normally
/// has". These four, and nothing else, because there is **no driver
/// `GET`/`PATCH /me/profile` (#39)** and the Supabase session is the only
/// source there is.
///
/// 🔴 What the Figma draws and this class deliberately gives nowhere to live:
/// - **a driver photo** — there is no avatar endpoint and nowhere to upload to.
/// - **a city caption** — does not exist anywhere. Not in the JWT, not in the
///   session, not in DOCS/04, not in any endpoint. (The rider refused the
///   identical "Wolverhampton, Eng" caption for the identical reason.)
/// - **a star rating** — no driver-rating read exists. Inventing a figure a
///   driver's livelihood is judged on is the worst fabrication on the frame.
/// - **a trip count** — no lifetime-trips read exists.
/// - **a vehicle** — the vehicle a driver is assigned is not on the session,
///   and a profile endpoint landing tomorrow would still carry none of it
///   unless it is designed in first.
///
/// Every field is nullable because every one of them genuinely can be unknown,
/// and the screen OMITS the row rather than filling it with a placeholder. "—"
/// and "Not set" both read as *you haven't filled this in* when the truth is
/// *we can't tell you*, and asserting absence when the truth is ignorance is a
/// lie, just a polite one.
class DriverPersonalFacts {
  /// Creates the honest fact-set for one driver session.
  const DriverPersonalFacts({
    this.fullName,
    this.email,
    this.phone,
    this.memberSince,
  });

  /// `user_metadata.full_name`, set when an admin provisions the account. Null
  /// for accounts created without one — the screen then falls back to [email].
  final String? fullName;

  /// The account's own identifier. The one field a signed-in session always
  /// carries.
  final String? email;

  /// The session's phone number. Often null — the invite/password path never
  /// sets one. Null is the honest, common case and the row is OMITTED.
  final String? phone;

  /// The account creation timestamp, as the session's raw ISO-8601 string.
  /// A real fact, so it is honest to show it.
  final String? memberSince;
}

/// Derives [DriverPersonalFacts] from the live session.
///
/// Reads `phone` and `createdAt` off the Supabase `User` hanging from
/// `AuthService.currentSession` because `AuthService` exposes no getters for
/// them. Tests override this provider directly rather than fabricating a
/// Supabase `Session`.
final driverPersonalFactsProvider = Provider<DriverPersonalFacts>((ref) {
  final auth = ref.watch(authServiceProvider);
  final user = auth.currentSession?.user;
  return DriverPersonalFacts(
    fullName: auth.fullName,
    email: auth.email,
    phone: user?.phone,
    memberSince: user?.createdAt,
  );
});

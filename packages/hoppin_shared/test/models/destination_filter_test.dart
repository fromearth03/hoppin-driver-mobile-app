import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// 🔴 EVERY NUMBER ON THIS OBJECT IS THE SERVER'S. NOT ONE IS OURS.
///
/// `GET /drivers/me/destination-filter` returns `daily_uses_remaining` and
/// `expires_at` — the backend computes both, and it owns the daily cap. It can
/// change that cap tomorrow without telling us.
///
/// So the counter is `int?`, and when the server did not send a number **the
/// app has no number**. A `?? 2` here would be the invented-count defect at its
/// source: it would confidently tell a driver they have a use left in hand on
/// the very day the platform decided they do not — a driver who then plans
/// their route home around a filter the server will refuse to set.
void main() {
  group('DestinationFilter.fromJson', () {
    test('{active: false} is a FIRST-CLASS parsed state — not null, not a throw',
        () {
      // This is what EVERY driver sees before they have ever set a filter. It is
      // the common case, and it is a fact, not a failure.
      final filter = DestinationFilter.fromJson(const {'active': false});

      expect(filter.active, isFalse);
      expect(filter.lat, isNull);
      expect(filter.lng, isNull);
      expect(filter.dailyUsesRemaining, isNull);
      expect(filter.expiresAt, isNull);
    });

    test('the full active payload parses, and the counter comes from the SERVER',
        () {
      final filter = DestinationFilter.fromJson(const {
        'active': true,
        'filter': {
          'lat': 52.58,
          'lng': -2.12,
          'daily_uses_remaining': 1,
          'expires_at': '2026-07-14T19:00:00Z',
        },
      });

      expect(filter.active, isTrue);
      expect(filter.lat, 52.58);
      expect(filter.lng, -2.12);
      expect(filter.dailyUsesRemaining, 1);
      expect(filter.expiresAt, DateTime.utc(2026, 7, 14, 19));
      expect(filter.expiresAt!.isUtc, isTrue);
    });

    test(
        '🔴 counter keys ABSENT → dailyUsesRemaining is NULL. There is no '
        'default, and there must never be one', () {
      // The load-bearing test of this file. If a `?? 2` is ever added, this goes
      // red — and it SHOULD, because the alternative is an app that invents a
      // number and tells a driver a lie in the server's voice.
      final filter = DestinationFilter.fromJson(const {
        'active': true,
        'filter': {'lat': 52.58, 'lng': -2.12},
      });

      expect(filter.active, isTrue);
      expect(filter.lat, 52.58);
      expect(
        filter.dailyUsesRemaining,
        isNull,
        reason:
            'THE SERVER DID NOT SEND A COUNT, SO WE DO NOT HAVE ONE. Any '
            'default here — `?? 2` most of all — invents a number the platform '
            'never said, and the UI would then tell a driver they have a use '
            'in hand on the day the server refuses them.',
      );
      expect(
        filter.expiresAt,
        isNull,
        reason: 'same: no expiry was sent, so we know of no expiry',
      );
    });

    test('active:true with `filter` absent DEGRADES to inactive, never crashes',
        () {
      // The contract does not promise this shape. Ignorance degrades to "no
      // filter" — it never degrades to a CONFIDENT one.
      final filter = DestinationFilter.fromJson(const {'active': true});

      expect(filter.active, isFalse);
      expect(filter.lat, isNull);
      expect(filter.dailyUsesRemaining, isNull);
    });

    test('a garbage / empty body degrades to inactive', () {
      // `res.data ?? const {}` in the repository lands here.
      expect(DestinationFilter.fromJson(const {}).active, isFalse);
      expect(
        DestinationFilter.fromJson(const {'active': 'yes'}).active,
        isFalse,
        reason: 'active is read defensively — `== true`, not a blind cast',
      );
      expect(
        DestinationFilter.fromJson(
          const {'active': true, 'filter': 'nonsense'},
        ).active,
        isFalse,
        reason: 'a non-Map filter is not a filter',
      );
    });

    test('coords arriving as ints (52 not 52.0) still parse as doubles', () {
      // JSON has one number type. A whole-number latitude comes back as an int
      // and a blind `as double` would throw on it.
      final filter = DestinationFilter.fromJson(const {
        'active': true,
        'filter': {'lat': 52, 'lng': -2, 'daily_uses_remaining': 2},
      });

      expect(filter.lat, 52.0);
      expect(filter.lng, -2.0);
    });

    test('const DestinationFilter.inactive() is the same honest empty state',
        () {
      const filter = DestinationFilter.inactive();

      expect(filter.active, isFalse);
      expect(filter.dailyUsesRemaining, isNull);
      expect(filter.expiresAt, isNull);
    });
  });

  group('🔴 the source itself carries no invented count', () {
    test('destination_filter.dart contains no daily-uses default anywhere', () {
      // A SOURCE assertion, because the defect this guards is one a future
      // contributor adds in good faith: the UI wants a number, the map does not
      // always have one, and `?? 2` makes the red squiggle go away. It also
      // makes the app lie. There is no "2 per day" constant in this codebase and
      // there must never be one — the cap is the SERVER's policy.
      //
      // Comments are stripped, deliberately: this file's own doc comment says
      // "no `?? 2`" at length, and it must be allowed to. A guard that matched
      // the prose explaining the ban would go red on a correct codebase, and a
      // test that cries wolf gets deleted — leaving no guard at all.
      final raw = File('lib/src/models/destination_filter.dart')
          .readAsStringSync()
          .split('\n');

      final code = <String>[];
      var inBlock = false;
      for (var line in raw) {
        if (inBlock) {
          final end = line.indexOf('*/');
          if (end == -1) {
            code.add('');
            continue;
          }
          inBlock = false;
          line = line.substring(end + 2);
        }
        var start = line.indexOf('/*');
        while (start != -1) {
          final end = line.indexOf('*/', start + 2);
          if (end == -1) {
            inBlock = true;
            line = line.substring(0, start);
            break;
          }
          line = line.substring(0, start) + line.substring(end + 2);
          start = line.indexOf('/*');
        }
        final lineComment = line.indexOf('//');
        if (lineComment != -1) line = line.substring(0, lineComment);
        code.add(line);
      }

      final offenders = <String>[];
      // A `??` fallback ANYWHERE on the counter, and any bare assignment of a
      // literal to it. `final int? dailyUsesRemaining;` is a declaration and is
      // fine; `dailyUsesRemaining = 2` and `?? 2` are not.
      final banned = <String, RegExp>{
        '?? fallback on the counter':
            RegExp(r'daily[_a-zA-Z]*\s*\]?\s*(as[^;]*)?\?\?'),
        'a literal default for the counter':
            RegExp(r'dailyUsesRemaining\s*[:=]\s*\d'),
        'a hardcoded daily cap': RegExp(r'\b(dailyCap|maxDailyUses|usesPerDay)\b'),
      };

      for (var i = 0; i < code.length; i++) {
        for (final entry in banned.entries) {
          if (entry.value.hasMatch(code[i])) {
            offenders.add('  line ${i + 1}  [${entry.key}]  ${code[i].trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'AN INVENTED COUNT HAS APPEARED IN DestinationFilter.\n\n'
            '${offenders.join('\n')}\n\n'
            'The server computes `daily_uses_remaining`. It owns the cap and it '
            'can change the cap tomorrow. If the server did not send a number, '
            'THE APP HAS NO NUMBER — the field stays null and the UI says '
            'nothing about uses, because it knows nothing. A default here tells '
            'a driver they may still set a filter on their way home, and the '
            'server then refuses them.',
      );
    });
  });
}

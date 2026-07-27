import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Autocomplete contract acceptance: [PlaceSuggestion] round-trips the row
/// shape `GET /geocode/search` serves — `{ label, lat, lng, postcode?, source }`
/// — and stays tolerant of the fields the server documents as optional.
void main() {
  group('PlaceSuggestion', () {
    const mapJson = <String, dynamic>{
      'label': 'Molineux Stadium, Waterloo Road, Wolverhampton',
      'lat': 52.5901,
      'lng': -2.13,
      'postcode': 'WV1 4QR',
      'source': 'map',
    };

    test('round-trips the documented search row shape', () {
      final s = PlaceSuggestion.fromJson(mapJson);
      expect(s.label, 'Molineux Stadium, Waterloo Road, Wolverhampton');
      expect(s.lat, 52.5901);
      expect(s.lng, -2.13);
      expect(s.postcode, 'WV1 4QR');
      expect(s.source, 'map');
      expect(s.isSaved, isFalse);
      expect(jsonDecode(jsonEncode(s.toJson())), mapJson);
    });

    test('postcode is optional — Photon has none for every hit', () {
      final json = Map<String, dynamic>.of(mapJson)..remove('postcode');
      final s = PlaceSuggestion.fromJson(json);
      expect(s.postcode, isNull);
      // An absent postcode must not surface as the string "null" in the UI.
      expect(s.toJson().containsKey('postcode'), isFalse);
    });

    test('an empty postcode is treated as absent, not as a blank line', () {
      final json = Map<String, dynamic>.of(mapJson)..['postcode'] = '   ';
      expect(PlaceSuggestion.fromJson(json).postcode, isNull);
    });

    test('a saved place is flagged so the picker can badge it', () {
      final json = Map<String, dynamic>.of(mapJson)..['source'] = 'saved';
      expect(PlaceSuggestion.fromJson(json).isSaved, isTrue);
    });

    test('a missing source defaults to map rather than throwing', () {
      final json = Map<String, dynamic>.of(mapJson)..remove('source');
      expect(PlaceSuggestion.fromJson(json).source, 'map');
    });

    test('an unknown source is passed through, not rejected', () {
      // The server may add a source before the app ships again; an unrecognised
      // value must still render as an ordinary result.
      final json = Map<String, dynamic>.of(mapJson)..['source'] = 'airport';
      final s = PlaceSuggestion.fromJson(json);
      expect(s.source, 'airport');
      expect(s.isSaved, isFalse);
    });
  });
}

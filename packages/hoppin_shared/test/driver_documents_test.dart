import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Driver compliance-documents contract acceptance: [DriverDocument] is part
/// of the public barrel and round-trips the exact row shape both
/// `POST /drivers/me/documents` (confirm, 201) and `GET /drivers/me/documents`
/// serve — `{ id, document_type, verification_status, uploaded_at,
/// expires_at|null }` — and the repository publishes the documented
/// eight-type / three-content-type upload vocabulary.
void main() {
  group('DriverDocument', () {
    const fullJson = <String, dynamic>{
      'id': 'doc-1',
      'document_type': 'mot_certificate',
      'verification_status': 'pending_review',
      'uploaded_at': '2026-06-30T09:30:00.000',
      'expires_at': '2026-07-20T09:30:00.000',
    };

    test('round-trips the documented confirm/list row shape', () {
      final doc = DriverDocument.fromJson(fullJson);
      expect(doc.id, 'doc-1');
      expect(doc.documentType, 'mot_certificate');
      expect(doc.verificationStatus, 'pending_review');
      expect(doc.uploadedAt, DateTime(2026, 6, 30, 9, 30));
      expect(doc.expiresAt, DateTime(2026, 7, 20, 9, 30));
      expect(jsonDecode(jsonEncode(doc.toJson())), fullJson);
    });

    test('expires_at is null-tolerant — not every document expires', () {
      final json = Map<String, dynamic>.of(fullJson)..['expires_at'] = null;
      final doc = DriverDocument.fromJson(json);
      expect(doc.expiresAt, isNull);
      final reparsed = DriverDocument.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
      );
      expect(reparsed, doc);
    });
  });

  group('upload vocabulary', () {
    test('the eight documented compliance document types are published', () {
      expect(DriverRepository.documentTypes, hasLength(8));
      expect(
        DriverRepository.documentTypes,
        containsAll(const [
          'dvla_license',
          'wolverhampton_taxi_badge',
          'nr3s_background_check',
          'right_to_work',
          'mot_certificate',
          'insurance_policy',
          'v5c_logbook',
          'caz_compliance_proof',
        ]),
      );
    });

    test('the three accepted upload content types are published', () {
      expect(
        DriverRepository.documentContentTypes,
        const ['application/pdf', 'image/jpeg', 'image/png'],
      );
    });
  });
}

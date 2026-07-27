/// The backend's EIGHT `document_type` keys → the words a driver reads.
///
/// 🔴 THE KEYS ARE NOT NEGOTIABLE AND THEY ARE NOT OURS. They are
/// `DriverRepository.documentTypes`, and a key outside that list
/// `400 VALIDATION_FAILED`s ("invalid document type").
///
/// The Figma invents a `Medical Certificate` that would 400, and OMITS
/// `mot_certificate`, `v5c_logbook` and `caz_compliance_proof` — three
/// documents a Wolverhampton private-hire driver is legally required to hold.
/// **D4: TRUTH WINS OVER FIGMA COPY.**
///
/// This is the ONE place a key becomes English. It is a projection of the
/// contract, never a menu: a ninth key here is a document the backend rejects,
/// and a missing key is a legally-required document the driver never sees.
/// `document_truth_test.dart` asserts this map's keys are SET-EQUAL to
/// `DriverRepository.documentTypes` — a missing key is a RED test, not a silent
/// fallback.
const kDocumentTypeLabels = <String, String>{
  'dvla_license': 'DVLA driving licence',
  'wolverhampton_taxi_badge': 'Wolverhampton taxi badge',
  'nr3s_background_check': 'NR3S background check',
  'right_to_work': 'Right to work',
  'mot_certificate': 'MOT certificate',
  'insurance_policy': 'Insurance policy',
  'v5c_logbook': 'V5C logbook',
  'caz_compliance_proof': 'CAZ compliance proof',
};

/// The label for [type], or the raw key when we have never heard of it.
///
/// Falling back to the KEY (not to "Unknown", not to a blank) is deliberate: a
/// type the backend serves that this map does not carry is our ignorance, and
/// the driver is better served seeing the platform's own word for it than a
/// row that silently says nothing.
String documentTypeLabel(String type) => kDocumentTypeLabels[type] ?? type;

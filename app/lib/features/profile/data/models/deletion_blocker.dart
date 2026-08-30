class BlockerCopy {
  final String title;
  final String body;
  const BlockerCopy(this.title, this.body);
}

const _blockers = <String, BlockerCopy>{
  'active_trip': BlockerCopy(
    'You have a trip in progress',
    'Finish or cancel your current trip, then try again.',
  ),
  'unresolved_dispute': BlockerCopy(
    'You have an open dispute',
    'We need to close your open support ticket first.',
  ),
  'outstanding_balance': BlockerCopy(
    'You have an outstanding balance',
    'Your account balance needs settling before it can be deleted.',
  ),
  'compliance_investigation': BlockerCopy(
    'Documents are under review',
    'We are still reviewing your documents. This usually finishes within a few days.',
  ),
};

/// Copy for one `DELETION_BLOCKED` reason. An unrecognised code degrades to
/// a generic message rather than showing the driver a raw slug.
BlockerCopy blockerCopy(String code) =>
    _blockers[code] ??
    const BlockerCopy('Something is blocking deletion',
        'Please contact support and we will sort it out.');

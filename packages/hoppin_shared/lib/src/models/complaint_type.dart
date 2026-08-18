/// An admin-managed complaint type. Only active rows are returned by the API.
class ComplaintTypeOption {
  const ComplaintTypeOption({required this.code, required this.label});

  factory ComplaintTypeOption.fromJson(Map<String, dynamic> json) =>
      ComplaintTypeOption(
        code: (json['code'] as String?)?.trim() ?? '',
        label: (json['label'] as String?)?.trim() ?? '',
      );

  final String code;
  final String label;
}

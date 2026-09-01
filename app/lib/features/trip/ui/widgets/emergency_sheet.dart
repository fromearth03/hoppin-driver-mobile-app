import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/error_codes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../support/ui/support_screen.dart';
import '../../data/sos_repository.dart';

/// The red button's sheet: the fastest ways to a human, then the platform's
/// own alarm.
///
/// The numbers are the admin-maintained `GET /contacts` card — a row whose
/// number is blank simply is not offered. "Alert Hoppin" is `POST /me/sos`:
/// the ride id rides along, the server stamps it driver-triggered, and the
/// dispatcher sees it with the driver's last reported position.
class EmergencySheet extends ConsumerStatefulWidget {
  final String? rideId;

  const EmergencySheet({super.key, this.rideId});

  static Future<void> show(BuildContext context, {String? rideId}) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => EmergencySheet(rideId: rideId),
      );

  @override
  ConsumerState<EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends ConsumerState<EmergencySheet> {
  bool _sending = false;
  bool _sent = false;
  String? _error;

  Future<void> _raiseSos() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await ref
        .read(sosRepositoryProvider)
        .raise(rideId: widget.rideId);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = result.isOk;
      _error = result.isOk ? null : errorCopy(result.errorOrNull!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(platformContactsProvider).valueOrNull;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 78,
                decoration: BoxDecoration(
                  color: AppColors.textDisabled,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Emergency', style: AppText.display),
            const SizedBox(height: 4),
            const Text(
              'If you are in danger, call the emergency services first.',
              style: AppText.bodySecondary,
            ),
            const SizedBox(height: 16),
            if ((contacts?.emergencyPhone ?? '').isNotEmpty)
              _row(
                icon: Icons.local_phone,
                tint: AppColors.negative,
                title: 'Call emergency line',
                subtitle: contacts!.emergencyPhone,
                onTap: () => launchUrl(
                    Uri(scheme: 'tel', path: contacts.emergencyPhone)),
              ),
            if ((contacts?.supportPhone ?? '').isNotEmpty)
              _row(
                icon: Icons.support_agent,
                tint: AppColors.info,
                title: 'Call support',
                subtitle: contacts!.supportPhone,
                onTap: () => launchUrl(
                    Uri(scheme: 'tel', path: contacts.supportPhone)),
              ),
            if ((contacts?.whatsappNumber ?? '').isNotEmpty)
              _row(
                icon: Icons.chat,
                tint: AppColors.positive,
                title: 'WhatsApp support',
                subtitle: contacts!.whatsappNumber,
                onTap: () => launchUrl(
                  Uri.https('wa.me',
                      '/${contacts.whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '')}'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            if (_sent)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.tintMint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Alert sent. The team can see your trip and your last '
                  'reported position.',
                  style: AppText.body,
                ),
              )
            else
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _raiseSos,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.negative,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _sending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sos),
                  label: const Text('Alert Hoppin — send SOS',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: AppText.caption.copyWith(color: AppColors.negative)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required Color tint,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration:
                        BoxDecoration(color: tint, shape: BoxShape.circle),
                    child: Icon(icon, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: AppText.heading.copyWith(fontSize: 16)),
                        Text(subtitle, style: AppText.caption),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      );
}

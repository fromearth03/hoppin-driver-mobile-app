import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// Registration3 — **Vehicle** (seam #82, now live).
///
/// Collects the driver's vehicle (reg / make / model / colour) + insurance
/// (provider + expiry) and upserts it via `POST /drivers/me/vehicle` on Continue.
/// Riders see the make/model/plate on the trip screen. A plate already on another
/// driver's account comes back as PLATE_TAKEN and is shown inline; the step only
/// advances after a successful save.
class VehicleStep extends ConsumerStatefulWidget {
  const VehicleStep({
    required this.onBack,
    required this.onContinue,
    this.onContactSupport,
    super.key,
  });

  final VoidCallback onBack;

  /// Advance to the attachments step — called only AFTER a successful save.
  final VoidCallback onContinue;

  /// Retained for API compatibility; the live form no longer shows a support rung.
  final VoidCallback? onContactSupport;

  @override
  ConsumerState<VehicleStep> createState() => _VehicleStepState();
}

class _VehicleStepState extends ConsumerState<VehicleStep> {
  final _formKey = GlobalKey<FormState>();
  final _reg = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _colour = TextEditingController();
  final _insurer = TextEditingController();
  final _expiry = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reg.dispose();
    _make.dispose();
    _model.dispose();
    _colour.dispose();
    _insurer.dispose();
    _expiry.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: DateTime(now.year + 6),
    );
    if (picked != null) {
      _expiry.text = picked.toIso8601String().split('T').first;
      setState(() {});
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(driverRepositoryProvider).registerVehicle(
            make: _make.text.trim(),
            model: _model.text.trim(),
            licensePlate: _reg.text.trim(),
            color: _colour.text.trim(),
            insuranceProvider: _insurer.text.trim(),
            insuranceExpiry: _expiry.text.trim(),
          );
      if (mounted) widget.onContinue();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.code == 'PLATE_TAKEN'
            ? 'That registration is already on another driver account.'
            : 'Could not save your vehicle. Check the details and try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your vehicle. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your vehicle', style: hoppin.type.title),
          SizedBox(height: hoppin.spacing.xs),
          Text(
            'The car you drive for Hoppin. Riders see the make, model and plate.',
            style: hoppin.type.metaSmall.copyWith(color: colors.textMid),
          ),
          SizedBox(height: hoppin.spacing.lg),
          if (_error != null) ...[
            HopBanner.error(message: _error!),
            SizedBox(height: hoppin.spacing.md),
          ],
          _field(_reg, 'Registration', 'WH12 ABC', required: true, caps: true),
          SizedBox(height: hoppin.spacing.md),
          Row(children: [
            Expanded(child: _field(_make, 'Make', 'Toyota', required: true)),
            SizedBox(width: hoppin.spacing.lg),
            Expanded(child: _field(_model, 'Model', 'Prius', required: true)),
          ]),
          SizedBox(height: hoppin.spacing.md),
          _field(_colour, 'Colour', 'Silver'),
          SizedBox(height: hoppin.spacing.md),
          _field(_insurer, 'Insurance provider', 'Provider & policy no.'),
          SizedBox(height: hoppin.spacing.md),
          TextFormField(
            controller: _expiry,
            readOnly: true,
            enabled: !_busy,
            onTap: _busy ? null : _pickExpiry,
            decoration: const InputDecoration(
              labelText: 'Insurance expiry',
              hintText: 'Tap to pick a date',
              prefixIcon: Icon(Icons.event_outlined),
            ),
          ),
          SizedBox(height: hoppin.spacing.xl),
          Row(children: [
            Expanded(
              child: HopButton.secondary(
                label: 'Back',
                onPressed: _busy ? null : widget.onBack,
              ),
            ),
            SizedBox(width: hoppin.spacing.lg),
            Expanded(
              child: HopButton.primary(
                label: 'Save & continue',
                onPressed: _busy ? null : _submit,
                busy: _busy,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    String hint, {
    bool required = false,
    bool caps = false,
  }) {
    return TextFormField(
      controller: c,
      enabled: !_busy,
      textCapitalization:
          caps ? TextCapitalization.characters : TextCapitalization.words,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

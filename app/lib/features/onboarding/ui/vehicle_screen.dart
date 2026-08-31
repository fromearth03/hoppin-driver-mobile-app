import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/onboarding_repository.dart';
import '../logic/onboarding_controller.dart';
import 'widgets/expiry_field.dart';
import 'widgets/wizard_scaffold.dart';

/// Step 3 of 4: the vehicle and the two dates it is approved against.
///
/// The design shows three boxes — Registration, Model, Type — each with its
/// label stacked above, which is the shape [AppTextField] already draws. The
/// service takes make, model, plate, colour, year and seat count, and reads
/// MOT and insurance expiry off the vehicle for its compliance sweep.
/// Dropping the rest to match the mock would leave a vehicle that can never
/// be approved, so the design's rhythm is kept and the fields the service
/// needs are carried in it.
class VehicleScreen extends ConsumerStatefulWidget {
  const VehicleScreen({super.key});

  @override
  ConsumerState<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends ConsumerState<VehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _plate = TextEditingController();
  final _color = TextEditingController();
  final _year = TextEditingController();
  final _seats = TextEditingController(text: '4');
  final _insurer = TextEditingController();
  DateTime? _insuranceExpiry;
  DateTime? _motExpiry;
  bool _caz = false;
  bool _busy = false;
  String? _error;

  /// The design spaces its stacked fields well apart; 22 is that gap.
  static const _gap = SizedBox(height: 22);

  @override
  void dispose() {
    for (final c in [_make, _model, _plate, _color, _year, _seats, _insurer]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    // The compliance sweep reads these two dates, so a vehicle saved without
    // them can never become compliant. Better to stop here than to leave the
    // driver waiting on an approval that cannot come.
    if (_insuranceExpiry == null || _motExpiry == null) {
      setState(() => _error =
          'Add both the MOT and insurance expiry dates - your vehicle cannot '
          'be approved without them.');
      return;
    }

    setState(() => _busy = true);
    final result = await ref.read(onboardingRepositoryProvider).saveVehicle(
          make: _make.text,
          model: _model.text,
          licensePlate: _plate.text,
          color: _color.text,
          year: int.parse(_year.text.trim()),
          passengerCapacity: int.parse(_seats.text.trim()),
          insuranceProvider: _insurer.text,
          insuranceExpiry: _insuranceExpiry,
          motExpiry: _motExpiry,
          cazCompliant: _caz,
        );
    if (!mounted) return;

    result.when(
      ok: (_) {
        ref.read(onboardingControllerProvider.notifier).refresh();
        context.pop();
      },
      err: (e) => setState(() => _error = e.code == 'PLATE_TAKEN'
          ? 'That registration is already on another account.'
          : errorCopy(e)),
    );
    if (mounted) setState(() => _busy = false);
  }

  String? _requiredField(String? v, String what) =>
      (v == null || v.trim().isEmpty) ? 'Enter $what' : null;

  @override
  Widget build(BuildContext context) => WizardScaffold(
        title: 'Vehicle Registration',
        step: 3,
        onBack: _busy ? null : () => context.pop(),
        actions: WizardActions(
          busy: _busy,
          onBack: _busy ? null : () => context.pop(),
          onContinue: _busy ? null : _submit,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                key: const Key('plate'),
                label: 'Vehicle Registration',
                controller: _plate,
                enabled: !_busy,
                hint: 'e.g. AB-123',
                textCapitalization: TextCapitalization.characters,
                validator: (v) => _requiredField(v, 'the registration'),
              ),
              _gap,
              AppTextField(
                key: const Key('make'),
                label: 'Vehicle Make',
                controller: _make,
                enabled: !_busy,
                hint: 'e.g. Honda',
                textCapitalization: TextCapitalization.words,
                validator: (v) => _requiredField(v, 'the make'),
              ),
              _gap,
              AppTextField(
                key: const Key('model'),
                label: 'Vehicle Model',
                controller: _model,
                enabled: !_busy,
                hint: 'e.g. Civic',
                textCapitalization: TextCapitalization.words,
                validator: (v) => _requiredField(v, 'the model'),
              ),
              _gap,
              // The design's third box is "Vehicle Type", placeholder
              // "Standard". The vehicle payload has no such field — make,
              // model, plate, colour, year, capacity and the compliance dates
              // are the whole of it — so the slot carries colour, which the
              // service does store and an admin does check.
              AppTextField(
                key: const Key('color'),
                label: 'Vehicle Colour',
                controller: _color,
                enabled: !_busy,
                hint: 'e.g. Silver',
                textCapitalization: TextCapitalization.words,
                validator: (v) => _requiredField(v, 'the colour'),
              ),
              _gap,
              AppTextField(
                key: const Key('year'),
                label: 'Year',
                controller: _year,
                enabled: !_busy,
                hint: 'e.g. 2019',
                keyboardType: TextInputType.number,
                validator: (v) {
                  final year = int.tryParse(v?.trim() ?? '');
                  if (year == null) return 'Enter the year';
                  if (year < 1990 || year > DateTime.now().year + 1) {
                    return 'Enter a valid year';
                  }
                  return null;
                },
              ),
              _gap,
              AppTextField(
                key: const Key('seats'),
                label: 'Passenger Seats',
                controller: _seats,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final seats = int.tryParse(v?.trim() ?? '');
                  if (seats == null || seats < 1) {
                    return 'Enter the number of passenger seats';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              const Text('Compliance', style: AppText.title),
              const SizedBox(height: 6),
              const Text(
                'These are what an admin checks before approving you.',
                style: AppText.bodySecondary,
              ),
              const SizedBox(height: 22),
              AppTextField(
                key: const Key('insurer'),
                label: 'Insurance Provider',
                controller: _insurer,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                validator: (v) => _requiredField(v, 'your insurer'),
              ),
              _gap,
              ExpiryField(
                key: const Key('insurance_expiry'),
                label: 'Insurance expiry',
                value: _insuranceExpiry,
                enabled: !_busy,
                onChanged: (d) => setState(() => _insuranceExpiry = d),
              ),
              _gap,
              ExpiryField(
                key: const Key('mot_expiry'),
                label: 'MOT expiry',
                value: _motExpiry,
                enabled: !_busy,
                onChanged: (d) => setState(() => _motExpiry = d),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title:
                    const Text('Clean Air Zone compliant', style: AppText.body),
                value: _caz,
                onChanged: _busy ? null : (v) => setState(() => _caz = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style: AppText.body.copyWith(color: AppColors.negative)),
              ],
            ],
          ),
        ),
      );
}

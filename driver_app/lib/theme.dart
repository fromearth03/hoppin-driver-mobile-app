import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// Driver lane themes — petrol navy on warm paper / warm near-black,
/// hand-tuned in hoppin_ui. Drop-in rewire: the exported names are stable so
/// every entrypoint through app.dart boots branded.
final ThemeData hoppinDriverLightTheme = HoppinTheme.driverLight();

/// Driver dark — lifted petrol on the warm near-black canvas (the show
/// theme).
final ThemeData hoppinDriverDarkTheme = HoppinTheme.driverDark();

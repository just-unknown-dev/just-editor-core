import 'dart:math' as math;
import 'package:meta/meta.dart';

import '../../look/widgets/scrubbable_number_field.dart';

/// A number typed into a field, or null for anything else — and for what
/// is not a finite number (`NaN`, `Infinity`, `1e999`), which no scene file
/// can hold, so a component holding one could not be saved. With [config],
/// kept within its `min` and `max`, and whole when it is an integer.
@internal
double? parseTypedNumber(String text, {NumberScrubConfig? config}) {
  final v = double.tryParse(text.trim());
  if (v == null || !v.isFinite) return null;
  var out = v;
  if (config != null) {
    if (config.min case final min?) out = math.max(out, min);
    if (config.max case final max?) out = math.min(out, max);
    if (config.integer) out = out.roundToDouble();
  }
  return out;
}

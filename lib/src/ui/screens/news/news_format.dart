import 'package:flutter/material.dart';

const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// «dom 30 nov 2026 · 08:00».
String formatNewsDate(DateTime t) =>
    '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]} ${t.year} · '
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// «30 nov».
String formatShortDate(DateTime t) => '${t.day} ${_months[t.month - 1]}';

/// Días de calendario desde [now] hasta [at] (negativo si ya pasó).
int daysUntil(DateTime at, DateTime now) =>
    DateUtils.dateOnly(at).difference(DateUtils.dateOnly(now)).inDays;

/// Elige fecha y luego hora; null si se cancela la fecha.
Future<DateTime?> pickDateTime(
  BuildContext context, {
  required DateTime initial,
  int defaultHour = 9,
}) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 3),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  return DateTime(
    date.year,
    date.month,
    date.day,
    time?.hour ?? defaultHour,
    time?.minute ?? 0,
  );
}

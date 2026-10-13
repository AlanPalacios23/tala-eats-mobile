// Formateadores de presentación (es-MX) sin dependencias externas.

/// `$1,284.50` — pesos mexicanos con separador de miles.
String money(num value, {bool cents = true}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(cents ? 2 : 0);
  final parts = fixed.split('.');
  final whole = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  final decimals = parts.length > 1 ? '.${parts[1]}' : '';
  return '${negative ? '-' : ''}\$$buffer$decimals';
}

/// Montos compactos para ejes de gráficas: `$1.2k`.
String moneyCompact(num value) {
  if (value.abs() >= 1000) {
    final k = value / 1000;
    final text = k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(1);
    return '\$${text.replaceAll('.0', '')}k';
  }
  return '\$${value.toStringAsFixed(0)}';
}

const List<String> _weekdays = <String>[
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const List<String> _weekdaysShort = <String>[
  'Lun',
  'Mar',
  'Mié',
  'Jue',
  'Vie',
  'Sáb',
  'Dom',
];

const List<String> _months = <String>[
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// "Viernes 9 de octubre"
String longDate(DateTime date) =>
    '${_capitalize(_weekdays[date.weekday - 1])} ${date.day} de ${_months[date.month - 1]}';

/// "Vie"
String shortWeekday(DateTime date) => _weekdaysShort[date.weekday - 1];

/// "9 oct"
String shortDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1].substring(0, 3)}';

/// "14:05"
String clockTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

/// Minutos transcurridos desde [since], nunca negativos.
int minutesSince(DateTime since, [DateTime? now]) {
  final diff = (now ?? DateTime.now()).difference(since).inMinutes;
  return diff < 0 ? 0 : diff;
}

/// "Ahora", "4 min", "1 h 12 min"
String elapsedLabel(int minutes) {
  if (minutes < 1) return 'Ahora';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// "hace 4 min" para listas.
String agoLabel(DateTime since, [DateTime? now]) {
  final minutes = minutesSince(since, now);
  if (minutes < 1) return 'Hace un momento';
  return 'Hace ${elapsedLabel(minutes)}';
}

String plural(int count, String singular, String pluralForm) =>
    '$count ${count == 1 ? singular : pluralForm}';

/// Saludo según la hora local.
String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 12) return 'Buenos días';
  if (h < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

/// Convierte "12,50" / "12.50" / "$ 12.50" a double.
double? parseMoney(String raw) {
  final clean = raw.replaceAll(RegExp(r'[^0-9,\.]'), '').replaceAll(',', '.');
  if (clean.isEmpty) return null;
  final firstDot = clean.indexOf('.');
  final normalized = firstDot < 0
      ? clean
      : clean.substring(0, firstDot + 1) +
          clean.substring(firstDot + 1).replaceAll('.', '');
  return double.tryParse(normalized);
}

/// Iniciales para avatar: "Tacos El Centro" → "TE".
String initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'T';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
}

const weekdays = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
const ordinals = {
  1: 'premier',
  2: 'deuxième',
  3: 'troisième',
  4: 'quatrième',
  -1: 'dernier',
};

class RecurrenceRule {
  const RecurrenceRule({
    this.unit = 'daily',
    this.interval = 1,
    this.days = const [1],
    this.monthDay = 1,
    this.ordinal = 1,
    this.weekday = 6,
    this.monthMode = 'date',
  });
  final String unit;
  final int interval;
  final List<int> days;
  final int monthDay;
  final int ordinal;
  final int weekday;
  final String monthMode;

  Map<String, dynamic> toJson() => {
    'unit': unit,
    'interval': interval,
    'days': days,
    'monthDay': monthDay,
    'ordinal': ordinal,
    'weekday': weekday,
    'monthMode': monthMode,
  };
  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    final rule = RecurrenceRule(
      unit: json['unit'] as String,
      interval: json['interval'] as int,
      days: (json['days'] as List).cast<int>(),
      monthDay: json['monthDay'] as int,
      ordinal: json['ordinal'] as int,
      weekday: json['weekday'] as int,
      monthMode: json['monthMode'] as String,
    );
    if (!['daily', 'weekly', 'monthly'].contains(rule.unit) ||
        rule.interval < 1 ||
        rule.interval > 999 ||
        rule.days.isEmpty ||
        rule.days.any((d) => d < 1 || d > 7) ||
        rule.monthDay < 1 ||
        rule.monthDay > 31 ||
        !ordinals.containsKey(rule.ordinal) ||
        rule.weekday < 1 ||
        rule.weekday > 7 ||
        !['date', 'ordinal'].contains(rule.monthMode)) {
      throw const FormatException('Répétition personnalisée invalide');
    }
    return rule;
  }

  String get label {
    if (unit == 'daily') {
      return interval == 1 ? 'Tous les jours' : 'Tous les $interval jours';
    }
    if (unit == 'weekly') {
      final ordered = days.toSet().toList()..sort();
      return '${interval == 1 ? 'Chaque semaine' : 'Toutes les $interval semaines'} : ${ordered.map((d) => weekdays[d - 1]).join(', ')}';
    }
    final when = monthMode == 'date'
        ? 'le $monthDay'
        : 'le ${ordinals[ordinal]} ${weekdays[weekday - 1]}';
    return '${interval == 1 ? 'Chaque mois' : 'Tous les $interval mois'}, $when';
  }

  // Calendar arithmetic preserves local clock time across DST boundaries.
  // The first deadline anchors active weeks/months. End-of-month dates clamp
  // without changing the configured day (31 Jan -> 28 Feb -> 31 Mar).
  DateTime next(DateTime date, {bool inclusive = false}) {
    DateTime at(int year, int month, int day) => DateTime(
      year,
      month,
      day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
    if (unit == 'daily') {
      return inclusive ? date : at(date.year, date.month, date.day + interval);
    }
    if (unit == 'weekly') {
      final ordered = days.toSet().toList()..sort();
      for (final day in ordered) {
        if (day > date.weekday || (inclusive && day == date.weekday)) {
          return at(date.year, date.month, date.day + day - date.weekday);
        }
      }
      return at(
        date.year,
        date.month,
        date.day - date.weekday + interval * 7 + ordered.first,
      );
    }
    DateTime inMonth(int offset) {
      final first = DateTime(date.year, date.month + offset, 1);
      final last = DateTime(first.year, first.month + 1, 0);
      int day;
      if (monthMode == 'date') {
        day = monthDay > last.day ? last.day : monthDay;
      } else if (ordinal == -1) {
        day = last.day - (last.weekday - weekday + 7) % 7;
      } else {
        day = 1 + (weekday - first.weekday + 7) % 7 + (ordinal - 1) * 7;
      }
      return at(first.year, first.month, day);
    }

    final current = inMonth(0);
    if (current.isAfter(date) || (inclusive && current == date)) return current;
    return inMonth(interval);
  }
}

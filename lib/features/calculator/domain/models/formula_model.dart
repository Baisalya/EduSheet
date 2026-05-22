enum ScienceSubject { physics, chemistry }

class Formula {
  final String name;
  final String expression;
  final String category;
  final ScienceSubject subject;
  final String description;

  const Formula({
    required this.name,
    required this.expression,
    required this.category,
    required this.subject,
    this.description = '',
  });
}

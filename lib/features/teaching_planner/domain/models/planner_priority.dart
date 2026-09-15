enum PlannerPriority { low, normal, high }

PlannerPriority plannerPriorityFromJson(Object? value) {
  final name = value?.toString();
  for (final priority in PlannerPriority.values) {
    if (priority.name == name) return priority;
  }
  return PlannerPriority.normal;
}

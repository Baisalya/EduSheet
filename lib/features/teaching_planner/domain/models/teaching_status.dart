enum TeachingProgressStatus {
  planned,
  inProgress,
  completed,
  skipped,
  rescheduled,
}

TeachingProgressStatus teachingProgressStatusFromJson(Object? value) {
  final name = value?.toString();
  for (final status in TeachingProgressStatus.values) {
    if (status.name == name) return status;
  }
  return TeachingProgressStatus.planned;
}

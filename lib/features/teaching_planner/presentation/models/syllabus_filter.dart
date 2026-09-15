enum SyllabusFilter { all, incomplete, completed, highPriority, unplanned }

extension SyllabusFilterLabel on SyllabusFilter {
  String get label => switch (this) {
    SyllabusFilter.all => 'All',
    SyllabusFilter.incomplete => 'Incomplete',
    SyllabusFilter.completed => 'Completed',
    SyllabusFilter.highPriority => 'High priority',
    SyllabusFilter.unplanned => 'No periods',
  };
}

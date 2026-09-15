enum TeachingPlannerAccessLevel { free, pro, complimentaryPro }

enum TeachingPlannerCapability {
  corePlanning,
  syllabusManagement,
  progressTracking,
  advancedScheduling,
  advancedDashboards,
  bulkOperations,
  richExportAndBackup,
}

class TeachingPlannerCapabilities {
  final TeachingPlannerAccessLevel accessLevel;
  final Set<TeachingPlannerCapability> enabled;

  const TeachingPlannerCapabilities({
    required this.accessLevel,
    required this.enabled,
  });

  bool allows(TeachingPlannerCapability capability) =>
      enabled.contains(capability);

  bool get hasProConvenience =>
      accessLevel == TeachingPlannerAccessLevel.pro ||
      accessLevel == TeachingPlannerAccessLevel.complimentaryPro;

  static const Set<TeachingPlannerCapability> _core = {
    TeachingPlannerCapability.corePlanning,
    TeachingPlannerCapability.syllabusManagement,
    TeachingPlannerCapability.progressTracking,
  };

  static const Set<TeachingPlannerCapability> _advanced = {
    ..._core,
    TeachingPlannerCapability.advancedScheduling,
    TeachingPlannerCapability.advancedDashboards,
    TeachingPlannerCapability.bulkOperations,
    TeachingPlannerCapability.richExportAndBackup,
  };

  factory TeachingPlannerCapabilities.free() =>
      const TeachingPlannerCapabilities(
        accessLevel: TeachingPlannerAccessLevel.free,
        enabled: _core,
      );

  factory TeachingPlannerCapabilities.pro() =>
      const TeachingPlannerCapabilities(
        accessLevel: TeachingPlannerAccessLevel.pro,
        enabled: _advanced,
      );

  factory TeachingPlannerCapabilities.complimentaryPro() =>
      const TeachingPlannerCapabilities(
        accessLevel: TeachingPlannerAccessLevel.complimentaryPro,
        enabled: _advanced,
      );
}

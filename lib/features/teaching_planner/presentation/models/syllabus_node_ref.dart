enum SyllabusNodeKind { classValue, subject, unit, chapter, topic }

class SyllabusNodeRef {
  final SyllabusNodeKind kind;
  final String id;
  final String classId;
  final String? subjectId;
  final String? unitId;
  final String? chapterId;

  const SyllabusNodeRef._({
    required this.kind,
    required this.id,
    required this.classId,
    this.subjectId,
    this.unitId,
    this.chapterId,
  });

  const SyllabusNodeRef.classValue(String classId)
    : this._(kind: SyllabusNodeKind.classValue, id: classId, classId: classId);

  const SyllabusNodeRef.subject({
    required String classId,
    required String subjectId,
  }) : this._(
         kind: SyllabusNodeKind.subject,
         id: subjectId,
         classId: classId,
         subjectId: subjectId,
       );

  const SyllabusNodeRef.unit({
    required String classId,
    required String subjectId,
    required String unitId,
  }) : this._(
         kind: SyllabusNodeKind.unit,
         id: unitId,
         classId: classId,
         subjectId: subjectId,
         unitId: unitId,
       );

  const SyllabusNodeRef.chapter({
    required String classId,
    required String subjectId,
    required String chapterId,
    String? unitId,
  }) : this._(
         kind: SyllabusNodeKind.chapter,
         id: chapterId,
         classId: classId,
         subjectId: subjectId,
         unitId: unitId,
         chapterId: chapterId,
       );

  const SyllabusNodeRef.topic({
    required String classId,
    required String subjectId,
    required String chapterId,
    required String topicId,
    String? unitId,
  }) : this._(
         kind: SyllabusNodeKind.topic,
         id: topicId,
         classId: classId,
         subjectId: subjectId,
         unitId: unitId,
         chapterId: chapterId,
       );

  bool contains(SyllabusNodeRef other) {
    if (classId != other.classId) return false;
    if (kind == SyllabusNodeKind.classValue) return true;
    if (subjectId != other.subjectId) return false;
    if (kind == SyllabusNodeKind.subject) return true;
    if (kind == SyllabusNodeKind.unit) {
      return unitId != null && unitId == other.unitId;
    }
    if (chapterId != other.chapterId) return false;
    if (kind == SyllabusNodeKind.chapter) return true;
    return id == other.id;
  }

  @override
  bool operator ==(Object other) {
    return other is SyllabusNodeRef &&
        other.kind == kind &&
        other.id == id &&
        other.classId == classId &&
        other.subjectId == subjectId &&
        other.unitId == unitId &&
        other.chapterId == chapterId;
  }

  @override
  int get hashCode =>
      Object.hash(kind, id, classId, subjectId, unitId, chapterId);
}

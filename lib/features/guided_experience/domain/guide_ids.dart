import 'package:flutter/foundation.dart';

@immutable
class GuideId {
  const GuideId(this.value) : assert(value != '');

  final String value;

  static const createPaper = GuideId('create_paper');
  static const createSyllabus = GuideId('create_syllabus');

  @override
  bool operator ==(Object other) => other is GuideId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

@immutable
class GuideStepId {
  const GuideStepId(this.value) : assert(value != '');

  final String value;

  @override
  bool operator ==(Object other) =>
      other is GuideStepId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

@immutable
class GuideTargetId {
  const GuideTargetId(this.value) : assert(value != '');

  final String value;

  @override
  bool operator ==(Object other) =>
      other is GuideTargetId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

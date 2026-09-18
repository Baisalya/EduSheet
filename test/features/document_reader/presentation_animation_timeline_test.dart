import 'package:edusheet/features/document_reader/domain/models/presentation_animation_timeline.dart';
import 'package:edusheet/features/document_reader/domain/models/presentation_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compiles click, with-previous and after-previous into one cue', () {
    final timeline = PresentationAnimationTimeline.compile(const [
      PresentationAnimationStep(
        targetObjectId: '2',
        kind: PresentationAnimationKind.fadeIn,
        trigger: PresentationAnimationTrigger.onClick,
        duration: Duration(milliseconds: 500),
      ),
      PresentationAnimationStep(
        targetObjectId: '3',
        kind: PresentationAnimationKind.flyIn,
        trigger: PresentationAnimationTrigger.withPrevious,
        delay: Duration(milliseconds: 100),
        duration: Duration(milliseconds: 300),
      ),
      PresentationAnimationStep(
        targetObjectId: '2',
        kind: PresentationAnimationKind.wipeOut,
        trigger: PresentationAnimationTrigger.afterPrevious,
        delay: Duration(milliseconds: 50),
        duration: Duration(milliseconds: 200),
      ),
      PresentationAnimationStep(
        targetObjectId: '4',
        kind: PresentationAnimationKind.appear,
        trigger: PresentationAnimationTrigger.onClick,
        duration: Duration(milliseconds: 1),
      ),
    ]);

    expect(timeline.groups, hasLength(2));
    final first = timeline.groups.first;
    expect(first.requiresClick, isTrue);
    expect(first.animations, hasLength(3));
    expect(first.animations[0].start.inMilliseconds, 0);
    expect(first.animations[0].end.inMilliseconds, 500);
    expect(first.animations[1].start.inMilliseconds, 100);
    expect(first.animations[1].end.inMilliseconds, 400);
    expect(first.animations[2].start.inMilliseconds, 450);
    expect(first.animations[2].end.inMilliseconds, 650);
    expect(first.duration.inMilliseconds, 650);
    expect(timeline.groups[1].requiresClick, isTrue);
  });

  test('first with-previous sequence starts automatically', () {
    final timeline = PresentationAnimationTimeline.compile(const [
      PresentationAnimationStep(
        targetObjectId: '2',
        kind: PresentationAnimationKind.fadeIn,
        trigger: PresentationAnimationTrigger.withPrevious,
      ),
      PresentationAnimationStep(
        targetObjectId: '3',
        kind: PresentationAnimationKind.pulse,
        trigger: PresentationAnimationTrigger.afterPrevious,
      ),
    ]);

    expect(timeline.groups, hasLength(1));
    expect(timeline.groups.single.requiresClick, isFalse);
  });
  test('unsupported Office effects do not create empty presentation clicks', () {
    final timeline = PresentationAnimationTimeline.compile(const [
      PresentationAnimationStep(
        targetObjectId: '2',
        kind: PresentationAnimationKind.unsupported,
        trigger: PresentationAnimationTrigger.onClick,
        supported: false,
        sourceEffect: 'animClr',
      ),
      PresentationAnimationStep(
        targetObjectId: '3',
        kind: PresentationAnimationKind.fadeIn,
        trigger: PresentationAnimationTrigger.onClick,
      ),
    ]);

    expect(timeline.unsupportedStepCount, 1);
    expect(timeline.playableStepCount, 1);
    expect(timeline.groups, hasLength(1));
    expect(timeline.groups.single.animations.single.step.targetObjectId, '3');
  });

}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/presentation/providers/editor_provider.dart';
import '../../editor/presentation/screens/create_paper_screen.dart';
import '../../teaching_planner/presentation/providers/teaching_planner_provider.dart';
import '../../teaching_planner/presentation/screens/teaching_planner_screen.dart';
import '../application/guided_experience_providers.dart';
import '../domain/guide_session.dart';
import '../guides/create_paper_guide.dart';
import '../guides/create_syllabus_guide.dart';
import 'demo_mode_banner.dart';
import 'guided_demo_controller.dart';
import 'guided_demo_providers.dart';
import 'guided_demo_session.dart';

class GuidedDemoScreen extends ConsumerStatefulWidget {
  const GuidedDemoScreen({
    super.key,
    required this.feature,
  });

  final GuidedDemoFeature feature;

  @override
  ConsumerState<GuidedDemoScreen> createState() => _GuidedDemoScreenState();
}

class _GuidedDemoScreenState extends ConsumerState<GuidedDemoScreen> {
  EditorSessionSnapshot? _paperSnapshot;
  bool _exiting = false;
  bool _ready = false;
  String? _prepareError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_prepareAndEnterDemo());
    });
  }

  Future<void> _prepareAndEnterDemo() async {
    try {
      switch (widget.feature) {
        case GuidedDemoFeature.createPaper:
          final demoRepository = ref.read(demoPaperRepositoryProvider);
          demoRepository.reset();
          final editor = ref.read(editorStateProvider.notifier);
          final snapshot = await editor.enterDemoIsolation(demoRepository);
          _paperSnapshot = snapshot;
          if (!mounted) {
            await editor.exitDemoIsolation(
              snapshot,
              ref.read(productionPaperRepositoryProvider),
            );
            return;
          }
          ref
              .read(guidedDemoControllerProvider.notifier)
              .start(GuidedDemoFeature.createPaper);
          ref.invalidate(savedPapersProvider);
          break;
        case GuidedDemoFeature.createSyllabus:
          ref.read(demoTeachingPlannerRepositoryProvider).reset();
          ref
              .read(guidedDemoControllerProvider.notifier)
              .start(GuidedDemoFeature.createSyllabus);
          ref.invalidate(teachingPlannerRepositoryProvider);
          ref.invalidate(teachingPlannerServiceProvider);
          ref.invalidate(teachingPlannerProvider);
          break;
      }

      if (!mounted) return;
      setState(() => _ready = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_startDemoGuide());
      });
    } catch (_) {
      final snapshot = _paperSnapshot;
      if (widget.feature == GuidedDemoFeature.createPaper && snapshot != null) {
        await ref.read(editorStateProvider.notifier).exitDemoIsolation(
              snapshot,
              ref.read(productionPaperRepositoryProvider),
            );
        _paperSnapshot = null;
      }
      ref.read(guidedDemoControllerProvider.notifier).stop();
      if (!mounted) return;
      setState(() {
        _prepareError =
            'EduSheet could not prepare isolated Demo Mode safely. Your real data was left unchanged.';
      });
    }
  }

  Future<void> _startDemoGuide() async {
    final controller = ref.read(guidedExperienceControllerProvider.notifier);
    switch (widget.feature) {
      case GuidedDemoFeature.createPaper:
        await controller.startGuide(
          createPaperGuideDefinition,
          mode: GuideSessionMode.demo,
          restart: true,
          startAtStepId: CreatePaperGuideSteps.openPaperSetup,
        );
        break;
      case GuidedDemoFeature.createSyllabus:
        await controller.startGuide(
          createSyllabusGuideDefinition,
          mode: GuideSessionMode.demo,
          restart: true,
          startAtStepId: CreateSyllabusGuideSteps.openClassSetup,
        );
        break;
    }
  }

  Future<void> _handleBackRequest() async {
    if (_exiting) return;
    final guide = ref.read(guidedExperienceControllerProvider);
    if (guide.activeSession?.mode == GuideSessionMode.demo) {
      await ref.read(guidedExperienceControllerProvider.notifier).stop();
      return;
    }
    await _exitDemo();
  }

  Future<void> _exitDemo() async {
    if (_exiting) return;
    _exiting = true;

    final guided = ref.read(guidedExperienceControllerProvider);
    if (guided.activeSession?.mode == GuideSessionMode.demo) {
      await ref.read(guidedExperienceControllerProvider.notifier).stop();
    }

    ref.read(guidedDemoControllerProvider.notifier).stop();

    switch (widget.feature) {
      case GuidedDemoFeature.createPaper:
        final snapshot = _paperSnapshot;
        if (snapshot != null) {
          await ref.read(editorStateProvider.notifier).exitDemoIsolation(
                snapshot,
                ref.read(productionPaperRepositoryProvider),
              );
        }
        ref.invalidate(savedPapersProvider);
        break;
      case GuidedDemoFeature.createSyllabus:
        ref.invalidate(teachingPlannerRepositoryProvider);
        ref.invalidate(teachingPlannerServiceProvider);
        ref.invalidate(teachingPlannerProvider);
        break;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return PopScope<void>(
        canPop: !_exiting,
        child: Scaffold(
          appBar: AppBar(title: const Text('Safe Demo')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _prepareError == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Preparing an isolated demo…'),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 36),
                        const SizedBox(height: 12),
                        Text(
                          _prepareError!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    final label = switch (widget.feature) {
      GuidedDemoFeature.createPaper => 'Create Paper',
      GuidedDemoFeature.createSyllabus => 'Create Syllabus',
    };
    final content = switch (widget.feature) {
      GuidedDemoFeature.createPaper => const CreatePaperScreen(),
      GuidedDemoFeature.createSyllabus => const TeachingPlannerScreen(),
    };

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBackRequest());
      },
      child: Material(
        child: Column(
          children: [
            DemoModeBanner(
              label: label,
              onExit: () => unawaited(_exitDemo()),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/content_template_repository.dart';
import '../../domain/models/content_template.dart';

final contentTemplateRepositoryProvider = Provider<ContentTemplateRepository>(
  (ref) => LocalContentTemplateRepository(),
);

final questionTemplatesProvider = FutureProvider.autoDispose<List<QuestionTemplate>>(
  (ref) => ref.watch(contentTemplateRepositoryProvider).getQuestionTemplates(),
);

final sectionTemplatesProvider = FutureProvider.autoDispose<List<SectionTemplate>>(
  (ref) => ref.watch(contentTemplateRepositoryProvider).getSectionTemplates(),
);

final paperBlueprintsProvider = FutureProvider.autoDispose<List<PaperBlueprint>>(
  (ref) => ref.watch(contentTemplateRepositoryProvider).getPaperBlueprints(),
);

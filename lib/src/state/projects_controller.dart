import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/project.dart';

final projectsControllerProvider =
    StateNotifierProvider<ProjectsController, List<Project>>((ref) {
      return ProjectsController();
    });

class ProjectsController extends StateNotifier<List<Project>> {
  ProjectsController()
    : super([
        Project(
          id: const Uuid().v4(),
          name: 'Vibe Coder Prototype',
          description:
              'A sample project with an agent chat + workspace layout.',
          updatedAt: DateTime.now(),
        ),
        Project(
          id: const Uuid().v4(),
          name: 'Landing Page Generator',
          description: 'Prototype ideas: prompt -> components -> preview.',
          updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
        ),
      ]);

  Project? byId(String id) {
    for (final p in state) {
      if (p.id == id) return p;
    }
    return null;
  }

  void createProject({required String name, required String description}) {
    final now = DateTime.now();
    final project = Project(
      id: const Uuid().v4(),
      name: name,
      description: description,
      updatedAt: now,
    );
    state = [project, ...state];
  }

  void touch(String projectId) {
    state = [
      for (final p in state)
        if (p.id == projectId) p.copyWith(updatedAt: DateTime.now()) else p,
    ];
  }
}

class Project {
  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final DateTime updatedAt;

  Project copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

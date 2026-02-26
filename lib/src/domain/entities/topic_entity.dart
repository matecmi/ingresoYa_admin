import 'subtopic_entity.dart';

class TopicEntity {
  final String id;
  final String name;
  final String description;
  final int order;
  final String summary;
  final List<SubtopicEntity> subtopics;

  const TopicEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.order,
    required this.summary,
    required this.subtopics,
  });
}

import 'topic_entity.dart';

class CourseEntity {
  final String id;
  final String idDoc;
  final String name;
  final String description;
  final bool active;
  final List<TopicEntity> topics;

  const CourseEntity({
    required this.id,
    required this.idDoc,
    required this.name,
    required this.description,
    required this.topics,
    this.active = true,
  });
}

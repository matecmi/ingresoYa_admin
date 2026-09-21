class SubtopicEntity {
  final String content;
  final String id;
  final String idTopic;
  final String name;
  final String order;
  final String linkVideo;
  final List<SubtopicPartEntity> listPart;

  const SubtopicEntity({
    required this.id,
    required this.name,
    required this.content,
    required this.order,
    required this.idTopic,
    required this.linkVideo,

    required this.listPart,
  });
}

class SubtopicPartEntity {
  final String id;
  final String content;
  final String idSubtopic;
  final String idTopic;
  final String name;
  final String order;
  final String linkVideo;
  final String linkPdf;
  final String summary;
  final List<String> objectives;
  final List<String> keyPoints;
  final int? estimatedMinutes;
  final String difficulty;
  final List<Map<String, dynamic>> formulas;
  final List<Map<String, dynamic>> examples;
  final List<Map<String, dynamic>> exercises;
  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> externalLinks;
  final List<Map<String, dynamic>> flashcards;
  final List<Map<String, dynamic>> quizQuestions;

  const SubtopicPartEntity({
    required this.id,
    required this.name,
    required this.idSubtopic,
    required this.idTopic,
    required this.content,
    required this.order,
    required this.linkVideo,
    required this.linkPdf,
    this.summary = '',
    this.objectives = const [],
    this.keyPoints = const [],
    this.estimatedMinutes,
    this.difficulty = 'basic',
    this.formulas = const [],
    this.examples = const [],
    this.exercises = const [],
    this.images = const [],
    this.externalLinks = const [],
    this.flashcards = const [],
    this.quizQuestions = const [],
  });
}

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

    required this.listPart

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

  const SubtopicPartEntity({
    required this.id,
    required this.name,
    required this.idSubtopic,
    required this.idTopic,
    required this.content,
    required this.order,
    required this.linkVideo,
    required this.linkPdf,
  });

}

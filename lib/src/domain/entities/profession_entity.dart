class ProfessionEntity {

  final String id;
  final String idDoc;
  final String name;
  final String acronym;
  final bool active;

  const ProfessionEntity({
    required this.id,
    required this.idDoc,
    required this.name,
    required this.acronym,
    required this.active,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'idDoc': idDoc,
    'name': name,
    'acronym': acronym,
    'active': active,
  };

  static ProfessionEntity fromJson(Map<String, dynamic> json) {

    return ProfessionEntity(
      id: json['id'],
      idDoc: json['idDoc'],
      name: json['name'],
      acronym: json['acronym'],
      active: json['active'] == true,
    );
  }
}

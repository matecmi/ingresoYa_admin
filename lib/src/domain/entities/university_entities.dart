import 'package:ingresoya_admin/src/domain/entities/profession_entity.dart';

class UniversityEntity {
  final String id;      // internal (igual al docId)
  final String idDoc;   // si lo usas distinto, si no = id
  final String name;
  final String acronym;
  final bool active;
  final String slogan;
  final String address;
  final String urlImage;
  final String location;
  final String ubigeo;
  final String department;
  final String province;
  final String district;
  final List<String>? links;
  final List<ModeEntity> modes;
  final List<ProfessionEntity> professions;

  const UniversityEntity({
    required this.id,
    required this.idDoc,
    required this.name,
    required this.acronym,
    required this.active,
    required this.slogan,
    required this.address,
    required this.urlImage,
    required this.location,
    required this.ubigeo,
    required this.department,
    required this.province,
    required this.district,
    required this.links,
    required this.modes,
    required this.professions,
  });

  UniversityEntity copyWith({
    String? name,
    String? acronym,
    bool? active,
    String? slogan,
    String? address,
    String? urlImage,
    String? location,
    String? ubigeo,
    String? department,
    String? province,
    String? district,
    List<String>? links,
  }) {
    return UniversityEntity(
      id: id,
      idDoc: idDoc,
      name: name ?? this.name,
      acronym: acronym ?? this.acronym,
      active: active ?? this.active,
      slogan: slogan ?? this.slogan,
      address: address ?? this.address,
      urlImage: urlImage ?? this.urlImage,
      location: location ?? this.location,
      ubigeo: ubigeo ?? this.ubigeo,
      department: department ?? this.department,
      province: province ?? this.province,
      district: district ?? this.district,
      links: links ?? this.links,
      modes: modes,
      professions: professions,
    );
  }
}

class ModeEntity {
  final String id;
  final String name;
  final String acronym;
  final bool active;
  final String universityId;

  const ModeEntity({
    required this.id,
    required this.name,
    required this.acronym,
    required this.active,
    required this.universityId,
  });
}



import 'dart:convert';
import '../../../shared/question_contract/question_contract.dart';

class AdmissionExam {
  AdmissionExam.fromJson(Json data)
    : id = idField(data, 'id'),
      name = idField(data, 'name'),
      universityId = idField(data, 'universityId'),
      universityName = idField(data, 'universityName'),
      universityAcronym = idField(data, 'universityAcronym'),
      modalityId = idField(data, 'modalityId'),
      modalityName = idField(data, 'modalityName'),
      examType = enumField(
        {...data, 'examType': data['examType'] ?? 'admission_exam'},
        'examType',
        ['admission_exam', 'official_practice', 'other'],
      ),
      reference = stringField(data, 'reference', fallback: '').trim(),
      revision = intField(data, 'revision', fallback: 0),
      syncPending = data['syncPending'] == true,
      year = intField(data, 'year', min: 1900),
      period = stringField(data, 'period', fallback: ''),
      active = data['active'] != false {
    if (year > 2100 || !['', 'I', 'II', 'III'].contains(period)) {
      throw const FormatException('Año o período inválido');
    }
  }
  final String id, name, universityId, universityName, universityAcronym;
  final String modalityId, modalityName, period;
  final String examType, reference;
  final int revision;
  final bool syncPending;
  final int year;
  final bool active;
  String get label => '$universityAcronym - $name';
  String get typeLabel => switch (examType) {
    'admission_exam' => 'Admisión',
    'official_practice' => 'Práctica oficial',
    _ => 'Otro',
  };

  /// University scopes the containing collection. A name change is not a new call.
  String get convocatoriaKey => base64Url
      .encode(utf8.encode(jsonEncode([examType, modalityId, year, period])))
      .replaceAll('=', '');
  Json toJson() => {
    'id': id,
    'name': name,
    'universityId': universityId,
    'universityName': universityName,
    'universityAcronym': universityAcronym,
    'modalityId': modalityId,
    'modalityName': modalityName,
    'year': year,
    'period': period,
    'active': active,
    'examType': examType,
    'reference': reference,
    'revision': revision,
  };
  SourceExam get source => SourceExam.fromJson({
    ...toJson(),
    'schemaVersion': 2,
    'examType': examType,
  });
  Json get questionFields => {
    'admissionExam': toJson(),
    'sourceExam': source.toJson(),
    'sourceType': examType,
    'sourceExamRevision': revision,
    'universityId': universityId,
    'universityName': universityName,
    'universityAcronym': universityAcronym,
    'examId': id,
    'examName': name,
    'modalityId': modalityId,
    'modalityName': modalityName,
    'year': year,
    'period': period,
    'label': label,
  };
}

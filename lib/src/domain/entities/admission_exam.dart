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
      year = intField(data, 'year', min: 1900),
      period = stringField(data, 'period', fallback: ''),
      active = data['active'] != false {
    if (year > 2100 || !['', 'I', 'II', 'III'].contains(period)) {
      throw const FormatException('Año o período inválido');
    }
  }
  final String id, name, universityId, universityName, universityAcronym;
  final String modalityId, modalityName, period;
  final int year;
  final bool active;
  String get label => '$universityAcronym - $name';
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
  };
  SourceExam get source => SourceExam.fromJson({
    ...toJson(),
    'schemaVersion': 2,
    'examType': 'admission_exam',
  });
  Json get questionFields => {
    'admissionExam': toJson(),
    'sourceExam': source.toJson(),
    'sourceType': 'admission_exam',
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

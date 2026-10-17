import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/domain/settings_catalog.dart';

void main() {
  test('cada ajuste apunta a un campo que existe en su documento', () {
    for (final spec in allSettingSpecs) {
      final value = readPath(factoryValues(spec.doc), spec.path);
      expect(value, isNotNull, reason: spec.id);
      expect(spec.check(value), isNull, reason: '${spec.id} = $value');
    }
  });

  test('los ids no se repiten', () {
    final ids = allSettingSpecs.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('los límites del catálogo los acepta el dominio', () {
    for (final spec in allSettingSpecs.where(
      (s) => s.kind == SettingKind.integer,
    )) {
      for (final edge in [spec.min, spec.max]) {
        if (edge == null) continue;
        var map = factoryValues(spec.doc);
        map = writePath(map, spec.path, edge);
        // Reglas cruzadas conocidas: se ajustan para probar solo este valor.
        if (spec.id == 'rankings.challenge.questionCount') {
          map = writePath(map, ['challenge', 'ownPastExamQuestions'], 0);
        }
        if (spec.id == 'rankings.challenge.ownPastExamQuestions') {
          map = writePath(map, ['challenge', 'questionCount'], 30);
        }
        if (spec.id == 'sync.debounceSeconds') {
          map = writePath(map, ['maxWaitSeconds'], 3600);
        }
        if (spec.id == 'sync.maxWaitSeconds') {
          map = writePath(map, ['debounceSeconds'], 5);
        }
        expect(
          validateDoc(spec.doc, map),
          isNull,
          reason: '${spec.id} = $edge',
        );
        expect(
          readPath(validateMapRoundTrip(spec.doc, map), spec.path),
          edge,
          reason: 'el dominio cambió ${spec.id} = $edge',
        );
      }
    }
  });

  test('suben y bajan igual que el servidor', () {
    expect(leagueMoves(30, 15, 15, 5), (5, 5));
    expect(leagueMoves(30, 20, 15, 5), (6, 5));
    expect(leagueMoves(4, 15, 15, 5), (1, 0));
    expect(leagueMoves(3, 50, 50, 1), (2, 1));
  });

  test('buscar sin tildes', () {
    expect(
      searchSettings('cuantos suben').map((r) => r.$2.id),
      contains('rankings.league.promotePercent'),
    );
    expect(
      searchSettings('reloj').single.$2.id,
      'simulator.practiceTimerDefault',
    );
  });
}

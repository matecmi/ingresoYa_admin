# Reporte de verificación

## Cobertura mínima trazable

| Requisito | Prueba principal |
| --- | --- |
| Borrador incompleto, clave ausente y alternativas válidas | `test/publishable_question_repo_test.dart` |
| Versión publicada inmutable y retiro | `test/publishable_question_repo_test.dart` |
| Clasificación académica, partes y filtros paginados | `test/question_academic_context_test.dart`, `test/question_bank_repo_test.dart` |
| Migración dry-run sin escritura, reanudación e idempotencia | `test/legacy_question_migration_test.dart` |
| Proyección previa sin claves, alternativas/ID inválidos y 8/10–9/10 | `functions/test/validation.test.ts` |
| Prioridad de universidad, banco insuficiente y sin duplicados | `functions/test/validation.test.ts` |
| Progreso provisional y verificado | `functions/test/validation.test.ts`, `test/part_learning_contract_test.dart` |
| Reglas de alumno/admin, intentos propios y Storage | `functions/test/rules.emulator.test.ts` |
| Límites de consulta y telemetría agregada | `functions/test/validation.test.ts`, `docs/backend_costs.md` |

La creación concurrente por `requestId`, recuperación del mismo orden y submit
idempotente se garantizan mediante transacciones y están cubiertos por las
proyecciones/validadores del backend; la corrida de emulador es el control de
integración local antes de promover a test. La prueba manual completa está en
`test_promotion_runbook.md`.

## Mediciones y límites

Las métricas de ejecución `*_completed` registran duración, lecturas
observadas, consultas, documentos devueltos, escrituras planificadas y
reintentos. El reporte de escenarios de 10/15 preguntas y su metodología está
en [backend_costs.md](backend_costs.md). No equivale a costo facturado: ese se
debe contrastar con el panel de uso de Firebase en staging.

## Resultado local de cierre

- `dart format test`: 11 archivos comprobados, 0 cambios.
- `flutter test`: 61 pruebas aprobadas.
- `flutter analyze`: sin errores bloqueantes; 405 avisos/informativos
  preexistentes de lint/deprecaciones fuera de este cambio.
- `flutter build web`: completado; produjo `build/web`.
- En `functions/`, `npm run lint`, `npm run build` y `npm test`: 21 pruebas
  unitarias aprobadas.
- Auth/Firestore/Storage Emulator: 7 pruebas aprobadas, incluida la prueba
  concurrente de servicio; el cargador de fixtures se ejecutó solo contra el
  emulador.

Los emuladores no desplegaron ni modificaron entornos remotos. La advertencia
actual de Firebase CLI indica que Java 17 perderá soporte futuro; el emulador
pasó con esta versión, pero se recomienda JDK 21 antes de actualizar CLI.

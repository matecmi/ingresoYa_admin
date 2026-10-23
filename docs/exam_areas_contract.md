# Contrato de áreas del examen

Compartido por el admin y la app (`iya-app/docs/exam_areas_contract.md` es una
copia). Decidido con Kevin el 2026-10-23: el peso de cada curso se registra
**por área** (grupo académico) de la universidad, no por carrera, porque las
carreras de un área rinden el mismo examen.

Ejemplo real: UNPRG, prospecto Admisión 2026-II, Anexo 1. Seis grupos (A
Ciencias Médicas, B Ciencia Política y Derecho, C Ciencias Económicas, D
Ciencias Sociales, E Ciencias e Ingenierías, F Ingenierías Agropecuarias), 100
preguntas cada uno, con preguntas por asignatura y puntos por respuesta
correcta distintos por grupo.

## 1. Datos (documento de la universidad)

| Campo | Contenido |
| --- | --- |
| `examAreas[]` | Áreas del examen. Cada una: `id` (letra o código corto, único en la universidad), `name` («Ciencias e Ingenierías»), `source` (de dónde salen los números: «Prospecto 2026-II, Anexo 1») y `rows[]`. |
| `examAreas[].rows[]` | Una fila por asignatura del examen: `subject` («Álgebra»), `courseId` (curso de la guía que la cubre; vacío si la guía no tiene ese curso), `questions` (entero 0–100), `points` (puntos por respuesta correcta, decimal > 0) y `key` (bool: curso clave para esta área, lo marca el admin). |
| `careerDetails.{professionId}.examAreaId` | Área que rinde la carrera. Vacío: la carrera no tiene área y la app se comporta como antes. |

Viajan en el documento de la universidad que la app ya baja por versión de
catálogo (`docs/catalog_version_contract.md`): no hay lecturas nuevas.

Reglas del admin al guardar: `id` y `name` obligatorios, `id` único; la suma
de `questions` de un área entre 1 y 200; `points` entre 0,01 y 1000; una
asignatura no se repite en la misma área. Varias asignaturas pueden apuntar al
mismo curso (se suman).

## 2. Peso de un curso

Para la carrera del alumno se toma su área y, por curso de la guía:

- `peso = Σ (questions × points)` de las filas con ese `courseId`;
- `porcentaje = peso ÷ Σ (questions × points)` de todas las filas del área
  (incluidas las que no tienen curso: es el puntaje máximo del examen);
- `preguntas = Σ questions` de esas filas;
- `clave = alguna de sus filas tiene key`.

En UNPRG grupo E: Razonamiento Verbal 20 × 20 = 400 de 2000 (20 %), Álgebra
6 × 22,222 = 133,3 (6,7 %).

## 3. Uso en la app

| Lugar | Comportamiento |
| --- | --- |
| Guía de estudio (pestaña Cursos) | Tres grupos: **«Clave para tu examen»** (cursos clave, de mayor a menor peso, tarjeta destacada con «N preguntas · P % de tu puntaje»), **«También vienen en tu examen»** (resto con preguntas > 0, por peso, con «N preguntas») y **«No vienen en tu examen»** (cursos activos sin filas o con 0 preguntas, atenuados al final). Sin área: la lista de siempre, sin grupos. |
| Estadísticas «Lo que más te acerca a <carrera>» | Usa las preguntas por curso de su área en vez de las del último examen pasado que rindió. Sin área: como antes. |
| Plan de hoy | La parte de la guía que toca sale primero de los cursos clave y luego por peso (`docs/simulator_contract.md` §4). |
| Práctica del día (Functions) | El resto de las preguntas (tras los temas débiles) sale de tres cursos activos elegidos al azar con probabilidad según su peso (`functions/src/exam_areas.ts`); una lectura de la universidad por práctica. |

El dorado sigue reservado para el dominio del subtema: lo «clave» usa el color
secundario.

import assert from "node:assert/strict";
import test from "node:test";

import { catalogBumpFields, catalogKindOf, courseIdFromParams } from "../src/catalog_version";

test("cada tipo auditado cae en su familia del catálogo o en ninguna", () => {
  assert.equal(catalogKindOf("courses"), "courses");
  assert.equal(catalogKindOf("topics"), "courses");
  assert.equal(catalogKindOf("subtopics"), "courses");
  assert.equal(catalogKindOf("universities"), "universities");
  assert.equal(catalogKindOf("universityChild"), "universities");
  for (const other of ["questions", "templates", "professions", "news", "config", "staff", "staffRoles"]) {
    assert.equal(catalogKindOf(other), null, other);
  }
});

test("el id del curso sale de {id} en el curso y de {c} en temas y subtemas", () => {
  assert.equal(courseIdFromParams("courses", { id: "alg" }), "alg");
  assert.equal(courseIdFromParams("topics", { c: "alg", id: "t1" }), "alg");
  assert.equal(courseIdFromParams("subtopics", { c: "alg", t: "t1", id: "s1" }), "alg");
  assert.equal(courseIdFromParams("universities", { id: "unprg" }), "");
  assert.equal(courseIdFromParams("courses", {}), "");
});

test("cursos sube coursesVersion y la versión del curso; universidades solo su contador", () => {
  const courses = catalogBumpFields("courses", "alg");
  assert.deepEqual(Object.keys(courses).sort(), ["courseVersions", "coursesVersion", "updatedAt"]);
  assert.deepEqual(Object.keys(courses.courseVersions as Record<string, unknown>), ["alg"]);

  const noCourse = catalogBumpFields("courses");
  assert.deepEqual(Object.keys(noCourse).sort(), ["coursesVersion", "updatedAt"]);

  const universities = catalogBumpFields("universities");
  assert.deepEqual(Object.keys(universities).sort(), ["universitiesVersion", "updatedAt"]);
});

test("un cambio de curso guarda la lista de cursos activos; temas y universidades no", () => {
  const withList = catalogBumpFields("courses", "alg", ["alg", "geo"]);
  assert.deepEqual(withList.activeCourseIds, ["alg", "geo"]);
  assert.equal("activeCourseIds" in catalogBumpFields("courses", "alg"), false);
  assert.equal("activeCourseIds" in catalogBumpFields("universities", "", ["alg"]), false);
});

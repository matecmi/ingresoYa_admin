import assert from "node:assert/strict";
import test from "node:test";

import { areaCourseWeights, weightedCourses } from "../src/exam_areas";

// UNPRG 2026-II, Anexo 1, grupo E (parte de sus filas).
const unprg = {
  examAreas: [
    {
      id: "E",
      name: "Ciencias e Ingenierías",
      rows: [
        { subject: "Habilidad verbal", courseId: "rv", questions: 20, points: 20, key: true },
        { subject: "Aritmética", courseId: "mat", questions: 6, points: 22.222 },
        { subject: "Álgebra", courseId: "mat", questions: 6, points: 22.222 },
        { subject: "Psicología", courseId: "", questions: 2, points: 17.631 },
        { subject: "Biología", courseId: "bio", questions: 0, points: 13.0038 }
      ]
    }
  ],
  careerDetails: { civil: { examAreaId: "E" }, derecho: { facultyId: "f1" } }
};

test("el peso de un curso suma sus asignaturas del área de la carrera", () => {
  const weights = areaCourseWeights(unprg, "civil");
  assert.deepEqual([...weights.keys()], ["rv", "mat"]);
  assert.equal(weights.get("rv"), 400);
  assert.ok(Math.abs((weights.get("mat") ?? 0) - 266.664) < 1e-9);
  assert.equal(areaCourseWeights(unprg, "derecho").size, 0);
  assert.equal(areaCourseWeights(unprg, undefined).size, 0);
  assert.equal(areaCourseWeights(undefined, "civil").size, 0);
});

test("la práctica del día elige más seguido los cursos que más pesan", () => {
  const active = ["rv", "mat", "his", "geo", "qui"];
  const weights = new Map([["rv", 400], ["mat", 266.664]]);
  // Con dos cursos con peso y tres sin peso, los dos con peso van siempre.
  for (let i = 0; i < 50; i++) {
    const picked = weightedCourses(active, weights, 3, `s${i}`);
    assert.equal(picked.length, 3);
    assert.ok(picked.includes("rv") && picked.includes("mat"));
  }
  // Entre cursos con peso, el más pesado sale más veces primero.
  const heavy = new Map([["rv", 400], ["mat", 100], ["his", 100], ["geo", 100]]);
  let first = 0;
  for (let i = 0; i < 400; i++) {
    if (weightedCourses(active, heavy, 1, `t${i}`)[0] === "rv") first++;
  }
  assert.ok(first > 160, `rv salió primero ${first} de 400`);
  // Misma semilla, misma elección.
  assert.deepEqual(weightedCourses(active, heavy, 3, "x"), weightedCourses(active, heavy, 3, "x"));
});

import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

const projectId = "ingresoya-security-rules";

async function main(): Promise<void> {
  if (process.env.FIRESTORE_EMULATOR_HOST === undefined) {
    throw new Error("Refusing to load fixtures without FIRESTORE_EMULATOR_HOST.");
  }
  if (process.env.FIREBASE_AUTH_EMULATOR_HOST === undefined) {
    throw new Error("Refusing to load fixtures without FIREBASE_AUTH_EMULATOR_HOST.");
  }
  if (process.env.GCLOUD_PROJECT === undefined) process.env.GCLOUD_PROJECT = projectId;
  if (getApps().length === 0) initializeApp({ projectId: process.env.GCLOUD_PROJECT });

  const db = getFirestore();
  const batch = db.batch();
  const users = db.collection("iya-profile-test");
  const courses = db.collection("iya-courses-test");
  const questions = db.collection("iya-questions-test");
  const answerKeys = db.collection("iya-question-answer-keys-test");
  const templates = db.collection("iya-exam-templates-test");

  try {
    await getAuth().getUser("fixture-student");
  } catch (error: unknown) {
    if ((error as { code?: unknown }).code !== "auth/user-not-found") throw error;
    await getAuth().createUser({
      uid: "fixture-student",
      email: "fixture-student@example.test",
      password: "FixturePass1!"
    });
  }

  batch.set(users.doc("fixture-student"), { universityId: "university-demo" });
  batch.set(users.doc("fixture-student").collection("learningProgress").doc("current"), {
    allowedParts: [{
      partId: "part-1",
      courseId: "course-demo",
      topicId: "topic-demo",
      subtopicId: "subtopic-demo"
    }]
  });
  batch.set(courses.doc("course-demo"), { active: true, name: "Curso demo" });
  batch.set(courses.doc("course-demo").collection("topics").doc("topic-demo"), {
    active: true,
    name: "Tema demo"
  });
  batch.set(
    courses.doc("course-demo").collection("topics").doc("topic-demo").collection("subtopics").doc("subtopic-demo"),
    {
      active: true,
      name: "Subtema demo",
      listPart: [{ id: "part-1", active: true, name: "Parte demo" }]
    }
  );
  batch.set(templates.doc("part-exam-v1"), {
    schemaVersion: 2,
    id: "part-exam-v1",
    version: 1,
    title: "Fixture de parte",
    status: "published",
    active: true,
    purpose: "part_completion",
    mode: "dynamic",
    selectionPolicy: "strict",
    allowedFallbackSources: [],
    questionCount: 10,
    passPercentExclusive: 80,
    blocks: [{ count: 10, filter: { partId: "part-1" } }]
  });

  for (let number = 1; number <= 10; number += 1) {
    const questionId = `fixture-question-${number}`;
    batch.set(questions.doc(questionId), {
      schemaVersion: 2,
      questionId,
      version: 1,
      status: "published",
      randomKey: number / 20,
      sourceLabel: "Fixture",
      universityId: "university-demo",
      sourceType: "original",
      sourceExamId: "",
      modalityId: "",
      courseId: "course-demo",
      topicId: "topic-demo",
      subtopicId: "subtopic-demo",
      partIds: ["part-1"],
      difficulty: "medium",
      content: [{ id: `statement-${number}`, type: "text", text: `Pregunta ${number}` }],
      alternatives: [
        { id: "a", label: "A", content: [{ id: "a", type: "text", text: "Correcta" }] },
        { id: "b", label: "B", content: [{ id: "b", type: "text", text: "Incorrecta" }] }
      ]
    });
    batch.set(answerKeys.doc(`${questionId}_1`), {
      schemaVersion: 2,
      questionId,
      version: 1,
      correctAlternativeId: "a",
      explanation: [{ id: `explanation-${number}`, type: "text", text: "Fixture" }]
    });
  }

  await batch.commit();
  console.log("Loaded deterministic test fixtures into the Firestore Emulator.");
}

void main();

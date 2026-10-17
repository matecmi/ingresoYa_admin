import assert from "node:assert/strict";
import test from "node:test";

import { Timestamp } from "firebase-admin/firestore";

import { newsTopics, pushContent, pushMessages, shouldSendPush, topicSafe } from "../src/news_push";

const now = Date.UTC(2026, 9, 21, 15);
const live = {
  status: "published",
  push: true,
  pushSentAt: null,
  publishAt: Timestamp.fromMillis(now - 60_000),
  title: "Las inscripciones cierran este viernes",
  body: "Inscríbete en la web\nde admisión.",
  priority: "urgent",
  universityIds: ["unprg"],
  universityLabels: ["UNPRG"]
};

test("temas: general o uno por universidad, con el sufijo del entorno", () => {
  assert.deepEqual(newsTopics("test", []), ["news-all-test"]);
  assert.deepEqual(newsTopics("production", undefined), ["news-all"]);
  assert.deepEqual(newsTopics("staging", ["unprg", "uni", "unprg"]), [
    "news-uni-unprg-staging",
    "news-uni-uni-staging"
  ]);
  assert.equal(topicSafe("u n/í"), "u_n__");
});

test("solo se envía una publicada, con push, sin enviar y ya visible", () => {
  assert.equal(shouldSendPush(live, now), true);
  assert.equal(shouldSendPush({ ...live, push: false }, now), false);
  assert.equal(shouldSendPush({ ...live, status: "draft" }, now), false);
  assert.equal(shouldSendPush({ ...live, pushSentAt: Timestamp.fromMillis(now) }, now), false);
  assert.equal(shouldSendPush({ ...live, publishAt: Timestamp.fromMillis(now + 1) }, now), false);
  assert.equal(shouldSendPush(null, now), false);
});

test("el texto: aviso con siglas, cuerpo en una línea y la ruta del detalle", () => {
  const content = pushContent(live);
  assert.equal(content.title, "Aviso UNPRG: Las inscripciones cierran este viernes");
  assert.equal(content.body, "Inscríbete en la web de admisión.");
  assert.equal(pushContent({ title: "Consejo", priority: "normal" }).body, "Toca para ver la noticia.");
  const [message] = pushMessages("test", "n1", live);
  assert.equal((message as { topic: string }).topic, "news-uni-unprg-test");
  assert.deepEqual(message!.data, { newsId: "n1", route: "/news/n1" });
});

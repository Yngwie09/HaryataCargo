import test from "node:test";
import assert from "node:assert/strict";
import { createTrackingHub } from "../src/tracking.js";
const settle = () => new Promise((resolve) => setImmediate(resolve));

test("satu snapshot server dibagikan ke semua dashboard dan hanya berubah saat data berubah", async () => {
  let rows = [
      { id: "k1", version: "1", data: { latitude: -5, longitude: 119 } },
    ],
    loads = 0;
  const hub = createTrackingHub(async () => {
      loads++;
      return rows;
    }, 60000),
    a = [],
    b = [];
  const stopA = hub.subscribe((event, data) => a.push({ event, data }));
  await settle();
  const stopB = hub.subscribe((event, data) => b.push({ event, data }));
  await settle();
  const before = a.length;
  await hub.refresh();
  assert.equal(a.length, before);
  rows = [
    { id: "k1", version: "2", data: { latitude: -5.001, longitude: 119.001 } },
  ];
  await hub.refresh();
  assert.equal(a.at(-1).data.docs[0].version, "2");
  assert.deepEqual(a.at(-1), b.at(-1));
  stopA();
  stopB();
  const done = loads;
  await hub.refresh();
  assert.equal(loads, done);
});
test("gangguan database menandai offline dan snapshot pemulihan dikirim meskipun koordinat tidak berubah", async () => {
  let fail = false;
  const received = [];
  const hub = createTrackingHub(async () => {
    if (fail) throw Error("offline");
    return [];
  }, 60000);
  const stop = hub.subscribe((event, data) => received.push({ event, data }));
  await settle();
  fail = true;
  await hub.refresh();
  assert.equal(received.at(-1).event, "unavailable");
  fail = false;
  await hub.refresh();
  assert.equal(received.at(-1).event, "locations");
  stop();
});
test("pembaruan lambat tidak menumpuk kueri database", async () => {
  let complete,
    loads = 0;
  const hub = createTrackingHub(() => {
    loads++;
    return new Promise((resolve) => (complete = resolve));
  }, 60000);
  const stop = hub.subscribe(() => {});
  await hub.refresh();
  await hub.refresh();
  assert.equal(loads, 1);
  complete([]);
  await settle();
  stop();
});

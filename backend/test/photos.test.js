import test from "node:test";
import assert from "node:assert/strict";
import sharp from "sharp";
import { preparePhoto } from "../src/photos.js";

test("JPG dan PNG dinormalisasi dan dapat didekode ulang", async () => {
  for (const [format, type] of [
    ["jpeg", "image/jpeg"],
    ["png", "image/png"],
  ]) {
    const original = await sharp({
      create: { width: 640, height: 480, channels: 3, background: "#123e52" },
    })
      [format]()
      .toBuffer();
    const bytes = await preparePhoto(original, type);
    assert.equal((await sharp(bytes).metadata()).format, format);
    assert.equal((await sharp(bytes).raw().toBuffer()).length, 640 * 480 * 3);
    assert.deepEqual(await preparePhoto(original, type), bytes);
  }
});
test("file rusak, gambar mini dan tipe palsu ditolak sebelum masuk database", async () => {
  await assert.rejects(
    preparePhoto(Buffer.from([255, 216, 255, 1, 2]), "image/jpeg"),
    (e) => e.code === "invalid-image",
  );
  const tiny = await sharp({
    create: { width: 1, height: 1, channels: 3, background: "#ffffff" },
  })
    .png()
    .toBuffer();
  await assert.rejects(
    preparePhoto(tiny, "image/png"),
    (e) => e.status === 400,
  );
  const png = await sharp({
    create: { width: 64, height: 64, channels: 3, background: "#ffffff" },
  })
    .png()
    .toBuffer();
  await assert.rejects(
    preparePhoto(png, "image/jpeg"),
    (e) => e.status === 400,
  );
});

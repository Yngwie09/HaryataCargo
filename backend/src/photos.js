import sharp from "sharp";
import { requireValue, ApiError } from "./auth.js";

sharp.concurrency(1);
sharp.cache({ memory: 16, files: 0, items: 16 });

/** Decode the entire image: a valid file signature alone cannot detect damage. */
export async function preparePhoto(bytes, contentType) {
  try {
    const image = sharp(bytes, {
      limitInputPixels: 24000000,
      failOn: "warning",
    });
    const meta = await image.metadata();
    requireValue(
      (contentType === "image/jpeg" && meta.format === "jpeg") ||
        (contentType === "image/png" && meta.format === "png"),
      "Format foto tidak sesuai.",
    );
    requireValue(
      meta.width >= 32 && meta.height >= 32,
      "Foto terlalu kecil. Ambil kembali foto yang jelas.",
    );
    const normalized = image
      .rotate()
      .resize({
        width: 2000,
        height: 2000,
        fit: "inside",
        withoutEnlargement: true,
      });
    const result = await (
      meta.format === "jpeg"
        ? normalized.jpeg({ quality: 85 })
        : normalized.png({ compressionLevel: 6 })
    ).toBuffer();
    requireValue(result.length <= 5242880, "Foto maksimal 5 MB.");
    return result;
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(
      400,
      "invalid-image",
      "Foto rusak atau tidak dapat dibaca. Pilih foto JPG atau PNG yang lain.",
    );
  }
}

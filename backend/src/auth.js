import {
  randomBytes,
  scrypt as scryptCallback,
  timingSafeEqual,
  createHash,
} from "node:crypto";
import { promisify } from "node:util";
import { pool } from "./db.js";
const scrypt = promisify(scryptCallback);
export class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}
export function requireValue(
  ok,
  message,
  code = "invalid-argument",
  status = 400,
) {
  if (!ok) throw new ApiError(status, code, message);
}
export function validPassword(value) {
  return typeof value === "string" && value.length > 0 && value.length <= 4096;
}
export function validEmail(value) {
  return (
    typeof value === "string" &&
    value.length <= 254 &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)
  );
}
export async function hashPassword(password) {
  requireValue(validPassword(password), "Isi kata sandi.");
  const salt = randomBytes(16).toString("hex");
  const hash = await scrypt(password, salt, 64, {
    N: 16384,
    r: 8,
    p: 1,
    maxmem: 64 * 1024 * 1024,
  });
  return `scrypt$${salt}$${hash.toString("hex")}`;
}
export async function verifyPassword(password, encoded) {
  if (!validPassword(password) || !encoded) return false;
  const [kind, salt, hash] = encoded.split("$");
  if (kind !== "scrypt" || !/^[a-f0-9]{128}$/.test(hash || "")) return false;
  const actual = await scrypt(password, salt, 64, {
    N: 16384,
    r: 8,
    p: 1,
    maxmem: 64 * 1024 * 1024,
  });
  return timingSafeEqual(actual, Buffer.from(hash, "hex"));
}
export const tokenHash = (token) =>
  createHash("sha256").update(token).digest("hex");
export function publicUser(u) {
  return {
    uid: u.id,
    email: u.email,
    name: u.name,
    role: u.role,
    active: u.active,
  };
}
export async function authenticate(req, res, next) {
  try {
    const token = req.headers.authorization?.match(
      /^Bearer ([A-Za-z0-9_-]{43})$/,
    )?.[1];
    if (!token)
      throw new ApiError(
        401,
        "unauthenticated",
        "Silakan masuk terlebih dahulu.",
      );
    const { rows } = await pool.query(
      "SELECT u.* FROM sessions s JOIN app_users u ON u.id=s.user_id WHERE s.token_hash=$1 AND s.expires_at>now()",
      [tokenHash(token)],
    );
    if (!rows[0] || !rows[0].active)
      throw new ApiError(
        401,
        "unauthenticated",
        "Sesi berakhir atau akun dinonaktifkan. Silakan masuk kembali.",
      );
    req.user = rows[0];
    req.sessionHash = tokenHash(token);
    next();
  } catch (e) {
    next(e);
  }
}
export function admin(user) {
  if (user.role !== "admin")
    throw new ApiError(403, "permission-denied", "Menu ini hanya untuk admin.");
}
export async function bootstrapAdmin() {
  const email = process.env.ADMIN_EMAIL?.trim().toLowerCase(),
    password = process.env.ADMIN_PASSWORD;
  if (!email || !password) return;
  requireValue(validEmail(email), "ADMIN_EMAIL tidak valid.");
  const hash = await hashPassword(password);
  await pool.query(
    `INSERT INTO app_users(id,email,name,role,password_hash) VALUES($1,$2,'Admin Haryata','admin',$3) ON CONFLICT DO NOTHING`,
    [
      "admin_" + createHash("sha256").update(email).digest("hex").slice(0, 24),
      email,
      hash,
    ],
  );
}
export async function createSession(user) {
  const token = randomBytes(32).toString("base64url");
  await pool.query("DELETE FROM sessions WHERE expires_at<now()");
  await pool.query(
    "INSERT INTO sessions(token_hash,user_id,expires_at) VALUES($1,$2,now()+interval '14 days')",
    [tokenHash(token), user.id],
  );
  return { token, user: publicUser(user) };
}

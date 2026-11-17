import { admin } from "./auth.js";
import { queryRecords } from "./records.js";

/** One database refresh serves every connected dashboard; no per-client polling. */
export function createTrackingHub(load, intervalMs = 1000) {
  const clients = new Set();
  let timer,
    busy = false,
    previous,
    latest;
  async function refresh() {
    if (busy || clients.size === 0) return;
    busy = true;
    try {
      const data = { docs: await load() },
        encoded = JSON.stringify(data);
      if (encoded !== previous) {
        previous = encoded;
        latest = data;
        for (const client of clients) client("locations", data);
      }
    } catch (_) {
      previous = undefined;
      for (const client of clients)
        client("unavailable", {
          message: "Sinkronisasi lokasi sedang dipulihkan.",
        });
    } finally {
      busy = false;
    }
  }
  return {
    subscribe(client) {
      clients.add(client);
      if (latest) client("locations", latest);
      if (!timer) {
        timer = setInterval(refresh, intervalMs);
        timer.unref?.();
      }
      refresh();
      return () => {
        clients.delete(client);
        if (!clients.size) {
          clearInterval(timer);
          timer = undefined;
          previous = undefined;
          latest = undefined;
        }
      };
    },
    refresh,
  };
}

export function registerTracking(app, pool) {
  const hub = createTrackingHub(() =>
    queryRecords(
      pool,
      { role: "admin" },
      { path: "courier_locations", limit: 5000 },
    ),
  );
  app.get("/v1/tracking/stream", (req, res) => {
    admin(req.user);
    res
      .status(200)
      .set({
        "Content-Type": "text/event-stream; charset=utf-8",
        "Cache-Control": "no-cache, no-transform",
        Connection: "keep-alive",
        "X-Accel-Buffering": "no",
      });
    res.flushHeaders();
    res.write(": connected\n\n");
    let closed = false,
      validating = false;
    const send = (event, data) => {
      if (closed) return;
      // Reconnect slow consumers instead of allowing unbounded response buffers.
      if (res.writableLength > 262144) {
        res.end();
        return;
      }
      res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
    };
    const unsubscribe = hub.subscribe(send);
    const heartbeat = setInterval(async () => {
      if (closed || validating) return;
      validating = true;
      try {
        const session = await pool.query(
          "SELECT 1 FROM sessions s JOIN app_users u ON u.id=s.user_id WHERE s.token_hash=$1 AND s.expires_at>now() AND u.active=true AND u.role='admin'",
          [req.sessionHash],
        );
        if (!session.rowCount) {
          send("expired", {});
          res.end();
          return;
        }
        if (!closed) res.write(": heartbeat\n\n");
      } catch (_) {
        send("unavailable", { message: "Koneksi lokasi sedang dipulihkan." });
      } finally {
        validating = false;
      }
    }, 15000);
    req.on("close", () => {
      closed = true;
      clearInterval(heartbeat);
      unsubscribe();
    });
  });
}

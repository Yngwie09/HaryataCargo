CREATE TABLE IF NOT EXISTS schema_migrations(version integer PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS app_users(
 id text PRIMARY KEY, email text NOT NULL, name text NOT NULL,
 phone text NOT NULL DEFAULT '', role text NOT NULL CHECK(role IN ('admin','kurir')),
 active boolean NOT NULL DEFAULT true, password_hash text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 revision bigint NOT NULL DEFAULT 1
);
CREATE UNIQUE INDEX IF NOT EXISTS app_users_email_unique ON app_users(lower(email));
CREATE TABLE IF NOT EXISTS sessions(
 token_hash text PRIMARY KEY, user_id text NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
 expires_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sessions_user_idx ON sessions(user_id);
CREATE TABLE IF NOT EXISTS shipments(
 id text PRIMARY KEY, resi text NOT NULL UNIQUE CHECK(resi ~ '^[A-Z0-9-]{4,40}$'),
 courier_id text NOT NULL REFERENCES app_users(id), status text NOT NULL
 CHECK(status IN ('Pending','Proses','Tertunda','Selesai','Retur','Batal')),
 data jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(), revision bigint NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS shipments_courier_created_idx ON shipments(courier_id,created_at DESC);
CREATE INDEX IF NOT EXISTS shipments_status_created_idx ON shipments(status,created_at DESC);
CREATE INDEX IF NOT EXISTS shipments_completed_idx ON shipments((data->>'completedAt'));
CREATE TABLE IF NOT EXISTS courier_locations(
 courier_id text PRIMARY KEY REFERENCES app_users(id), latitude double precision,
 longitude double precision, data jsonb NOT NULL, updated_at timestamptz NOT NULL DEFAULT now(),
 revision bigint NOT NULL DEFAULT 1,
 CHECK(latitude BETWEEN -90 AND 90), CHECK(longitude BETWEEN -180 AND 180)
);
CREATE TABLE IF NOT EXISTS shipment_events(
 id text PRIMARY KEY, shipment_id text NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
 actor_id text REFERENCES app_users(id), data jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS shipment_events_order_idx ON shipment_events(shipment_id,created_at DESC);
CREATE TABLE IF NOT EXISTS proof_photos(
 path text PRIMARY KEY, shipment_id text NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
 courier_id text NOT NULL REFERENCES app_users(id), kind text NOT NULL CHECK(kind IN ('receipt','recipient','parcel')),
 content_type text NOT NULL CHECK(content_type IN ('image/jpeg','image/png')),
 bytes bytea NOT NULL CHECK(octet_length(bytes) BETWEEN 1 AND 5242880),
 created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO schema_migrations(version) VALUES(1) ON CONFLICT DO NOTHING;

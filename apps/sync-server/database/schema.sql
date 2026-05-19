-- Sync Server Database Schema
-- PostgreSQL

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    encrypted_key TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Devices table
CREATE TABLE IF NOT EXISTS devices (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    public_key TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_sync_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Sync records table (stores pending sync operations)
CREATE TABLE IF NOT EXISTS sync_records (
    id TEXT PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    operation TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    data TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    synced_at TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1
);

-- Conflict records table
CREATE TABLE IF NOT EXISTS conflicts (
    id TEXT PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    device_id_1 TEXT NOT NULL REFERENCES devices(id),
    device_id_2 TEXT NOT NULL REFERENCES devices(id),
    data_1 TEXT NOT NULL,
    data_2 TEXT NOT NULL,
    resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolution TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_sync_records_device ON sync_records(device_id);
CREATE INDEX IF NOT EXISTS idx_sync_records_table ON sync_records(table_name);
CREATE INDEX IF NOT EXISTS idx_sync_records_created ON sync_records(created_at);
CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id);
CREATE INDEX IF NOT EXISTS idx_conflicts_record ON conflicts(table_name, record_id);
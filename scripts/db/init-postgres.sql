CREATE TABLE IF NOT EXISTS audit_job_trail (
    track_id         TEXT        NOT NULL,
    process_name     TEXT        NOT NULL,
    track_timestamp  BIGINT      NOT NULL,
    track_datetime   TIMESTAMPTZ NOT NULL,
    track_status     TEXT        NOT NULL,
    status_type      TEXT        NOT NULL,
    tenant_id        TEXT        NOT NULL,
    reference_id     TEXT        NOT NULL,
    parent_id        TEXT        NOT NULL,
    hierarchy_level  INTEGER     NOT NULL,
    message          TEXT,
    extras           JSONB,
    ttl_timestamp    BIGINT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (track_id, track_timestamp)
);

CREATE INDEX IF NOT EXISTS idx_app_lifecycle_track_id_status_type     ON audit_job_trail (track_id,     status_type,  track_timestamp);
CREATE INDEX IF NOT EXISTS idx_app_lifecycle_parent_id_status_type    ON audit_job_trail (parent_id,    status_type,  track_timestamp);
CREATE INDEX IF NOT EXISTS idx_app_lifecycle_reference_id_status_type ON audit_job_trail (reference_id, status_type,  track_timestamp);
CREATE INDEX IF NOT EXISTS idx_app_lifecycle_tenant_id_status_type    ON audit_job_trail (tenant_id,    status_type,  track_timestamp);
CREATE INDEX IF NOT EXISTS idx_app_lifecycle_track_id_track_status    ON audit_job_trail (track_id,     track_status, track_timestamp);
CREATE INDEX IF NOT EXISTS idx_app_lifecycle_parent_id_track_status   ON audit_job_trail (parent_id,    track_status, track_timestamp);
CREATE INDEX IF NOT EXISTS idx_app_lifecycle_reference_id_track_status ON audit_job_trail (reference_id, track_status, track_timestamp);
CREATE INDEX IF NOT EXISTS idx_app_lifecycle_tenant_id_track_status   ON audit_job_trail (tenant_id,    track_status, track_timestamp);

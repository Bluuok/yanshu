PRAGMA foreign_keys = ON;
PRAGMA user_version = 1;

-- V1 SQLite 参考建表。所有路径必须位于独立的受限工作区。
-- 日期字段使用 UTC ISO 8601，由应用层写入；未授权数据不得外发。
CREATE TABLE IF NOT EXISTS projects (
  project_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  data_policy TEXT NOT NULL DEFAULT 'PUBLIC'
    CHECK (data_policy IN ('PUBLIC','LOCAL_ONLY','APPROVED_CLOUD')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS yanshu_tasks (
  task_id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(project_id),
  task_type TEXT NOT NULL CHECK (task_type IN ('LITERATURE','COMPUTE','PLAN','WRITE','REVIEW')),
  yanshu_status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (yanshu_status IN ('PENDING','RUNNING','WAITING_FOR_DATA',
      'WAITING_FOR_CONFIRM','RECONCILING','COMPLETED','FAILED','CANCELLED')),
  status_reason TEXT,
  checkpoint_json TEXT NOT NULL DEFAULT '{}',
  input_bundle_sha256 TEXT,
  version INTEGER NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_tasks_project_status
  ON yanshu_tasks(project_id,yanshu_status);

CREATE TABLE IF NOT EXISTS task_attempts (
  attempt_id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL REFERENCES yanshu_tasks(task_id),
  attempt_no INTEGER NOT NULL CHECK (attempt_no >= 1),
  os_session_id TEXT,
  os_request_id TEXT,
  os_run_id TEXT,
  request_payload_sha256 TEXT NOT NULL,
  attempt_state TEXT NOT NULL DEFAULT 'PREPARED'
    CHECK (attempt_state IN ('PREPARED','SUBMITTED','RUNNING','COMPLETED',
      'FAILED','CANCELLED','INTERRUPTED','UNKNOWN')),
  side_effect_state TEXT NOT NULL DEFAULT 'UNKNOWN'
    CHECK (side_effect_state IN ('UNKNOWN','NONE','OBSERVED','VERIFIED')),
  effect_manifest_json TEXT NOT NULL DEFAULT '[]',
  result_ref TEXT,
  failure_reason TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (task_id,attempt_no),
  UNIQUE (os_session_id,os_request_id)
);
-- 防止同一业务任务同时出现两次未决提交。
CREATE UNIQUE INDEX IF NOT EXISTS idx_attempt_one_active
  ON task_attempts(task_id)
  WHERE attempt_state IN ('PREPARED','SUBMITTED','RUNNING','UNKNOWN');

CREATE TABLE IF NOT EXISTS task_events (
  event_id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL REFERENCES yanshu_tasks(task_id),
  old_status TEXT,
  new_status TEXT NOT NULL,
  actor_type TEXT NOT NULL CHECK (actor_type IN ('SYSTEM','RESEARCHER','REVIEWER')),
  actor_id TEXT,
  reason TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_events_task_time ON task_events(task_id,created_at);

CREATE TABLE IF NOT EXISTS scientific_sources (
  source_id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(project_id),
  source_type TEXT NOT NULL CHECK (source_type IN ('CSV','EXCEL','PDF','API','OTHER')),
  original_name TEXT NOT NULL,
  immutable_path TEXT NOT NULL,
  file_sha256 TEXT NOT NULL CHECK (length(file_sha256) = 64),
  file_size_bytes INTEGER NOT NULL CHECK (file_size_bytes >= 0),
  source_version INTEGER NOT NULL DEFAULT 1 CHECK (source_version >= 1),
  parent_source_id TEXT REFERENCES scientific_sources(source_id),
  provenance_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_sources_project_hash
  ON scientific_sources(project_id,file_sha256);

CREATE TABLE IF NOT EXISTS compute_records (
  record_id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(project_id),
  task_id TEXT REFERENCES yanshu_tasks(task_id),
  attempt_id TEXT REFERENCES task_attempts(attempt_id),
  script_version TEXT NOT NULL,
  script_sha256 TEXT NOT NULL CHECK (length(script_sha256) = 64),
  environment_fingerprint TEXT NOT NULL,
  input_params_json TEXT NOT NULL DEFAULT '{}',
  output_manifest_json TEXT NOT NULL DEFAULT '[]',
  output_summary_json TEXT NOT NULL DEFAULT '{}',
  compute_status TEXT NOT NULL CHECK (compute_status IN ('RUNNING','COMPLETED','FAILED')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_compute_project ON compute_records(project_id);

CREATE TABLE IF NOT EXISTS compute_inputs (
  input_id TEXT PRIMARY KEY,
  record_id TEXT NOT NULL REFERENCES compute_records(record_id),
  source_id TEXT NOT NULL REFERENCES scientific_sources(source_id),
  source_locator TEXT NOT NULL,
  parsed_data_sha256 TEXT,
  parser_config_json TEXT NOT NULL DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_compute_inputs_record ON compute_inputs(record_id);

CREATE TABLE IF NOT EXISTS scientific_claims (
  claim_id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(project_id),
  claim_text TEXT NOT NULL,
  claim_type TEXT NOT NULL CHECK (claim_type IN ('DATA','LITERATURE','HYPOTHESIS','INTERPRETATION')),
  document_version TEXT NOT NULL,
  review_state TEXT NOT NULL DEFAULT 'UNVERIFIED'
    CHECK (review_state IN ('UNVERIFIED','SUPPORTED','PARTIAL','CONFLICT','REJECTED')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS evidence_links (
  link_id TEXT PRIMARY KEY,
  claim_id TEXT NOT NULL REFERENCES scientific_claims(claim_id),
  source_id TEXT REFERENCES scientific_sources(source_id),
  record_id TEXT REFERENCES compute_records(record_id),
  source_locator TEXT,
  exact_snippet TEXT,
  support_state TEXT NOT NULL DEFAULT 'UNVERIFIED'
    CHECK (support_state IN ('UNVERIFIED','SUPPORTED','PARTIAL','CONFLICT','INSUFFICIENT')),
  reviewer_id TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (source_id IS NOT NULL OR record_id IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS idx_evidence_claim ON evidence_links(claim_id);
-- 业务层写入事务必须核查所有关联对象的 project_id 相同。

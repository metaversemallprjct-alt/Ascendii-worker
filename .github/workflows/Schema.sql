-- =============================================================================
-- Ascendii Protocol — Off-Chain Indexer Schema
-- Covers: HandleRegistry, RitualGate, HallOfMonuments, SIBCore / ScoreEngine /
--         BenefactorVault / CeremonyRegistry / GovernanceCap / SIBAccessControl,
--         AscendiiFoundingArchitects, InterchangeHubBase
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

CREATE TYPE rank_tier AS ENUM (
    'INITIATE', 'APPRENTICE', 'ARTISAN', 'MASTER', 'LEGENDARY'
);

CREATE TYPE benefactor_state AS ENUM (
    'INACTIVE', 'ACTIVE', 'SUSPENDED', 'EXITED'
);

CREATE TYPE ceremony_type AS ENUM (
    'GENESIS', 'ASCENSION', 'RITUAL', 'LEGACY'
);

CREATE TYPE consent_status AS ENUM (
    'PENDING', 'GRANTED', 'REVOKED'
);

CREATE TYPE broadcast_status AS ENUM (
    'SCHEDULED', 'DELIVERED', 'FAILED'
);

-- =============================================================================
-- HandleRegistry
-- =============================================================================

CREATE TABLE handles (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_address   CHAR(42)    NOT NULL,
    handle          CITEXT      NOT NULL UNIQUE,
    registered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    released_at     TIMESTAMPTZ,
    cooldown_until  TIMESTAMPTZ,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    CONSTRAINT handle_format CHECK (handle ~ '^[a-zA-Z0-9_]{1,32}$')
);

CREATE INDEX idx_handles_owner  ON handles (owner_address);
CREATE INDEX idx_handles_active ON handles (is_active) WHERE is_active = TRUE;

CREATE TABLE handle_history (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    handle_id       UUID        NOT NULL REFERENCES handles (id) ON DELETE CASCADE,
    previous_handle CITEXT      NOT NULL,
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE handle_rename_requests (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    handle_id       UUID        NOT NULL REFERENCES handles (id) ON DELETE CASCADE,
    new_handle      CITEXT      NOT NULL,
    requested_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fulfilled_at    TIMESTAMPTZ,
    cancelled_at    TIMESTAMPTZ
);

CREATE TABLE endorsements (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    handle_id           UUID        NOT NULL REFERENCES handles (id) ON DELETE CASCADE,
    endorser_address    CHAR(42)    NOT NULL,
    epoch               BIGINT      NOT NULL,
    endorsed_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (handle_id, endorser_address, epoch)
);

-- =============================================================================
-- RitualGate
-- =============================================================================

CREATE TABLE ritual_verifiers (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    ritual_type         TEXT        NOT NULL UNIQUE,
    contract_address    CHAR(42)    NOT NULL,
    registered_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ,
    is_enabled          BOOLEAN     NOT NULL DEFAULT TRUE
);

CREATE TABLE verifier_update_log (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    ritual_type     TEXT        NOT NULL,
    old_address     CHAR(42),
    new_address     CHAR(42)    NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE ritual_verifications (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    handle_id       UUID        NOT NULL REFERENCES handles (id) ON DELETE CASCADE,
    ritual_type     TEXT        NOT NULL,
    proof_hash      CHAR(66)    NOT NULL UNIQUE,
    verified_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    chain_id        BIGINT      NOT NULL
);

-- =============================================================================
-- HallOfMonuments
-- =============================================================================

CREATE TABLE monuments (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    on_chain_id     BIGINT      NOT NULL UNIQUE,
    creator_handle  UUID        NOT NULL REFERENCES handles (id),
    name            TEXT        NOT NULL,
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_paused       BOOLEAN     NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE
);

CREATE TABLE monument_contributions (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    monument_id     UUID        NOT NULL REFERENCES monuments (id) ON DELETE CASCADE,
    contributor     UUID        NOT NULL REFERENCES handles (id),
    proof_hash      CHAR(66)    NOT NULL UNIQUE,
    contributed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (monument_id, contributor)
);

-- =============================================================================
-- SIB Stack
-- =============================================================================

CREATE TABLE sib_roles (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    address     CHAR(42)    NOT NULL,
    role        TEXT        NOT NULL,
    granted_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at  TIMESTAMPTZ,
    UNIQUE (address, role)
);

CREATE TABLE soul_badges (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_address   CHAR(42)        NOT NULL UNIQUE,
    handle_id       UUID            REFERENCES handles (id),
    rank_tier       rank_tier       NOT NULL DEFAULT 'INITIATE',
    ais_score       NUMERIC(18,6)   NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE TABLE score_events (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    badge_id        UUID            NOT NULL REFERENCES soul_badges (id) ON DELETE CASCADE,
    delta           NUMERIC(18,6)   NOT NULL,
    new_score       NUMERIC(18,6)   NOT NULL,
    event_type      TEXT            NOT NULL,
    source_ref      UUID,
    block_number    BIGINT,
    occurred_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE TABLE benefactor_records (
    id                  UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    address             CHAR(42)            NOT NULL UNIQUE,
    state               benefactor_state    NOT NULL DEFAULT 'INACTIVE',
    deposited_amount    NUMERIC(36,0)       NOT NULL DEFAULT 0,
    lcs_checkpoint      TIMESTAMPTZ,
    created_at          TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

CREATE TABLE deposits (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    benefactor_id   UUID            NOT NULL REFERENCES benefactor_records (id) ON DELETE CASCADE,
    amount          NUMERIC(36,0)   NOT NULL,
    tx_hash         CHAR(66)        NOT NULL UNIQUE,
    deposited_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE TABLE distribution_grants (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    benefactor_id   UUID            NOT NULL REFERENCES benefactor_records (id) ON DELETE CASCADE,
    badge_id        UUID            REFERENCES soul_badges (id),
    amount          NUMERIC(36,0)   NOT NULL,
    released_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    tx_hash         CHAR(66)        NOT NULL UNIQUE
);

CREATE TABLE ceremony_entries (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    on_chain_id     BIGINT          NOT NULL UNIQUE,
    badge_id        UUID            NOT NULL REFERENCES soul_badges (id) ON DELETE CASCADE,
    ceremony_type   ceremony_type   NOT NULL,
    consent_status  consent_status  NOT NULL DEFAULT 'PENDING',
    proof_hash      CHAR(66)        UNIQUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);

CREATE TABLE governance_parameter_log (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    param_key   TEXT        NOT NULL,
    old_value   TEXT,
    new_value   TEXT        NOT NULL,
    changed_by  CHAR(42)    NOT NULL,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tx_hash     CHAR(66)    NOT NULL UNIQUE
);

-- =============================================================================
-- AscendiiFoundingArchitects
-- =============================================================================

CREATE TABLE founding_architects (
    token_id        BIGINT      PRIMARY KEY,
    owner_address   CHAR(42)    NOT NULL,
    aura            TEXT        NOT NULL,
    mantle          TEXT        NOT NULL,
    virtue          TEXT        NOT NULL,
    rank            TEXT        NOT NULL,
    metadata_uri    TEXT        NOT NULL,
    minted_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tx_hash         CHAR(66)    NOT NULL UNIQUE,
    CONSTRAINT token_id_range CHECK (token_id BETWEEN 1 AND 222)
);

CREATE INDEX idx_fa_owner ON founding_architects (owner_address);

-- =============================================================================
-- InterchangeHubBase
-- =============================================================================

CREATE TABLE semaphore_root_broadcasts (
    id                  UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    semaphore_root      CHAR(66)            NOT NULL,
    target_chain_id     BIGINT              NOT NULL,
    lz_dst_eid          BIGINT,
    status              broadcast_status    NOT NULL DEFAULT 'SCHEDULED',
    refund_address      CHAR(42),
    scheduled_at        TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    delivered_at        TIMESTAMPTZ,
    failed_at           TIMESTAMPTZ,
    tx_hash_origin      CHAR(66),
    tx_hash_delivery    CHAR(66)
);

CREATE INDEX idx_root_broadcasts_status ON semaphore_root_broadcasts (status);

-- =============================================================================
-- Cross-module view + indexer bookkeeping
-- =============================================================================

CREATE VIEW v_identity AS
    SELECT
        h.handle,
        h.owner_address,
        sb.rank_tier,
        sb.ais_score,
        fa.token_id     AS founding_architect_token,
        h.registered_at
    FROM handles h
    LEFT JOIN soul_badges         sb ON sb.owner_address = h.owner_address
    LEFT JOIN founding_architects fa ON fa.owner_address = h.owner_address
    WHERE h.is_active = TRUE;

CREATE TABLE indexer_checkpoints (
    chain_id        BIGINT  NOT NULL,
    contract_name   TEXT    NOT NULL,
    last_block      BIGINT  NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (chain_id, contract_name)
);

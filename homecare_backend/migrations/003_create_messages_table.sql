CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY,
    family_id UUID NOT NULL,
    sender_id UUID NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_family_created_at
    ON messages (family_id, created_at);

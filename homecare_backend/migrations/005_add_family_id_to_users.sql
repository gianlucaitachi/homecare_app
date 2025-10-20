-- Add family_id column to users and backfill existing data with new families
ALTER TABLE users
    ADD COLUMN family_id UUID;

-- Create families for existing users and assign them
CREATE TEMP TABLE tmp_user_families AS
SELECT
    id AS user_id,
    uuid_generate_v4() AS family_id,
    name
FROM users;

INSERT INTO families (id, name)
SELECT
    family_id,
    name || ' Family'
FROM tmp_user_families
ON CONFLICT (id) DO NOTHING;

UPDATE users
SET family_id = tmp.family_id
FROM tmp_user_families tmp
WHERE users.id = tmp.user_id;

ALTER TABLE users
    ALTER COLUMN family_id SET NOT NULL;

ALTER TABLE users
    ADD CONSTRAINT users_family_id_fkey
    FOREIGN KEY (family_id) REFERENCES families(id) ON DELETE RESTRICT;

DROP TABLE tmp_user_families;

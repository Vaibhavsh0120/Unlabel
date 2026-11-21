-- Retain the user's explicit choice independently from the thumbnail's origin.
ALTER TABLE accounts.profiles ADD COLUMN avatar_preference varchar(16)
    NOT NULL DEFAULT 'automatic'
    CHECK (avatar_preference IN ('automatic', 'defaultAvatar', 'google', 'custom'));
UPDATE accounts.profiles SET avatar_preference='custom' WHERE avatar_png IS NOT NULL;

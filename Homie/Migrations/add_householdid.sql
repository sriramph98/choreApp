-- Migration to add householdid column to tasks table
-- Run this script on your Supabase database to update the schema

-- First, add the householdid column to the tasks table if it doesn't exist
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS householdid UUID;

-- Update tasks table with indexes to improve performance
DROP INDEX IF EXISTS idx_tasks_userid;
CREATE INDEX IF NOT EXISTS idx_tasks_userid_householdid ON tasks(userid, householdid);

-- Add foreign key constraint if households table exists
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'households') THEN
        -- Check if constraint already exists
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'fk_tasks_household' 
            AND table_name = 'tasks'
        ) THEN
            ALTER TABLE tasks 
            ADD CONSTRAINT fk_tasks_household 
            FOREIGN KEY (householdid) 
            REFERENCES households(id) 
            ON DELETE SET NULL;
        END IF;
    END IF;
END
$$;

-- Add comment explaining the column
COMMENT ON COLUMN tasks.householdid IS 'References the household this task belongs to';

-- Print success message
DO $$
BEGIN
    RAISE NOTICE 'Migration completed: Added householdid column to tasks table';
END
$$; 
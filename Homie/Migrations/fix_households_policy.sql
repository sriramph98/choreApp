-- Fix for the household policy error
-- This script first drops any existing policies before recreating them

-- First, check if the table exists and drop existing policies
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'households') THEN
        -- Drop existing policies if they exist
        DROP POLICY IF EXISTS "Users can view their households" ON households;
        DROP POLICY IF EXISTS "Users can create households" ON households;
        DROP POLICY IF EXISTS "Creators can update their households" ON households;
        DROP POLICY IF EXISTS "Creators can delete their households" ON households;
    END IF;
END
$$;

-- Create the households table if it doesn't exist
CREATE TABLE IF NOT EXISTS households (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    creatorid UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    members UUID[] DEFAULT ARRAY[]::UUID[], -- Array of user IDs
    createdat TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for faster lookup
CREATE INDEX IF NOT EXISTS idx_households_creatorid ON households(creatorid);
CREATE INDEX IF NOT EXISTS idx_households_members ON households USING GIN (members);

-- Enable Row Level Security
ALTER TABLE households ENABLE ROW LEVEL SECURITY;

-- Re-create the policies
-- Users can view households they're a member of
CREATE POLICY "Users can view their households"
    ON households FOR SELECT
    USING (creatorid = auth.uid() OR auth.uid()::text = ANY(members::text[]));

-- Users can create households
CREATE POLICY "Users can create households"
    ON households FOR INSERT
    WITH CHECK (creatorid = auth.uid());

-- Users can update households they created
CREATE POLICY "Creators can update their households"
    ON households FOR UPDATE
    USING (creatorid = auth.uid());

-- Users can delete households they created
CREATE POLICY "Creators can delete their households"
    ON households FOR DELETE
    USING (creatorid = auth.uid());

-- If the add_householdid migration has already been run,
-- update the tasks table to reference the households table
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'tasks' AND column_name = 'householdid'
    ) THEN
        -- Add the constraint if it doesn't exist already
        IF NOT EXISTS (
            SELECT FROM information_schema.table_constraints 
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
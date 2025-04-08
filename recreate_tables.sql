-- Drop existing tables if they exist
DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS profiles;

-- Create profiles table
CREATE TABLE profiles (
  id UUID PRIMARY KEY,
  authuserid UUID REFERENCES auth.users(id) NOT NULL,
  name TEXT NOT NULL,
  avatarsystemname TEXT NOT NULL,
  color TEXT NOT NULL,
  createdat TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create tasks table
CREATE TABLE tasks (
  id UUID PRIMARY KEY,
  userid UUID NOT NULL,
  name TEXT NOT NULL,
  duedate TEXT NOT NULL,
  iscompleted BOOLEAN DEFAULT FALSE,
  assignedto UUID,
  notes TEXT,
  repeatoption TEXT DEFAULT 'never',
  parenttaskid UUID,
  createdat TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  householdid UUID
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Create policies for profiles
CREATE POLICY "Users can view all profiles"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = authuserid);

CREATE POLICY "Users can insert their own profile"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = authuserid);

-- Create policies for tasks
CREATE POLICY "Users can view all tasks"
  ON tasks FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert their own tasks"
  ON tasks FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update their own tasks"
  ON tasks FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Users can delete their own tasks"
  ON tasks FOR DELETE
  TO authenticated
  USING (true);

-- Update indexes to include the new column
DROP INDEX IF EXISTS idx_tasks_userid;
CREATE INDEX idx_tasks_userid_householdid ON tasks(userid, householdid);

-- Add foreign key constraint if households table exists
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'households') THEN
        ALTER TABLE tasks 
        ADD CONSTRAINT fk_tasks_household 
        FOREIGN KEY (householdid) 
        REFERENCES households(id) 
        ON DELETE SET NULL;
    END IF;
END
$$; 
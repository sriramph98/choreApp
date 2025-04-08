-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY,
  authUserId UUID REFERENCES auth.users(id) NOT NULL,
  name TEXT NOT NULL,
  avatarSystemName TEXT NOT NULL,
  color TEXT NOT NULL,
  createdAt TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create tasks table
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY,
  userId UUID NOT NULL,
  name TEXT NOT NULL,
  dueDate TEXT NOT NULL,
  isCompleted BOOLEAN DEFAULT FALSE,
  assignedTo UUID,
  notes TEXT,
  repeatOption TEXT DEFAULT 'never',
  parentTaskId UUID,
  createdAt TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Create policies for profiles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE tablename = 'profiles' AND policyname = 'Users can view all profiles'
  ) THEN
    CREATE POLICY "Users can view all profiles"
      ON profiles FOR SELECT
      TO authenticated
      USING (true);
  END IF;
  
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE tablename = 'profiles' AND policyname = 'Users can update their own profile'
  ) THEN
    CREATE POLICY "Users can update their own profile"
      ON profiles FOR UPDATE
      TO authenticated
      USING (auth.uid() = authUserId);
  END IF;
  
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE tablename = 'profiles' AND policyname = 'Users can insert their own profile'
  ) THEN
    CREATE POLICY "Users can insert their own profile"
      ON profiles FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = authUserId);
  END IF;
END
$$;

-- Create policies for tasks
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE tablename = 'tasks' AND policyname = 'Users can view all tasks'
  ) THEN
    CREATE POLICY "Users can view all tasks"
      ON tasks FOR SELECT
      TO authenticated
      USING (true);
  END IF;
  
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE tablename = 'tasks' AND policyname = 'Users can insert their own tasks'
  ) THEN
    CREATE POLICY "Users can insert their own tasks"
      ON tasks FOR INSERT
      TO authenticated
      WITH CHECK (true);
  END IF;
  
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE tablename = 'tasks' AND policyname = 'Users can update their own tasks'
  ) THEN
    CREATE POLICY "Users can update their own tasks"
      ON tasks FOR UPDATE
      TO authenticated
      USING (true);
  END IF;
  
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE tablename = 'tasks' AND policyname = 'Users can delete their own tasks'
  ) THEN
    CREATE POLICY "Users can delete their own tasks"
      ON tasks FOR DELETE
      TO authenticated
      USING (true);
  END IF;
END
$$; 
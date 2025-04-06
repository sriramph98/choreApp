# Homie App with Supabase Integration

This iOS application helps you manage tasks and chores, with cloud synchronization using Supabase.

## Supabase Setup

To use the Supabase integration, follow these steps:

1. Create a Supabase account at https://supabase.io
2. Create a new Supabase project
3. In the Supabase dashboard, go to SQL Editor
4. Copy the contents of the `Chore/Migrations/supabase_tables.sql` file and run it in the SQL Editor to create the necessary tables
5. In the Supabase dashboard, go to Settings > API to get your:
   - Project URL
   - Project API Key (anon public key)
6. Update the `SupabaseManager.swift` file with your project URL and API key:
   ```swift
   private let supabaseURL = "YOUR_SUPABASE_URL"
   private let supabaseKey = "YOUR_SUPABASE_ANON_KEY"
   ```

## Authentication

The app uses Supabase for authentication. Users can:
- Sign up with email and password
- Sign in with email and password
- Sign in with Google (requires additional OAuth configuration in Supabase)

## Data Sync

When logged in, the app will automatically:
- Sync tasks between devices
- Sync user profiles
- Sync custom chore templates

## Development

This is an Xcode project. To get started:
1. Clone the repository
2. Open `Chore.xcodeproj` in Xcode
3. Install the required dependencies using Swift Package Manager
4. Configure your Supabase credentials as described above
5. Build and run the project 
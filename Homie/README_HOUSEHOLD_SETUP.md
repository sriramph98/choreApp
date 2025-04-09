# Households Setup for Homie App

This document explains how to set up the households feature in the Homie app, which allows users to create and manage households with multiple members.

## Fixing the "Failed to create household" Error

If you're experiencing an error when trying to create a new household, it's likely because the `households` table doesn't exist in your Supabase database. Follow these steps to resolve the issue:

### 1. Run the Households Table Migration Script

Navigate to the Supabase Studio for your project and run the SQL script from:
`Homie/Migrations/create_households_table.sql`

This script creates:
- The `households` table with all required columns
- Appropriate indexes for performance
- Row-Level Security (RLS) policies
- Relations to the tasks table

### 2. Verify the Table Structure

After running the migration, check that the `households` table has been created with the following columns:
- `id` (UUID, Primary Key)
- `name` (TEXT)
- `creatorid` (UUID referencing auth.users)
- `members` (UUID[] - an array of UUIDs)
- `createdat` (TIMESTAMP)

### 3. Ensure Column Names Match Exactly

The column names in the database must exactly match what the app expects:
- `creatorid` (not creator_id or creatorID)
- `createdat` (not created_at or createdAt)
- `members` (an array type column)

## Common Issues and Solutions

### Missing Table

**Symptoms:**
- "Failed to create household" error
- 404 errors in the logs when attempting to access the households table

**Solution:**
Run the SQL migration script as described above.

### Auth Issues

**Symptoms:**
- "Failed to create household" error with 401 or 403 status codes in logs

**Solution:**
Ensure the RLS policies are set correctly with the script. Check that the user has:
1. Successfully authenticated (logged in)
2. Has a valid user profile

### Data Type Issues

**Symptoms:**
- Error creating households with 400 status code
- Error messages about invalid column types

**Solution:**
Ensure the `members` column is defined as an array type (UUID[]).

## Testing the Household Feature

After setting up the table, you should be able to:
1. Create a new household
2. Invite members to your household
3. See tasks associated with your household
4. Switch between different households

## Troubleshooting Logs

Enable verbose logging in the app by adding these lines to the beginning of `viewDidLoad()` in the `AppDelegate.swift` file:

```swift
// Set up debug logging
UserDefaults.standard.set(true, forKey: "enableVerboseLogging")
```

This will display detailed information about household operations in the console.

## Contact Support

If you continue experiencing issues after following these steps, please contact support with:
1. Screenshots of the error
2. Console logs from the app
3. Your Supabase project configuration details 
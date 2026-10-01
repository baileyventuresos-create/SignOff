# SignOff Backend

Supabase project ref: `ltswgpiwsgjfhuqjiczo`

The canonical database schema lives in `supabase/migrations/`.

## Environment

Copy `.env.example` to `.env.local` and supply the project's publishable/anon key locally or in the deployment provider. Never commit service-role keys.

## Core model

- businesses: tenant/workspace
- business_memberships: users and roles
- approvals: approval-gated proposed actions
- approval_events: immutable action/audit history

All application tables have Row Level Security enabled.

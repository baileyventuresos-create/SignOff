-- SignOff core multi-tenant schema
-- Applied to Supabase project ltswgpiwsgjfhuqjiczo on 2026-10-01.
-- Keep secrets out of source control.

create extension if not exists pgcrypto;

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  created_by uuid not null references auth.users(id) on delete restrict,
  brand_config jsonb not null default '{}'::jsonb,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.business_memberships (
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','member')),
  created_at timestamptz not null default now(),
  primary key (business_id,user_id)
);

create table public.approvals (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  type text not null check (type in ('email_reply','scheduling','social_post','graphic','marketing_campaign','booking','other')),
  title text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled','completed')),
  payload jsonb not null default '{}'::jsonb,
  proposed_action jsonb not null default '{}'::jsonb,
  requested_by uuid references auth.users(id) on delete set null,
  decided_by uuid references auth.users(id) on delete set null,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.approval_events (
  id bigint generated always as identity primary key,
  approval_id uuid not null references public.approvals(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  event_type text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index business_memberships_user_idx on public.business_memberships(user_id);
create index businesses_created_by_idx on public.businesses(created_by);
create index approvals_business_status_created_idx on public.approvals(business_id,status,created_at desc);
create index approvals_requested_by_idx on public.approvals(requested_by);
create index approvals_decided_by_idx on public.approvals(decided_by);
create index approval_events_approval_created_idx on public.approval_events(approval_id,created_at);
create index approval_events_business_idx on public.approval_events(business_id);
create index approval_events_actor_idx on public.approval_events(actor_id);

alter table public.businesses enable row level security;
alter table public.business_memberships enable row level security;
alter table public.approvals enable row level security;
alter table public.approval_events enable row level security;

create policy "members read businesses" on public.businesses for select to authenticated using (
 created_by=(select auth.uid()) or exists(select 1 from public.business_memberships m where m.business_id=businesses.id and m.user_id=(select auth.uid()))
);
create policy "users create businesses" on public.businesses for insert to authenticated with check (created_by=(select auth.uid()));
create policy "owners update businesses" on public.businesses for update to authenticated
using (created_by=(select auth.uid()) or exists(select 1 from public.business_memberships m where m.business_id=businesses.id and m.user_id=(select auth.uid()) and m.role in ('owner','admin')))
with check (created_by=(select auth.uid()) or exists(select 1 from public.business_memberships m where m.business_id=businesses.id and m.user_id=(select auth.uid()) and m.role in ('owner','admin')));

create policy "members read own membership" on public.business_memberships for select to authenticated using (user_id=(select auth.uid()));
create policy "business creator adds memberships" on public.business_memberships for insert to authenticated with check (exists(select 1 from public.businesses b where b.id=business_memberships.business_id and b.created_by=(select auth.uid())));
create policy "business creator manages memberships" on public.business_memberships for update to authenticated using (exists(select 1 from public.businesses b where b.id=business_memberships.business_id and b.created_by=(select auth.uid()))) with check (exists(select 1 from public.businesses b where b.id=business_memberships.business_id and b.created_by=(select auth.uid())));
create policy "business creator deletes memberships" on public.business_memberships for delete to authenticated using (exists(select 1 from public.businesses b where b.id=business_memberships.business_id and b.created_by=(select auth.uid())));

create policy "members read approvals" on public.approvals for select to authenticated using (
 exists(select 1 from public.business_memberships m where m.business_id=approvals.business_id and m.user_id=(select auth.uid()))
 or exists(select 1 from public.businesses b where b.id=approvals.business_id and b.created_by=(select auth.uid()))
);
create policy "members create approvals" on public.approvals for insert to authenticated with check (
 requested_by=(select auth.uid()) and (
 exists(select 1 from public.business_memberships m where m.business_id=approvals.business_id and m.user_id=(select auth.uid()))
 or exists(select 1 from public.businesses b where b.id=approvals.business_id and b.created_by=(select auth.uid())))
);
create policy "members update approvals" on public.approvals for update to authenticated using (
 exists(select 1 from public.business_memberships m where m.business_id=approvals.business_id and m.user_id=(select auth.uid()))
 or exists(select 1 from public.businesses b where b.id=approvals.business_id and b.created_by=(select auth.uid()))
) with check (
 exists(select 1 from public.business_memberships m where m.business_id=approvals.business_id and m.user_id=(select auth.uid()))
 or exists(select 1 from public.businesses b where b.id=approvals.business_id and b.created_by=(select auth.uid()))
);

create policy "members read approval events" on public.approval_events for select to authenticated using (
 exists(select 1 from public.business_memberships m where m.business_id=approval_events.business_id and m.user_id=(select auth.uid()))
 or exists(select 1 from public.businesses b where b.id=approval_events.business_id and b.created_by=(select auth.uid()))
);
create policy "members create approval events" on public.approval_events for insert to authenticated with check (
 actor_id=(select auth.uid()) and (
 exists(select 1 from public.business_memberships m where m.business_id=approval_events.business_id and m.user_id=(select auth.uid()))
 or exists(select 1 from public.businesses b where b.id=approval_events.business_id and b.created_by=(select auth.uid())))
);

grant select,insert,update on public.businesses to authenticated;
grant select,insert,update,delete on public.business_memberships to authenticated;
grant select,insert,update on public.approvals to authenticated;
grant select,insert on public.approval_events to authenticated;
grant usage,select on sequence public.approval_events_id_seq to authenticated;

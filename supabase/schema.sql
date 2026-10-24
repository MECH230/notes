-- =====================================================================
-- MECH230 notes: database schema for student login and activity logs
-- =====================================================================
-- Run this whole file once in Supabase: Dashboard -> SQL Editor -> New
-- query -> paste -> Run. It is safe to run again; it will not delete data.
--
-- What it creates
--   allowed_domains  email domains allowed to sign in (edit to change)
--   profiles         one row per user: email, role (student/instructor)
--   tutor_messages   questions asked to the AI tutor and its answers (Phase 4)
--   quiz_answers     answers to quiz questions (Phase 5)
--   code_runs        code submitted in runnable cells (Phase 6)
--
-- Security (row-level security):
--   * Only addresses on allowed_domains can create an account.
--   * A student can read and add only their own rows.
--   * An instructor can read everyone's rows.
--   * Nobody can edit or delete rows from the website.
--
-- To make yourself an instructor, after you have signed in once, run:
--   update public.profiles set role = 'instructor' where email = 'you@aub.edu.lb';
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Allowed email domains
-- ---------------------------------------------------------------------
create table if not exists public.allowed_domains (
  domain text primary key check (domain = lower(domain))
);

insert into public.allowed_domains (domain) values
  ('mail.aub.edu'),      -- AUB students
  ('aub.edu.lb')         -- AUB staff and faculty
on conflict do nothing;

alter table public.allowed_domains enable row level security;
-- No policies: the website cannot read or change this table.


create or replace function public.email_domain_allowed(addr text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.allowed_domains d
    where lower(split_part(addr, '@', 2)) = d.domain
  );
$$;


-- ---------------------------------------------------------------------
-- 2. Block sign-ups from other domains
-- ---------------------------------------------------------------------
-- Runs inside Supabase Auth before a new account is saved. An address
-- from another domain gets an error and no account is created.
create or replace function public.check_signup_domain()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is null or not public.email_domain_allowed(new.email) then
    raise exception 'Please sign in with your AUB email address.'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists check_signup_domain on auth.users;
create trigger check_signup_domain
  before insert on auth.users
  for each row execute function public.check_signup_domain();


-- ---------------------------------------------------------------------
-- 3. Profiles
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  email      text not null,
  role       text not null default 'student'
             check (role in ('student', 'instructor')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Create a profile automatically when someone signs in for the first time.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, lower(new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Is the current user an instructor? (security definer avoids a loop
-- between the profiles policies and this check)
create or replace function public.is_instructor()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'instructor'
  );
$$;

drop policy if exists "read own profile or instructor" on public.profiles;
create policy "read own profile or instructor"
  on public.profiles for select
  to authenticated
  using (id = (select auth.uid()) or public.is_instructor());
-- No insert/update/delete policies: profiles are created by the trigger
-- above, and roles are changed only from the SQL Editor.


-- ---------------------------------------------------------------------
-- 4. Activity tables
-- ---------------------------------------------------------------------
-- Every row records who (user_id), where on the site (page) and when.
-- user_id is filled in automatically from the signed-in user.

create table if not exists public.tutor_messages (
  id          bigint generated always as identity primary key,
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  page        text,
  question    text not null check (char_length(question) <= 4000),
  answer      text,
  model       text,
  input_tokens  integer,
  output_tokens integer,
  created_at  timestamptz not null default now()
);

create table if not exists public.quiz_answers (
  id          bigint generated always as identity primary key,
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  page        text,
  question_id text not null,
  answer      jsonb not null,
  correct     boolean,
  attempt     integer,
  created_at  timestamptz not null default now()
);

create table if not exists public.code_runs (
  id          bigint generated always as identity primary key,
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  page        text,
  exercise_id text not null,
  kind        text not null default 'run' check (kind in ('run', 'submit')),
  code        text not null check (char_length(code) <= 20000),
  output      text check (char_length(output) <= 20000),
  correct     boolean,
  created_at  timestamptz not null default now()
);

create index if not exists tutor_messages_user_idx on public.tutor_messages (user_id, created_at);
create index if not exists quiz_answers_user_idx   on public.quiz_answers (user_id, created_at);
create index if not exists code_runs_user_idx      on public.code_runs (user_id, created_at);

alter table public.tutor_messages enable row level security;
alter table public.quiz_answers   enable row level security;
alter table public.code_runs      enable row level security;

-- Read: your own rows, or everything if you are an instructor.
drop policy if exists "read own or instructor" on public.tutor_messages;
create policy "read own or instructor" on public.tutor_messages
  for select to authenticated
  using (user_id = (select auth.uid()) or public.is_instructor());

drop policy if exists "read own or instructor" on public.quiz_answers;
create policy "read own or instructor" on public.quiz_answers
  for select to authenticated
  using (user_id = (select auth.uid()) or public.is_instructor());

drop policy if exists "read own or instructor" on public.code_runs;
create policy "read own or instructor" on public.code_runs
  for select to authenticated
  using (user_id = (select auth.uid()) or public.is_instructor());

-- Write: students add their own quiz answers and code runs.
-- Tutor messages are written only by the tutor function (Phase 4),
-- which uses the private service key, so there is no insert policy here.
drop policy if exists "insert own" on public.quiz_answers;
create policy "insert own" on public.quiz_answers
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "insert own" on public.code_runs;
create policy "insert own" on public.code_runs
  for insert to authenticated
  with check (user_id = (select auth.uid()));


-- ---------------------------------------------------------------------
-- 5. End-of-semester cleanup (run by hand when you want)
-- ---------------------------------------------------------------------
-- Deletes all activity older than the given date, keeping accounts:
--   select public.purge_activity_before('2027-02-01');
create or replace function public.purge_activity_before(cutoff timestamptz)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.tutor_messages where created_at < cutoff;
  delete from public.quiz_answers   where created_at < cutoff;
  delete from public.code_runs      where created_at < cutoff;
$$;
revoke execute on function public.purge_activity_before(timestamptz) from public, anon, authenticated;

-- Helper functions are for the database's own use, not callable from the website.
revoke execute on function public.email_domain_allowed(text) from public, anon, authenticated;
revoke execute on function public.check_signup_domain() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

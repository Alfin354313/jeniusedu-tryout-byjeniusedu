begin;
-- Jenius Tryout schema, designed for a dedicated Supabase project.
-- Review in staging first. Does not modify panel-baru or existing tables.

create table if not exists public.jt_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check (char_length(display_name) between 1 and 100),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.jt_categories (
 id uuid primary key default gen_random_uuid(), slug text not null unique, title text not null,
 description text, is_published boolean not null default false, created_at timestamptz not null default now()
);
create table if not exists public.jt_exams (
 id uuid primary key default gen_random_uuid(), category_id uuid not null references public.jt_categories(id),
 title text not null, duration_minutes integer not null check(duration_minutes between 1 and 360),
 starts_at timestamptz, ends_at timestamptz, is_published boolean not null default false,
 created_at timestamptz not null default now(),
 constraint jt_exam_schedule_valid check (starts_at is null or ends_at is null or ends_at > starts_at)
);
create table if not exists public.jt_questions (
 id uuid primary key default gen_random_uuid(), exam_id uuid not null references public.jt_exams(id) on delete cascade,
 position integer not null check(position > 0), prompt text not null,
 options jsonb not null check(jsonb_typeof(options)='array' and jsonb_array_length(options) between 2 and 8),
 correct_option integer not null check(correct_option >= 0 and correct_option < jsonb_array_length(options)),
 explanation text, unique(exam_id,position)
);
create table if not exists public.jt_attempts (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 exam_id uuid not null references public.jt_exams(id), started_at timestamptz not null default now(),
 submitted_at timestamptz, score numeric(6,2),
 constraint jt_attempt_score_range check(score is null or score between 0 and 100),
 constraint jt_attempt_finish_valid check(submitted_at is null or submitted_at >= started_at)
);
create table if not exists public.jt_answers (
 attempt_id uuid not null references public.jt_attempts(id) on delete cascade,
 question_id uuid not null references public.jt_questions(id), selected_option integer,
 updated_at timestamptz not null default now(), primary key(attempt_id,question_id)
);
create table if not exists public.jt_orders (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 exam_id uuid references public.jt_exams(id), amount_idr bigint not null check(amount_idr >= 0),
 status text not null default 'pending' check(status in ('pending','paid','expired','cancelled','refunded')),
 provider_reference text unique, created_at timestamptz not null default now(), paid_at timestamptz
);
create index if not exists jt_attempts_user_idx on public.jt_attempts(user_id,started_at desc);
create index if not exists jt_orders_user_idx on public.jt_orders(user_id,created_at desc);
create index if not exists jt_questions_exam_idx on public.jt_questions(exam_id,position);

alter table public.jt_profiles enable row level security;
alter table public.jt_categories enable row level security;
alter table public.jt_exams enable row level security;
alter table public.jt_questions enable row level security;
alter table public.jt_attempts enable row level security;
alter table public.jt_answers enable row level security;
alter table public.jt_orders enable row level security;

-- Only profile data is user-editable. All scoring, exam attempts, answer submission,
-- payment status changes, and admin actions MUST run in trusted server code.
drop policy if exists jt_profiles_read_own on public.jt_profiles;
create policy jt_profiles_read_own on public.jt_profiles for select to authenticated using (user_id=(select auth.uid()));
drop policy if exists jt_profiles_insert_own on public.jt_profiles;
create policy jt_profiles_insert_own on public.jt_profiles for insert to authenticated with check (user_id=(select auth.uid()));
drop policy if exists jt_profiles_update_own on public.jt_profiles;
create policy jt_profiles_update_own on public.jt_profiles for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
drop policy if exists jt_categories_public on public.jt_categories;
create policy jt_categories_public on public.jt_categories for select to anon,authenticated using (is_published);
drop policy if exists jt_exams_public on public.jt_exams;
create policy jt_exams_public on public.jt_exams for select to anon,authenticated using (is_published);
drop policy if exists jt_attempts_read_own on public.jt_attempts;
create policy jt_attempts_read_own on public.jt_attempts for select to authenticated using (user_id=(select auth.uid()));
drop policy if exists jt_orders_read_own on public.jt_orders;
create policy jt_orders_read_own on public.jt_orders for select to authenticated using (user_id=(select auth.uid()));
-- No SELECT policy for jt_questions or jt_answers: correct_option and explanation
-- must never be exposed during an active exam. Server endpoints should return
-- sanitized question options and verify ownership, time limits, eligibility.
-- No client INSERT/UPDATE policies for attempts, answers, or orders.

-- IMPORTANT: privileged server routes must verify Supabase JWT and use a server-side
-- service-role key ONLY in server environment variables, never in frontend JavaScript.
-- Payment status must only change after verifying a provider webhook signature.

-- Shared panel authorization from trusted app_metadata only.
create or replace function public.jt_is_admin() returns boolean
language sql stable set search_path=public,pg_temp
as $$ select lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) in ('admin','pengelola','administrator') $$;
revoke all on function public.jt_is_admin() from public,anon;
grant execute on function public.jt_is_admin() to authenticated;
create table if not exists public.jt_enrollments(
 user_id uuid not null references auth.users(id) on delete cascade,
 exam_id uuid not null references public.jt_exams(id) on delete cascade,
 status text not null default 'active' check(status in ('active','cancelled')),
 created_at timestamptz not null default now(),primary key(user_id,exam_id)
);
alter table public.jt_enrollments enable row level security;
drop policy if exists jt_enrollments_own on public.jt_enrollments;
create policy jt_enrollments_own on public.jt_enrollments for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists jt_enrollments_admin on public.jt_enrollments;
create policy jt_enrollments_admin on public.jt_enrollments for all to authenticated using((select public.jt_is_admin())) with check((select public.jt_is_admin()));
do $$ declare t text; begin
 foreach t in array array['jt_categories','jt_exams','jt_questions'] loop
  execute format('drop policy if exists jt_admin_manage on public.%I',t);
  execute format('create policy jt_admin_manage on public.%I for all to authenticated using ((select public.jt_is_admin())) with check ((select public.jt_is_admin()))',t);
 end loop;
 foreach t in array array['jt_profiles','jt_attempts','jt_orders'] loop
  execute format('drop policy if exists jt_admin_read on public.%I',t);
  execute format('create policy jt_admin_read on public.%I for select to authenticated using ((select public.jt_is_admin()))',t);
 end loop;
end $$;
grant select on public.jt_categories,public.jt_exams to anon,authenticated;
grant select,insert,update on public.jt_profiles to authenticated;
grant select on public.jt_attempts,public.jt_orders to authenticated;
grant select,insert,update,delete on public.jt_categories,public.jt_exams,public.jt_questions,public.jt_enrollments to authenticated;
-- Participants still have NO question SELECT policy, no grading/order/attempt write.
commit;

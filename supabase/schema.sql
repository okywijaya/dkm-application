-- DKM Masjid: identitas, verifikasi, dan isolasi tenant.
create extension if not exists pgcrypto;

create table if not exists public.masjids (
  id uuid primary key default gen_random_uuid(), name text not null, address text not null,
  phone text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.app_users (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete cascade,
  masjid_id uuid references public.masjids(id) on update cascade on delete restrict,
  full_name text not null, email text not null unique, phone text,
  role text not null default 'operator' check (role in ('super_administrator','administrator','pengurus','operator')),
  verification_status text not null default 'pending' check (verification_status in ('pending','verified','rejected','inactive')),
  verified_at timestamptz, verified_by uuid references auth.users(id) on delete set null,
  rejection_reason text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

-- Kolom migrasi untuk instalasi yang sudah memakai skema versi awal.
alter table public.app_users add column if not exists auth_user_id uuid unique references auth.users(id) on delete cascade;
alter table public.app_users alter column masjid_id drop not null;
alter table public.app_users add column if not exists verification_status text not null default 'pending';
alter table public.app_users add column if not exists verified_at timestamptz;
alter table public.app_users add column if not exists verified_by uuid references auth.users(id) on delete set null;
alter table public.app_users add column if not exists rejection_reason text;
alter table public.app_users drop constraint if exists app_users_role_check;
update public.app_users set role = lower(role) where role in ('Administrator','Pengurus','Operator');
alter table public.app_users add constraint app_users_role_check check (role in ('super_administrator','administrator','pengurus','operator'));
alter table public.app_users drop constraint if exists app_users_verification_status_check;
alter table public.app_users add constraint app_users_verification_status_check check (verification_status in ('pending','verified','rejected','inactive'));
update public.app_users u set auth_user_id = a.id from auth.users a
where u.auth_user_id is null and lower(u.email) = lower(a.email);

-- Backfill akun Auth lama yang dibuat sebelum trigger profil dipasang.
insert into public.app_users (auth_user_id,masjid_id,full_name,email,role,verification_status)
select
  a.id,
  null,
  coalesce(nullif(a.raw_user_meta_data ->> 'full_name',''),split_part(a.email,'@',1)),
  a.email,
  'operator',
  'pending'
from auth.users a
where a.email is not null
  and not exists (select 1 from public.app_users u where u.auth_user_id = a.id or lower(u.email) = lower(a.email));

create table if not exists public.majelis (
  id uuid primary key default gen_random_uuid(), masjid_id uuid not null references public.masjids(id) on update cascade on delete restrict,
  name text not null, type text not null check (type in ('TPQ','Majelis Taklim')), leader text, description text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique (masjid_id,name)
);

create table if not exists public.anggota (
  id uuid primary key default gen_random_uuid(), masjid_id uuid not null references public.masjids(id) on update cascade on delete restrict,
  majelis_id uuid not null references public.majelis(id) on update cascade on delete restrict,
  name text not null, birth_date date not null, gender text not null check (gender in ('Laki-laki','Perempuan')),
  address text not null, member_role text not null default 'murid' check (member_role in ('pengajar','murid')),
  membership_status text not null default 'active' check (membership_status in ('active','inactive','graduated')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

-- Master Al-Qur'an dan catatan murojaah.
create table if not exists public.quran_surahs (
  number smallint primary key check (number between 1 and 114), name text not null,
  arabic_name text, ayah_count smallint not null check (ayah_count > 0), updated_at timestamptz not null default now()
);
create table if not exists public.quran_ayahs (
  id bigint generated always as identity primary key,
  surah_number smallint not null references public.quran_surahs(number) on update cascade on delete cascade,
  ayah_number smallint not null check (ayah_number > 0), arabic_text text not null, translation text,
  unique (surah_number, ayah_number)
);
create table if not exists public.murojaah_records (
  id uuid primary key default gen_random_uuid(),
  masjid_id uuid not null references public.masjids(id) on update cascade on delete restrict,
  anggota_id uuid not null references public.anggota(id) on update cascade on delete restrict,
  surah_number smallint not null check (surah_number between 1 and 114),
  ayah_start smallint not null check (ayah_start > 0), ayah_end smallint not null check (ayah_end >= ayah_start),
  review_date date not null default current_date,
  result text not null check (result in ('lancar','ulang','belum_lancar')), notes text,
  recorded_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create index if not exists idx_murojaah_masjid on public.murojaah_records(masjid_id);
create index if not exists idx_murojaah_anggota on public.murojaah_records(anggota_id);
create index if not exists idx_murojaah_date on public.murojaah_records(review_date desc);
alter table public.anggota add column if not exists member_role text;
alter table public.anggota add column if not exists membership_status text not null default 'active';
do $$ begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'anggota' and column_name = 'status') then
    execute 'update public.anggota set member_role = lower(status) where member_role is null and status in (''Pengajar'',''Murid'')';
  end if;
end $$;
update public.anggota set member_role = 'murid' where member_role is null;
alter table public.anggota alter column member_role set not null;
alter table public.anggota drop constraint if exists anggota_member_role_check;
alter table public.anggota add constraint anggota_member_role_check check (member_role in ('pengajar','murid'));
alter table public.anggota drop constraint if exists anggota_membership_status_check;
alter table public.anggota add constraint anggota_membership_status_check check (membership_status in ('active','inactive','graduated'));
alter table public.anggota drop column if exists status;

create index if not exists idx_app_users_auth on public.app_users(auth_user_id);
create index if not exists idx_app_users_masjid on public.app_users(masjid_id);
create index if not exists idx_majelis_masjid on public.majelis(masjid_id);
create index if not exists idx_anggota_masjid on public.anggota(masjid_id);
create index if not exists idx_anggota_majelis on public.anggota(majelis_id);

create or replace function public.set_updated_at() returns trigger language plpgsql security invoker set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;
do $$ declare t text; begin foreach t in array array['masjids','app_users','majelis','anggota'] loop
  execute format('drop trigger if exists set_%I_updated_at on public.%I',t,t);
  execute format('create trigger set_%I_updated_at before update on public.%I for each row execute function public.set_updated_at()',t,t);
end loop; end $$;

-- Profil aplikasi dibuat otomatis saat akun Auth dibuat.
create or replace function public.handle_new_auth_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare requested_masjid uuid;
begin
  begin requested_masjid := nullif(new.raw_user_meta_data ->> 'masjid_id','')::uuid;
  exception when invalid_text_representation then requested_masjid := null; end;
  insert into public.app_users (auth_user_id,masjid_id,full_name,email,role,verification_status)
  values (new.id,requested_masjid,coalesce(nullif(new.raw_user_meta_data ->> 'full_name',''),split_part(new.email,'@',1)),new.email,'operator','pending')
  on conflict (email) do update set auth_user_id = excluded.auth_user_id;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_auth_user();

create or replace function public.audit_user_verification() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if new.verification_status = 'verified' and old.verification_status is distinct from 'verified' then
    new.verified_at := now(); new.verified_by := auth.uid(); new.rejection_reason := null;
  elsif new.verification_status <> 'verified' then new.verified_at := null; new.verified_by := null; end if;
  return new;
end; $$;
drop trigger if exists audit_app_user_verification on public.app_users;
create trigger audit_app_user_verification before update of verification_status on public.app_users
for each row execute function public.audit_user_verification();

-- SECURITY DEFINER mencegah rekursi saat policy app_users membaca profil aktif.
create or replace function public.current_masjid_id() returns uuid language sql stable security definer set search_path = '' as $$
select masjid_id from public.app_users where auth_user_id = auth.uid() and verification_status = 'verified' limit 1 $$;
create or replace function public.current_app_role() returns text language sql stable security definer set search_path = '' as $$
select role from public.app_users where auth_user_id = auth.uid() and verification_status = 'verified' limit 1 $$;
create or replace function public.is_super_administrator() returns boolean language sql stable security definer set search_path = '' as $$
select exists(select 1 from public.app_users where auth_user_id = auth.uid() and verification_status = 'verified' and role = 'super_administrator') $$;
create or replace function public.can_manage_murojaah(target_masjid_id uuid, target_anggota_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
select exists (
  select 1
  from public.app_users u
  join public.anggota a on a.id = target_anggota_id and a.masjid_id = target_masjid_id
  where u.auth_user_id = auth.uid()
    and u.verification_status = 'verified'
    and u.role in ('super_administrator','administrator','pengurus','operator')
    and (u.role = 'super_administrator' or u.masjid_id = target_masjid_id)
) $$;
revoke all on function public.current_masjid_id() from public; grant execute on function public.current_masjid_id() to authenticated;
revoke all on function public.current_app_role() from public; grant execute on function public.current_app_role() to authenticated;
revoke all on function public.is_super_administrator() from public; grant execute on function public.is_super_administrator() to authenticated;
revoke all on function public.can_manage_murojaah(uuid,uuid) from public; grant execute on function public.can_manage_murojaah(uuid,uuid) to authenticated;

alter table public.masjids enable row level security;
alter table public.app_users enable row level security;
alter table public.majelis enable row level security;
alter table public.anggota enable row level security;
alter table public.quran_surahs enable row level security;
alter table public.quran_ayahs enable row level security;
alter table public.murojaah_records enable row level security;
drop policy if exists "authenticated_manage_masjids" on public.masjids;
drop policy if exists "authenticated_manage_app_users" on public.app_users;
drop policy if exists "authenticated_manage_majelis" on public.majelis;
drop policy if exists "authenticated_manage_anggota" on public.anggota;
drop policy if exists "profile_read_self_or_same_masjid" on public.app_users;
drop policy if exists "admin_update_same_masjid_users" on public.app_users;
drop policy if exists "verified_read_own_masjid" on public.masjids;
drop policy if exists "admin_update_own_masjid" on public.masjids;
drop policy if exists "verified_read_majelis" on public.majelis;
drop policy if exists "staff_write_majelis" on public.majelis;
drop policy if exists "verified_read_anggota" on public.anggota;
drop policy if exists "staff_write_anggota" on public.anggota;
drop policy if exists "super_admin_read_all_users" on public.app_users;
drop policy if exists "super_admin_update_all_users" on public.app_users;
drop policy if exists "super_admin_manage_masjids" on public.masjids;
drop policy if exists "super_admin_manage_majelis" on public.majelis;
drop policy if exists "super_admin_manage_anggota" on public.anggota;

create policy "profile_read_self_or_same_masjid" on public.app_users for select to authenticated
using (auth_user_id = auth.uid() or (masjid_id = public.current_masjid_id() and public.current_app_role() = 'administrator'));
create policy "super_admin_read_all_users" on public.app_users for select to authenticated
using (public.is_super_administrator());
create policy "admin_update_same_masjid_users" on public.app_users for update to authenticated
using (masjid_id = public.current_masjid_id() and public.current_app_role() = 'administrator' and role <> 'super_administrator')
with check (masjid_id = public.current_masjid_id() and role <> 'super_administrator');
create policy "super_admin_update_all_users" on public.app_users for update to authenticated
using (public.is_super_administrator()) with check (public.is_super_administrator());
create policy "verified_read_own_masjid" on public.masjids for select to authenticated using (id = public.current_masjid_id());
create policy "admin_update_own_masjid" on public.masjids for update to authenticated
using (id = public.current_masjid_id() and public.current_app_role() = 'administrator') with check (id = public.current_masjid_id());
create policy "super_admin_manage_masjids" on public.masjids for all to authenticated
using (public.is_super_administrator()) with check (public.is_super_administrator());
create policy "verified_read_majelis" on public.majelis for select to authenticated using (masjid_id = public.current_masjid_id());
create policy "staff_write_majelis" on public.majelis for all to authenticated
using (masjid_id = public.current_masjid_id() and public.current_app_role() in ('administrator','pengurus'))
with check (masjid_id = public.current_masjid_id() and public.current_app_role() in ('administrator','pengurus'));
create policy "super_admin_manage_majelis" on public.majelis for all to authenticated
using (public.is_super_administrator()) with check (public.is_super_administrator());
create policy "verified_read_anggota" on public.anggota for select to authenticated using (masjid_id = public.current_masjid_id());
create policy "staff_write_anggota" on public.anggota for all to authenticated
using (masjid_id = public.current_masjid_id() and public.current_app_role() in ('administrator','pengurus','operator'))
with check (masjid_id = public.current_masjid_id() and public.current_app_role() in ('administrator','pengurus','operator'));

drop policy if exists "authenticated_read_surahs" on public.quran_surahs;
drop policy if exists "staff_manage_surahs" on public.quran_surahs;
drop policy if exists "authenticated_read_ayahs" on public.quran_ayahs;
drop policy if exists "staff_manage_ayahs" on public.quran_ayahs;
drop policy if exists "verified_read_murojaah" on public.murojaah_records;
drop policy if exists "staff_write_murojaah" on public.murojaah_records;
drop policy if exists "super_admin_read_murojaah" on public.murojaah_records;
create policy "authenticated_read_surahs" on public.quran_surahs for select to authenticated using (public.current_masjid_id() is not null);
create policy "staff_manage_surahs" on public.quran_surahs for all to authenticated
using (public.current_app_role() in ('super_administrator','administrator','pengurus'))
with check (public.current_app_role() in ('super_administrator','administrator','pengurus'));
create policy "authenticated_read_ayahs" on public.quran_ayahs for select to authenticated using (public.current_masjid_id() is not null);
create policy "staff_manage_ayahs" on public.quran_ayahs for all to authenticated
using (public.current_app_role() in ('super_administrator','administrator','pengurus'))
with check (public.current_app_role() in ('super_administrator','administrator','pengurus'));
create policy "verified_read_murojaah" on public.murojaah_records for select to authenticated using (masjid_id = public.current_masjid_id());
create policy "staff_write_murojaah" on public.murojaah_records for all to authenticated
using (public.can_manage_murojaah(masjid_id, anggota_id))
with check (public.can_manage_murojaah(masjid_id, anggota_id));
create policy "super_admin_read_murojaah" on public.murojaah_records for select to authenticated
using (public.is_super_administrator());
create policy "super_admin_manage_anggota" on public.anggota for all to authenticated
using (public.is_super_administrator()) with check (public.is_super_administrator());

-- Program pembelajaran, struktur bab, materi, dan progres murid.
create table if not exists public.learning_programs (
  id uuid primary key default gen_random_uuid(),
  masjid_id uuid not null references public.masjids(id) on update cascade on delete cascade,
  title text not null, description text, level text not null default 'Pemula',
  status text not null default 'draft' check (status in ('draft','published')),
  icon text default 'menu_book', created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.learning_chapters (
  id uuid primary key default gen_random_uuid(), program_id uuid not null references public.learning_programs(id) on delete cascade,
  title text not null, description text, position integer not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.learning_lessons (
  id uuid primary key default gen_random_uuid(), chapter_id uuid not null references public.learning_chapters(id) on delete cascade,
  title text not null, lesson_type text not null default 'Dokumen' check (lesson_type in ('Video','Dokumen','Audio','Latihan')),
  content text, duration_minutes integer not null default 0, storage_path text, position integer not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.learning_progress (
  id uuid primary key default gen_random_uuid(), anggota_id uuid not null references public.anggota(id) on delete cascade,
  lesson_id uuid not null references public.learning_lessons(id) on delete cascade,
  completed boolean not null default false, completed_at timestamptz, updated_at timestamptz not null default now(),
  unique (anggota_id, lesson_id)
);
create index if not exists idx_learning_programs_masjid on public.learning_programs(masjid_id);
create index if not exists idx_learning_chapters_program on public.learning_chapters(program_id,position);
create index if not exists idx_learning_lessons_chapter on public.learning_lessons(chapter_id,position);
create index if not exists idx_learning_progress_anggota on public.learning_progress(anggota_id);

do $$ declare t text; begin foreach t in array array['learning_programs','learning_chapters','learning_lessons','learning_progress'] loop
  execute format('drop trigger if exists set_%I_updated_at on public.%I',t,t);
  execute format('create trigger set_%I_updated_at before update on public.%I for each row execute function public.set_updated_at()',t,t);
end loop; end $$;

alter table public.learning_programs enable row level security;
alter table public.learning_chapters enable row level security;
alter table public.learning_lessons enable row level security;
alter table public.learning_progress enable row level security;
drop policy if exists "verified_read_learning_programs" on public.learning_programs;
drop policy if exists "staff_manage_learning_programs" on public.learning_programs;
drop policy if exists "verified_read_learning_chapters" on public.learning_chapters;
drop policy if exists "staff_manage_learning_chapters" on public.learning_chapters;
drop policy if exists "verified_read_learning_lessons" on public.learning_lessons;
drop policy if exists "staff_manage_learning_lessons" on public.learning_lessons;
drop policy if exists "verified_manage_learning_progress" on public.learning_progress;
create policy "verified_read_learning_programs" on public.learning_programs for select to authenticated
using (masjid_id = public.current_masjid_id() and (status = 'published' or public.current_app_role() in ('super_administrator','administrator','pengurus')));
create policy "staff_manage_learning_programs" on public.learning_programs for all to authenticated
using (masjid_id = public.current_masjid_id() and public.current_app_role() in ('super_administrator','administrator','pengurus'))
with check (masjid_id = public.current_masjid_id() and public.current_app_role() in ('super_administrator','administrator','pengurus'));
create policy "verified_read_learning_chapters" on public.learning_chapters for select to authenticated
using (exists (select 1 from public.learning_programs p where p.id = program_id and p.masjid_id = public.current_masjid_id()));
create policy "staff_manage_learning_chapters" on public.learning_chapters for all to authenticated
using (exists (select 1 from public.learning_programs p where p.id = program_id and p.masjid_id = public.current_masjid_id() and public.current_app_role() in ('super_administrator','administrator','pengurus')))
with check (exists (select 1 from public.learning_programs p where p.id = program_id and p.masjid_id = public.current_masjid_id() and public.current_app_role() in ('super_administrator','administrator','pengurus')));
create policy "verified_read_learning_lessons" on public.learning_lessons for select to authenticated
using (exists (select 1 from public.learning_chapters c join public.learning_programs p on p.id = c.program_id where c.id = chapter_id and p.masjid_id = public.current_masjid_id()));
create policy "staff_manage_learning_lessons" on public.learning_lessons for all to authenticated
using (exists (select 1 from public.learning_chapters c join public.learning_programs p on p.id = c.program_id where c.id = chapter_id and p.masjid_id = public.current_masjid_id() and public.current_app_role() in ('super_administrator','administrator','pengurus')))
with check (exists (select 1 from public.learning_chapters c join public.learning_programs p on p.id = c.program_id where c.id = chapter_id and p.masjid_id = public.current_masjid_id() and public.current_app_role() in ('super_administrator','administrator','pengurus')));
create policy "verified_manage_learning_progress" on public.learning_progress for all to authenticated
using (exists (select 1 from public.anggota a where a.id = anggota_id and a.masjid_id = public.current_masjid_id()))
with check (exists (select 1 from public.anggota a where a.id = anggota_id and a.masjid_id = public.current_masjid_id()));

-- Bucket privat untuk PDF, audio, video, dan dokumen materi.
insert into storage.buckets (id,name,public) values ('learning-materials','learning-materials',false)
on conflict (id) do update set public = false;
drop policy if exists "verified_read_learning_files" on storage.objects;
drop policy if exists "staff_manage_learning_files" on storage.objects;
create policy "verified_read_learning_files" on storage.objects for select to authenticated
using (bucket_id = 'learning-materials' and (storage.foldername(name))[1] = public.current_masjid_id()::text);
create policy "staff_manage_learning_files" on storage.objects for all to authenticated
using (bucket_id = 'learning-materials' and (storage.foldername(name))[1] = public.current_masjid_id()::text and public.current_app_role() in ('super_administrator','administrator','pengurus'))
with check (bucket_id = 'learning-materials' and (storage.foldername(name))[1] = public.current_masjid_id()::text and public.current_app_role() in ('super_administrator','administrator','pengurus'));

-- Bootstrap super administrator pertama setelah registrasi (jalankan sekali di SQL Editor):
-- update public.app_users set role='super_administrator', verification_status='verified'
-- where email='admin@contoh.id';

-- Evaluasi pilihan ganda, attempt, dan jawaban santri.
create table if not exists public.evaluations (
  id uuid primary key default gen_random_uuid(), masjid_id uuid not null references public.masjids(id) on delete cascade,
  title text not null, description text, passing_score smallint not null default 70 check (passing_score between 0 and 100),
  is_active boolean not null default true, created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.evaluation_questions (
  id uuid primary key default gen_random_uuid(), evaluation_id uuid not null references public.evaluations(id) on delete cascade,
  question_text text not null, position smallint not null check (position > 0), points smallint not null default 1 check (points > 0), unique (evaluation_id, position)
);
create table if not exists public.evaluation_options (
  id uuid primary key default gen_random_uuid(), question_id uuid not null references public.evaluation_questions(id) on delete cascade,
  option_text text not null, position smallint not null check (position > 0), is_correct boolean not null default false, unique (question_id, position)
);
create table if not exists public.evaluation_attempts (
  id uuid primary key default gen_random_uuid(), masjid_id uuid not null references public.masjids(id) on delete cascade,
  evaluation_id uuid not null references public.evaluations(id) on delete cascade, anggota_id uuid not null references public.anggota(id) on delete cascade,
  score smallint not null default 0 check (score between 0 and 100), correct_answers smallint not null default 0,
  total_questions smallint not null default 0, started_at timestamptz not null default now(), completed_at timestamptz
);
create table if not exists public.evaluation_answers (
  id uuid primary key default gen_random_uuid(), attempt_id uuid not null references public.evaluation_attempts(id) on delete cascade,
  question_id uuid not null references public.evaluation_questions(id) on delete cascade,
  selected_option_id uuid references public.evaluation_options(id) on delete set null, is_correct boolean not null default false,
  answered_at timestamptz not null default now(), unique (attempt_id, question_id)
);
create index if not exists idx_evaluations_masjid on public.evaluations(masjid_id);
create index if not exists idx_attempts_masjid on public.evaluation_attempts(masjid_id);
create index if not exists idx_attempts_anggota on public.evaluation_attempts(anggota_id);
alter table public.evaluations enable row level security;
alter table public.evaluation_questions enable row level security;
alter table public.evaluation_options enable row level security;
alter table public.evaluation_attempts enable row level security;
alter table public.evaluation_answers enable row level security;
drop policy if exists "tenant_evaluations" on public.evaluations;
drop policy if exists "tenant_questions" on public.evaluation_questions;
drop policy if exists "tenant_options" on public.evaluation_options;
drop policy if exists "tenant_attempts" on public.evaluation_attempts;
drop policy if exists "tenant_answers" on public.evaluation_answers;
create policy "tenant_evaluations" on public.evaluations for all to authenticated using (masjid_id=public.current_masjid_id()) with check (masjid_id=public.current_masjid_id());
create policy "tenant_questions" on public.evaluation_questions for all to authenticated using (exists(select 1 from public.evaluations e where e.id=evaluation_id and e.masjid_id=public.current_masjid_id())) with check (exists(select 1 from public.evaluations e where e.id=evaluation_id and e.masjid_id=public.current_masjid_id()));
create policy "tenant_options" on public.evaluation_options for all to authenticated using (exists(select 1 from public.evaluation_questions q join public.evaluations e on e.id=q.evaluation_id where q.id=question_id and e.masjid_id=public.current_masjid_id())) with check (exists(select 1 from public.evaluation_questions q join public.evaluations e on e.id=q.evaluation_id where q.id=question_id and e.masjid_id=public.current_masjid_id()));
create policy "tenant_attempts" on public.evaluation_attempts for all to authenticated using (masjid_id=public.current_masjid_id()) with check (masjid_id=public.current_masjid_id());
create policy "tenant_answers" on public.evaluation_answers for all to authenticated using (exists(select 1 from public.evaluation_attempts a where a.id=attempt_id and a.masjid_id=public.current_masjid_id())) with check (exists(select 1 from public.evaluation_attempts a where a.id=attempt_id and a.masjid_id=public.current_masjid_id()));

-- Run after 20261029_panel_integration.sql. Existing questions/history are retained.
begin;
create table if not exists public.jt_attempt_snapshots(
 attempt_id uuid primary key references public.jt_attempts(id) on delete cascade,
 questions jsonb not null, deadline timestamptz not null, reveal_at timestamptz not null,
 title text not null, revision bigint not null default 0
);
alter table public.jt_attempt_snapshots enable row level security;
revoke all on public.jt_attempt_snapshots from public,anon,authenticated;
create or replace function public.jt_exam_session(p_exam_id uuid,p_action text default 'get',p_answers jsonb default '[]',p_revision bigint default 0)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare a public.jt_attempts; e public.jt_exams; snap public.jt_attempt_snapshots; qs jsonb; item jsonb; q jsonb; selected integer; correct integer; result_questions jsonb; expired boolean; is_review boolean;
begin
 if auth.uid() is null then raise exception 'Silakan masuk ke akun peserta.'; end if;
 if p_action is null or p_action not in ('get','start','save','submit') then raise exception 'Aksi tidak valid.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_exam_id::text,0));
 select * into a from public.jt_attempts where exam_id=p_exam_id and user_id=auth.uid() order by started_at desc limit 1 for update;
 if a.id is null then
  if p_action<>'start' then raise exception 'Ujian belum dimulai.'; end if;
  select * into e from public.jt_exams where id=p_exam_id for share;
  if not found or not e.is_published or e.starts_at is null or e.ends_at is null then raise exception 'Paket atau jadwal belum diterbitkan.'; end if;
  if not exists(select 1 from public.jt_enrollments where user_id=auth.uid() and exam_id=p_exam_id and status='active') then raise exception 'Akun belum terdaftar aktif di paket ini.'; end if;
  if clock_timestamp()<e.starts_at or clock_timestamp()>=e.ends_at then raise exception 'Di luar jadwal ujian.'; end if;
  select jsonb_agg(jsonb_build_object('id',id,'position',position,'prompt',prompt,'options',options,'key',correct_option,'explanation',coalesce(explanation,'')) order by position) into qs from public.jt_questions where exam_id=p_exam_id;
  if qs is null or jsonb_array_length(qs)=0 then raise exception 'Paket belum memiliki soal.'; end if;
  if octet_length(qs::text)>8000000 then raise exception 'Paket melebihi batas 8 MB.'; end if;
  insert into public.jt_attempts(user_id,exam_id) values(auth.uid(),p_exam_id) returning * into a;
  insert into public.jt_attempt_snapshots(attempt_id,questions,deadline,reveal_at,title)
  values(a.id,qs,least(e.ends_at,a.started_at+make_interval(mins=>e.duration_minutes)),e.ends_at,e.title);
 end if;
 select * into snap from public.jt_attempt_snapshots where attempt_id=a.id for update;
 if not found then raise exception 'Riwayat lama belum memiliki snapshot ujian. Hubungi pengelola.'; end if;
 expired=clock_timestamp()>=snap.deadline;
 if a.submitted_at is null and p_action in ('save','submit') and not expired then
  if not exists(select 1 from public.jt_enrollments where user_id=auth.uid() and exam_id=p_exam_id and status='active') then raise exception 'Pendaftaran tidak aktif. Hubungi pengelola.'; end if;
  if p_revision is distinct from snap.revision then raise exception 'REVISION_CONFLICT: Jawaban diperbarui di tab lain. Muat ulang ujian.'; end if;
  if jsonb_typeof(p_answers) is distinct from 'array' then raise exception 'Jawaban tidak valid.'; end if;
  if jsonb_array_length(p_answers)>jsonb_array_length(snap.questions) or octet_length(p_answers::text)>100000 then raise exception 'Jawaban terlalu besar.'; end if;
  for item in select value from jsonb_array_elements(p_answers) loop
   select value into q from jsonb_array_elements(snap.questions) where value->>'id'=item->>'question_id';
   if q is null then raise exception 'Soal tidak termasuk ujian ini.'; end if;
   if jsonb_typeof(item->'selected_option') is distinct from 'number' or (item->>'selected_option') !~ '^[0-7]$' then raise exception 'Pilihan tidak valid.'; end if;
   selected=(item->>'selected_option')::integer;
   if selected>=jsonb_array_length(q->'options') then raise exception 'Pilihan tidak tersedia.'; end if;
   insert into public.jt_answers(attempt_id,question_id,selected_option) values(a.id,(q->>'id')::uuid,selected)
   on conflict(attempt_id,question_id) do update set selected_option=excluded.selected_option,updated_at=clock_timestamp();
  end loop;
  update public.jt_attempt_snapshots set revision=revision+1 where attempt_id=a.id returning * into snap;
 end if;
 if a.submitted_at is null and (expired or p_action='submit') then
  select count(*) into correct from jsonb_array_elements(snap.questions) as question_snapshot(value) join public.jt_answers ans on ans.attempt_id=a.id and ans.question_id=(question_snapshot.value->>'id')::uuid and ans.selected_option=(question_snapshot.value->>'key')::integer;
  update public.jt_attempts set submitted_at=greatest(started_at,least(clock_timestamp(),snap.deadline)),score=round(100.0*correct/jsonb_array_length(snap.questions),2) where id=a.id returning * into a;
 end if;
 is_review=a.submitted_at is not null and clock_timestamp()>=snap.reveal_at;
 select jsonb_agg(case when is_review then value else value-'key'-'explanation' end order by (value->>'position')::integer) into result_questions from jsonb_array_elements(snap.questions);
 return jsonb_build_object('attempt_id',a.id,'title',snap.title,'started_at',a.started_at,'deadline',snap.deadline,'server_now',clock_timestamp(),'submitted_at',a.submitted_at,'score',a.score,'revision',snap.revision,'review_available',is_review,'reveal_at',snap.reveal_at,'questions',result_questions,'answers',coalesce((select jsonb_agg(jsonb_build_object('question_id',question_id,'selected_option',selected_option)) from public.jt_answers where attempt_id=a.id),'[]'::jsonb));
end;
$$;
revoke all on function public.jt_exam_session(uuid,text,jsonb,bigint) from public,anon;
grant execute on function public.jt_exam_session(uuid,text,jsonb,bigint) to authenticated;
notify pgrst,'reload schema';
commit;

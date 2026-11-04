-- Vota3: esquema inicial do banco.
-- Execute no SQL Editor de um projeto Supabase NOVO.
-- Nenhuma tabela abaixo concede acesso público ou acesso direto aos eleitores.

create extension if not exists pgcrypto;

create table if not exists public.elections (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9-]{3,60}$'),
  status text not null default 'draft'
    check (status in ('draft','registration','ready','round_1','round_2','round_3','finished','cancelled')),
  current_round smallint not null default 0 check (current_round between 0 and 3),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.election_admins (
  election_id uuid not null references public.elections(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (election_id,user_id)
);

-- Ao criar uma eleição, o criador passa a ser seu primeiro administrador.
create or replace function public.add_creator_as_election_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.election_admins (election_id, user_id)
  values (new.id, new.created_by)
  on conflict do nothing;
  return new;
end;
$$;

create trigger trg_add_creator_as_election_admin
after insert on public.elections
for each row execute function public.add_creator_as_election_admin();

create table if not exists public.participants (
  id uuid primary key default gen_random_uuid(),
  election_id uuid not null references public.elections(id) on delete cascade,
  full_name text not null check (char_length(full_name) between 2 and 120),
  birth_date date not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  unique (election_id,id)
);

create table if not exists public.voter_credentials (
  id uuid primary key default gen_random_uuid(),
  election_id uuid not null,
  participant_id uuid not null,
  credential_hash text not null unique,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (election_id,participant_id)
    references public.participants(election_id,id) on delete cascade,
  unique (election_id,participant_id)
);

create table if not exists public.candidates (
  election_id uuid not null,
  participant_id uuid not null,
  enabled boolean not null default true,
  primary key (election_id,participant_id),
  foreign key (election_id,participant_id)
    references public.participants(election_id,id) on delete cascade
);

-- Guarda apenas o fato de que o eleitor já votou em uma rodada.
-- Não existe relação entre esta tabela e a cédula.
create table if not exists public.voter_status (
  election_id uuid not null references public.elections(id) on delete cascade,
  participant_id uuid not null,
  round_number smallint not null check (round_number between 1 and 3),
  voted_at timestamptz not null default now(),
  primary key (election_id,participant_id,round_number),
  foreign key (election_id,participant_id)
    references public.participants(election_id,id) on delete cascade
);

-- Cédula anônima: não armazena participant_id, credential_id, IP ou user_id.
create table if not exists public.ballots (
  id uuid primary key default gen_random_uuid(),
  election_id uuid not null references public.elections(id) on delete cascade,
  round_number smallint not null check (round_number between 1 and 3),
  candidate_id uuid not null,
  created_at timestamptz not null default now(),
  foreign key (election_id,candidate_id)
    references public.candidates(election_id,participant_id)
);

create index if not exists idx_participants_election_status
  on public.participants(election_id,status);
create index if not exists idx_ballots_election_round
  on public.ballots(election_id,round_number);
create index if not exists idx_candidates_election
  on public.candidates(election_id);

-- Função auxiliar para políticas administrativas.
create or replace function public.is_election_admin(target_election uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.election_admins ea
    where ea.election_id = target_election
      and ea.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_election_admin(uuid) from public;
grant execute on function public.is_election_admin(uuid) to authenticated;

-- RLS habilitado em todas as tabelas.
alter table public.elections enable row level security;
alter table public.election_admins enable row level security;
alter table public.participants enable row level security;
alter table public.voter_credentials enable row level security;
alter table public.candidates enable row level security;
alter table public.voter_status enable row level security;
alter table public.ballots enable row level security;

-- Administradores autenticados podem consultar e administrar somente suas salas.
create policy "admins read elections"
on public.elections for select to authenticated
using (public.is_election_admin(id) or created_by = (select auth.uid()));

create policy "creator inserts election"
on public.elections for insert to authenticated
with check (created_by = (select auth.uid()));

create policy "admins update elections"
on public.elections for update to authenticated
using (public.is_election_admin(id) or created_by = (select auth.uid()))
with check (public.is_election_admin(id) or created_by = (select auth.uid()));

create policy "admins read admin list"
on public.election_admins for select to authenticated
using (public.is_election_admin(election_id));

create policy "admins read participants"
on public.participants for select to authenticated
using (public.is_election_admin(election_id));

create policy "admins update participants"
on public.participants for update to authenticated
using (public.is_election_admin(election_id))
with check (public.is_election_admin(election_id));

create policy "admins read credentials"
on public.voter_credentials for select to authenticated
using (public.is_election_admin(election_id));

create policy "admins read candidates"
on public.candidates for select to authenticated
using (public.is_election_admin(election_id));

create policy "admins manage candidates"
on public.candidates for all to authenticated
using (public.is_election_admin(election_id))
with check (public.is_election_admin(election_id));

create policy "admins read voter status"
on public.voter_status for select to authenticated
using (public.is_election_admin(election_id));

create policy "admins read ballot aggregates only via server"
on public.ballots for select to authenticated
using (false);

-- Sem policies de INSERT/UPDATE/DELETE para participantes, credenciais,
-- status de voto ou cédulas. As Edge Functions usarão service role no servidor.
-- Não conceder a chave service_role ao navegador.

revoke all on public.elections from anon, authenticated;
revoke all on public.election_admins from anon, authenticated;
revoke all on public.participants from anon, authenticated;
revoke all on public.voter_credentials from anon, authenticated;
revoke all on public.candidates from anon, authenticated;
revoke all on public.voter_status from anon, authenticated;
revoke all on public.ballots from anon, authenticated;

grant select, insert, update on public.elections to authenticated;
grant select on public.election_admins to authenticated;
grant select, update on public.participants to authenticated;
grant select on public.voter_credentials to authenticated;
grant select, insert, update, delete on public.candidates to authenticated;
grant select on public.voter_status to authenticated;
grant select on public.ballots to authenticated;

-- Importante: não habilite Realtime/publicação para ballots.
-- O telão receberá apenas totais agregados por uma Edge Function.

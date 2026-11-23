-- ============================================================
-- MGM Contabilidade - Schema Supabase para Painel Administrativo
-- Execute no SQL Editor do Supabase (Dashboard > SQL Editor)
-- ============================================================

-- 1) Tabela de Leads (captura do formulário + painel admin)
create table if not exists public.leads (
  id              uuid primary key default gen_random_uuid(),
  -- campos do formulário público (form.js)
  nome            text,
  email           text,
  whatsapp        text,
  perfil          text,            -- setor/nicho (Médico, Clínica, etc.)
  faturamento_mensal text,
  mensagem        text,
  origem          text default 'site MGM',
  status          text default 'novo',
  idempotency_key text unique,
  -- campos do painel administrativo (admin.html)
  name            text,            -- espelho de nome
  profile         text,            -- espelho de perfil
  revenue         text,            -- espelho de faturamento_mensal
  message         text,            -- espelho de mensagem
  note            text default '',  -- anotações do admin
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- sincroniza campos espelho no insert/update via trigger
create or replace function public.sync_lead_fields()
returns trigger as $$
begin
  if new.name is null then new.name := new.nome; end if;
  if new.nome is null then new.nome := new.name; end if;
  if new.profile is null then new.profile := new.perfil; end if;
  if new.perfil is null then new.perfil := new.profile; end if;
  if new.revenue is null then new.revenue := new.faturamento_mensal; end if;
  if new.faturamento_mensal is null then new.faturamento_mensal := new.revenue; end if;
  if new.message is null then new.message := new.mensagem; end if;
  if new.mensagem is null then new.mensagem := new.message; end if;
  new.updated_at := now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_sync_lead_fields on public.leads;
create trigger trg_sync_lead_fields
  before insert or update on public.leads
  for each row execute function public.sync_lead_fields();

-- 2) Tabela de Configuração do Site (editável pelo painel admin)
create table if not exists public.site_config (
  id          uuid primary key default gen_random_uuid(),
  key         text unique not null,
  value       jsonb not null,
  updated_at  timestamptz default now()
);

-- seed inicial (identidade)
insert into public.site_config (key, value) values
  ('identity', '{"brandName":"MGM Contabilidade","shortName":"MGM","tagline":"Contabilidade Consultiva & Estratégica","crc":"CRC-SP 2SP041892/O-5"}'::jsonb)
on conflict (key) do nothing;

-- 3) RLS
alter table public.leads enable row level security;
alter table public.site_config enable row level security;

-- anon pode inserir leads (formulário público) e ler config
drop policy if exists "anon_insert_leads" on public.leads;
create policy "anon_insert_leads" on public.leads
  for insert to anon with check (true);

drop policy if exists "anon_read_config" on public.site_config;
create policy "anon_read_config" on public.site_config
  for select to anon using (true);

-- authenticated (admin) pode tudo
drop policy if exists "auth_all_leads" on public.leads;
create policy "auth_all_leads" on public.leads
  for all to authenticated using (true) with check (true);

drop policy if exists "auth_all_config" on public.site_config;
create policy "auth_all_config" on public.site_config
  for all to authenticated using (true) with check (true);

-- 4) Índices
create index if not exists idx_leads_created_at on public.leads (created_at desc);
create index if not exists idx_leads_status on public.leads (status);
create index if not exists idx_leads_idempotency on public.leads (idempotency_key);

-- 5) Realtime (opcional) - habilita sync em tempo real para o painel
alter publication supabase_realtime add table public.leads;
alter publication supabase_realtime add table public.site_config;

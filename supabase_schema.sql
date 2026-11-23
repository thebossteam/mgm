-- ============================================================
-- MGM Contabilidade - Schema Supabase para Painel Administrativo
-- Execute no SQL Editor do Supabase (Dashboard > SQL Editor)
-- ============================================================

-- 0) Se a tabela leads já existe (do formulário), adicione as colunas do painel
alter table public.leads add column if not exists name text;
alter table public.leads add column if not exists profile text;
alter table public.leads add column if not exists revenue text;
alter table public.leads add column if not exists message text;
alter table public.leads add column if not exists note text default '';
alter table public.leads add column if not exists created_at timestamptz default now();
alter table public.leads add column if not exists updated_at timestamptz default now();

-- 1) Tabela de Leads (captura do formulário público + painel admin)
create table if not exists public.leads (
  id              uuid primary key default gen_random_uuid(),
  nome            text,
  email           text,
  whatsapp        text,
  perfil          text,
  faturamento_mensal text,
  mensagem        text,
  origem          text default 'site MGM',
  status          text default 'novo',
  idempotency_key text unique,
  name            text,
  profile         text,
  revenue         text,
  message         text,
  note            text default '',
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

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

-- 3) Trigger para sincronizar campos espelho
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

-- 4) RLS
alter table public.leads enable row level security;
alter table public.site_config enable row level security;

drop policy if exists "anon_all_leads" on public.leads;
create policy "anon_all_leads" on public.leads
  for all to anon using (true) with check (true);

drop policy if exists "anon_all_config" on public.site_config;
create policy "anon_all_config" on public.site_config
  for all to anon using (true) with check (true);

drop policy if exists "auth_all_leads" on public.leads;
create policy "auth_all_leads" on public.leads
  for all to authenticated using (true) with check (true);

drop policy if exists "auth_all_config" on public.site_config;
create policy "auth_all_config" on public.site_config
  for all to authenticated using (true) with check (true);

-- 5) Índices
create index if not exists idx_leads_created_at on public.leads (created_at desc);
create index if not exists idx_leads_status on public.leads (status);
create index if not exists idx_leads_idempotency on public.leads (idempotency_key);

-- 6) Realtime (habilitar via Dashboard se der erro de "already member")
-- Dashboard > Database > Replication > supabase_realtime > adicionar tabelas leads e site_config
-- Ou execute manualmente (ignora erro se já estiver habilitado):
do $$ begin
  alter publication supabase_realtime add table public.leads;
exception when duplicate_object then null;
end $$;
do $$ begin
  alter publication supabase_realtime add table public.site_config;
exception when duplicate_object then null;
end $$;
-- 7) Supabase Storage (criar bucket 'site-images' para upload de imagens)
-- Execute no Dashboard: Storage > New Bucket > Name: site-images > Public: true
-- Ou via SQL (se a extensão storage estiver disponível):
insert into storage.buckets (id, name, public)
values ('site-images', 'site-images', true)
on conflict (id) do nothing;

-- Política de acesso público para leitura
drop policy if exists "Public read site-images" on storage.objects;
create policy "Public read site-images" on storage.objects
  for select using (bucket_id = 'site-images');

-- Política de upload para anon/authenticated
drop policy if exists "Auth upload site-images" on storage.objects;
create policy "Auth upload site-images" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'site-images');

drop policy if exists "Auth delete site-images" on storage.objects;
create policy "Auth delete site-images" on storage.objects
  for delete to anon, authenticated using (bucket_id = 'site-images');

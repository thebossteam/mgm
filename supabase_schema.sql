
-- 0) Se a tabela leads já existe (do formulário), adicione as colunas do painel
alter table public.leads add column if not exists name text;
alter table public.leads add column if not exists profile text;
alter table public.leads add column if not exists revenue text;
alter table public.leads add column if not exists message text;
alter table public.leads add column if not exists note text default '';
alter table public.leads add column if not exists created_at timestamptz default now();
alter table public.leads add column if not exists updated_at timestamptz default now();

# -*- coding: utf-8 -*-
p = 'supabase_schema.sql'
s = open(p, encoding='utf-8').read()

# Replace the RLS section to allow anon full access (admin panel has no auth)
old_rls = """-- 3) RLS
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
  for all to authenticated using (true) with check (true);"""

new_rls = """-- 3) RLS
-- Nota: o painel admin atual não tem autenticação própria.
-- Para produção, recomenda-se adicionar Supabase Auth e restringir
-- as políticas anon a insert/select apenas.
alter table public.leads enable row level security;
alter table public.site_config enable row level security;

-- anon pode tudo (painel admin sem auth + formulário público)
-- ATENÇÃO: em produção, restrinja com Supabase Auth.
drop policy if exists "anon_all_leads" on public.leads;
create policy "anon_all_leads" on public.leads
  for all to anon using (true) with check (true);

drop policy if exists "anon_all_config" on public.site_config;
create policy "anon_all_config" on public.site_config
  for all to anon using (true) with check (true);

-- authenticated (admin com Supabase Auth) também pode tudo
drop policy if exists "auth_all_leads" on public.leads;
create policy "auth_all_leads" on public.leads
  for all to authenticated using (true) with check (true);

drop policy if exists "auth_all_config" on public.site_config;
create policy "auth_all_config" on public.site_config
  for all to authenticated using (true) with check (true);"""

assert old_rls in s, 'rls block not found'
s = s.replace(old_rls, new_rls, 1)
open(p, 'w', encoding='utf-8').write(s)
print('SQL updated')

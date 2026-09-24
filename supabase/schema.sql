-- ============================================================
-- Controle de Lenha TRBJ — Supabase Schema
-- ============================================================

-- Enable UUID extension (optional, used by storage)
create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- Main table: notas_lenha
-- ------------------------------------------------------------
create table if not exists notas_lenha (
  id            bigint generated always as identity primary key,
  numero_nota   text,
  data_nota     date,
  motorista     text,
  placa         text,
  cliente       text,
  projeto       text,
  s1            decimal(10, 3),
  m2            decimal(10, 3),
  total_m3      decimal(10, 3),
  imagem_url    text,
  criado_em     timestamp with time zone default now()
);

-- Indexes for common queries
create index if not exists idx_notas_data_nota   on notas_lenha (data_nota desc);
create index if not exists idx_notas_motorista   on notas_lenha (motorista);
create index if not exists idx_notas_placa       on notas_lenha (placa);
create index if not exists idx_notas_cliente     on notas_lenha (cliente);
create index if not exists idx_notas_numero_nota on notas_lenha (numero_nota);

-- ------------------------------------------------------------
-- Row Level Security (free plan safe — enable when auth is set up)
-- ------------------------------------------------------------
alter table notas_lenha enable row level security;

-- Allow full access for authenticated users (adjust as needed)
create policy "Authenticated users full access"
  on notas_lenha
  for all
  to authenticated
  using (true)
  with check (true);

-- Allow anon read (remove if you want auth-only access)
create policy "Anon read access"
  on notas_lenha
  for select
  to anon
  using (true);

-- ------------------------------------------------------------
-- Storage bucket: notas-imagens
-- Run this in Supabase Dashboard → Storage → New bucket,
-- OR via the SQL editor:
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('notas-imagens', 'notas-imagens', true)
on conflict (id) do nothing;

-- Allow authenticated users to upload
create policy "Authenticated upload"
  on storage.objects
  for insert
  to authenticated
  with check (bucket_id = 'notas-imagens');

-- Allow public read of images
create policy "Public read images"
  on storage.objects
  for select
  to public
  using (bucket_id = 'notas-imagens');

-- ------------------------------------------------------------
-- Helper view: fechamento_mensal
-- ------------------------------------------------------------
create or replace view vw_fechamento_mensal as
select
  extract(year  from data_nota)::int as ano,
  extract(month from data_nota)::int as mes,
  cliente,
  projeto,
  count(*)                           as total_notas,
  sum(total_m3)                      as total_m3
from notas_lenha
where data_nota is not null
group by 1, 2, 3, 4
order by 1 desc, 2 desc, 3, 4;

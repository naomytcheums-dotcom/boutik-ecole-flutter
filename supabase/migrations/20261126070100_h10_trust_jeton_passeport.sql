-- H10 TRUST (2/3) : jeton de partage de passeport (matrice A-418, CDC 17.1/17.2).
--  * le titulaire crée un jeton aléatoire (192 bits) pour UNE sélection de rubriques, à durée limitée (1 à 30 jours, 7 par défaut) ; seul l'empreinte SHA-256 du jeton est stockée
--    (le jeton n'est montré qu'une fois) ; révocable immédiatement ; 5 jetons actifs au plus ;
--  * passport_token_verify(jeton) : lisible par un tiers sans connexion, limité aux rubriques choisies ; le nom complet n'apparaît que si « identite » est choisie
--    (sinon initiales) ; jeton inconnu / révoqué / expiré : même absence de données ; limite de tentatives infructueuses (anti-énumération, même compteur que les certificats) ;
--  * un compte suspendu ou supprimé ne se vérifie plus. Les rubriques privées non choisies ne sont jamais renvoyées.
-- Additive et rejouable. Retour arrière : drop function passport_token_issue(text[], integer, text), passport_token_list(), passport_token_revoke(uuid), passport_token_verify(text) ; drop table passport_tokens.

create extension if not exists pgcrypto;

create table if not exists passport_tokens (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles (id) on delete cascade,
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  sections text[] not null check (cardinality(sections) between 1 and 5 and sections <@ array['identite', 'competences', 'realisations', 'certificats', 'missions']),
  label text not null default '' check (char_length(label) <= 80),
  expires_at timestamptz not null,
  revoked boolean not null default false,
  revoked_at timestamptz,
  views integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists passport_tokens_owner_idx on passport_tokens (owner_id, created_at desc);
alter table passport_tokens enable row level security;
revoke all on passport_tokens from public, anon, authenticated;

create or replace function passport_token_issue(p_sections text[], p_ttl_days integer default 7, p_label text default '') returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_sections text[]; v_token text; v_exp timestamptz; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = '' or exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Compte indisponible'; end if;
  select coalesce(array_agg(distinct s order by s), '{}') into v_sections from unnest(coalesce(p_sections, '{}')) s;
  if cardinality(v_sections) = 0 then raise exception 'Choisissez au moins une rubrique à partager'; end if;
  if not (v_sections <@ array['identite', 'competences', 'realisations', 'certificats', 'missions']) then raise exception 'Rubrique inconnue'; end if;
  if coalesce(p_ttl_days, 7) not between 1 and 30 then raise exception 'Durée de validité : 1 à 30 jours'; end if;
  if (select count(*) from passport_tokens where owner_id = auth.uid() and not revoked and expires_at > now()) >= 5 then raise exception 'Cinq liens actifs au plus : révoquez-en un d''abord'; end if;
  v_token := qr_new_token();
  v_exp := now() + make_interval(days => coalesce(p_ttl_days, 7));
  insert into passport_tokens (owner_id, token_hash, sections, label, expires_at)
    values (auth.uid(), encode(digest(convert_to(v_token, 'UTF8'), 'sha256'), 'hex'), v_sections, left(_clean_text(p_label), 80), v_exp) returning id into v_id;
  return jsonb_build_object('id', v_id, 'token', v_token, 'sections', to_jsonb(v_sections), 'expires_at', v_exp);
end $$;

create or replace function passport_token_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'label', t.label, 'sections', to_jsonb(t.sections), 'expires_at', t.expires_at, 'revoked', t.revoked,
            'active', not t.revoked and t.expires_at > now(), 'views', t.views, 'created_at', t.created_at) order by t.created_at desc)
          from passport_tokens t where t.owner_id = auth.uid()), '[]'::jsonb);
end $$;

create or replace function passport_token_revoke(p_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update passport_tokens set revoked = true, revoked_at = coalesce(revoked_at, now()) where id = p_id and owner_id = auth.uid();
  if not found then raise exception 'Lien introuvable'; end if;
  return true;
end $$;

create or replace function passport_token_verify(p_token text) returns jsonb
language plpgsql volatile security definer set search_path = public, extensions as $$
declare
  v_caller text := _trust_caller(); t passport_tokens%rowtype; p profiles%rowtype; v_secs jsonb := '{}'::jsonb;
begin
  if (select count(*) from certificate_checks where caller = v_caller and at > now() - interval '10 minutes') >= 20 then
    return jsonb_build_object('valid', false, 'reason', 'limit');
  end if;
  select * into t from passport_tokens where token_hash = encode(digest(convert_to(left(coalesce(p_token, ''), 80), 'UTF8'), 'sha256'), 'hex');
  if not found then
    insert into certificate_checks (caller) values (v_caller);
    return jsonb_build_object('valid', false, 'reason', 'unknown');
  end if;
  select * into p from profiles where id = t.owner_id and not coalesce(suspended, false);
  if p.id is null or t.revoked or t.expires_at <= now() then
    return jsonb_build_object('valid', false, 'reason', case when t.revoked then 'revoked' when t.expires_at <= now() then 'expired' else 'unavailable' end);
  end if;
  update passport_tokens set views = views + 1 where id = t.id;
  if 'identite' = any (t.sections) then
    v_secs := v_secs || jsonb_build_object('identite', jsonb_build_object('headline', coalesce((select headline from talent_passport_profile where owner_id = p.id), ''),
      'summary', coalesce((select summary from talent_passport_profile where owner_id = p.id), ''), 'department', coalesce(p.department, ''), 'institution', coalesce(p.institution, ''),
      'certified', p.certification::text = 'approved'));
  end if;
  if 'competences' = any (t.sections) then
    v_secs := v_secs || jsonb_build_object('competences', coalesce((select jsonb_agg(jsonb_build_object('skill', s.skill, 'level', s.level, 'years', s.years, 'proof_verified', coalesce(d.status = 'verified', false))
        order by _talent_level_rank(s.level) desc, s.created_at) from talent_skills s left join user_documents d on d.id = s.proof_document_id where s.owner_id = p.id), '[]'::jsonb));
  end if;
  if 'realisations' = any (t.sections) then
    v_secs := v_secs || jsonb_build_object('realisations', coalesce((select jsonb_agg(jsonb_build_object('title', x.title, 'category', x.category, 'happened_on', x.happened_on) order by x.created_at desc)
        from (select * from portfolio_items where owner_id = p.id and kind = 'realisation' order by created_at desc limit 20) x), '[]'::jsonb));
  end if;
  if 'certificats' = any (t.sections) then
    v_secs := v_secs || jsonb_build_object('certificats', coalesce((select jsonb_agg(jsonb_build_object('code', c.code, 'title', c.subject_title, 'issued_at', c.issued_at) order by c.issued_at desc)
        from certificates c where c.holder_id = p.id and not c.revoked), '[]'::jsonb));
  end if;
  if 'missions' = any (t.sections) then
    v_secs := v_secs || jsonb_build_object('missions', coalesce((select jsonb_agg(jsonb_build_object('title', m.title, 'ended_on', m.updated_at::date) order by m.updated_at desc)
        from missions m join mission_proposals mp on mp.mission_id = m.id and mp.author_id = p.id and mp.status = 'accepted' where m.status in ('delivered', 'closed')), '[]'::jsonb));
  end if;
  return jsonb_build_object('valid', true, 'name', case when 'identite' = any (t.sections) then p.name else _trust_initials(p.name) end,
    'sections', v_secs, 'shared_sections', to_jsonb(t.sections), 'expires_at', t.expires_at);
end $$;

revoke all on function passport_token_issue(text[], integer, text), passport_token_list(), passport_token_revoke(uuid) from public, anon;
grant execute on function passport_token_issue(text[], integer, text), passport_token_list(), passport_token_revoke(uuid) to authenticated;
revoke all on function passport_token_verify(text) from public;
grant execute on function passport_token_verify(text) to anon, authenticated;

-- Réinitialisation du mot de passe par code à usage unique (SMS / WhatsApp), gérée par l'Edge Function « auth-recovery ».
-- Le code n'est JAMAIS stocké en clair (HMAC-SHA256 avec le secret du service) ; table inaccessible aux clients (RLS sans politique).
create table if not exists auth_recovery_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  phone text not null,
  channel text not null check (channel in ('sms','whatsapp')),
  code_hash text not null,
  attempts int not null default 0,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists auth_recovery_codes_phone_idx on auth_recovery_codes (phone, created_at desc);
alter table auth_recovery_codes enable row level security;
revoke all on auth_recovery_codes from anon, authenticated;
comment on table auth_recovery_codes is 'Codes de réinitialisation du mot de passe (hachés, 10 min, 5 essais max). Accès réservé au service.';

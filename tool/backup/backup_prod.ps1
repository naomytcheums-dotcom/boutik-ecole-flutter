# Sauvegarde LOGIQUE de la production Supabase (lecture seule) : donnees `public`, structure complete, metadonnees Auth, fichiers Storage.
# Prerequis : Supabase CLI connecte (`npx supabase login`), dossier de travail lie au projet (`supabase link`), Node. Aucun secret n'est ecrit ni affiche :
# la cle de service est lue en memoire pour telecharger les fichiers du stockage puis effacee.
#   pwsh tool/backup/backup_prod.ps1 -WorkDir C:\tmp\prodwork -OutDir <dossier_hors_depot> -Suffix 20261201_avant_xxx [-ProjectRef zxqcnmgwhtbxkdpjqtlr]
# Ensuite : chiffrer avec protect_backup.ps1 et verifier avec restore_drill.mjs (voir docs/transformation/H13_SAUVEGARDE_RESTAURATION.md).
param(
  [Parameter(Mandatory)][string]$WorkDir,
  [Parameter(Mandatory)][string]$OutDir,
  [Parameter(Mandatory)][string]$Suffix,
  [string]$ProjectRef = 'zxqcnmgwhtbxkdpjqtlr'
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutDir | Out-Null
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("bebk_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $tmp | Out-Null

function Invoke-Query([string]$sql) {
  $f = Join-Path $tmp ([guid]::NewGuid().ToString('N') + '.sql'); Set-Content $f $sql -Encoding UTF8
  Push-Location $WorkDir
  try { $raw = npx supabase@2.122.0 db query --linked --workdir $WorkDir -f $f -o json 2>$null } finally { Pop-Location }
  return (($raw | Where-Object { $_ -notmatch '^Initialising' }) -join "`n")
}

# 1. donnees public (une ligne JSON par table)
$gen = (Invoke-Query "select string_agg(format('select %L::text as t, coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) as r from public.%I x', tablename, tablename), E' union all\n') as q from pg_tables where schemaname='public';") | ConvertFrom-Json
$data = Invoke-Query $gen.rows[0].q
Set-Content (Join-Path $OutDir "prod_donnees_public_$Suffix.json") $data -Encoding UTF8
$d = $data | ConvertFrom-Json
"public : $($d.rows.Count) tables, $((($d.rows | ForEach-Object { $_.r.Count }) | Measure-Object -Sum).Sum) lignes"

# 2. structure complete
$struct = @"
select jsonb_build_object(
 'functions', (select coalesce(jsonb_agg(jsonb_build_object('schema', n.nspname, 'name', p.proname, 'def', pg_get_functiondef(p.oid)) order by n.nspname, p.proname), '[]') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind in ('f','p')),
 'policies', (select coalesce(jsonb_agg(to_jsonb(x) order by x.schemaname, x.tablename, x.policyname), '[]') from pg_policies x where x.schemaname in ('public','storage')),
 'triggers', (select coalesce(jsonb_agg(jsonb_build_object('table', c.relname, 'name', t.tgname, 'def', pg_get_triggerdef(t.oid)) order by c.relname, t.tgname), '[]') from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal),
 'rls', (select coalesce(jsonb_agg(jsonb_build_object('table', c.relname, 'rls', c.relrowsecurity) order by c.relname), '[]') from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r'),
 'indexes', (select coalesce(jsonb_agg(jsonb_build_object('table', tablename, 'name', indexname, 'def', indexdef) order by tablename, indexname), '[]') from pg_indexes where schemaname='public'),
 'grants', (select coalesce(jsonb_agg(to_jsonb(g) order by g.table_name, g.grantee, g.privilege_type), '[]') from information_schema.role_table_grants g where g.table_schema='public' and g.grantee in ('anon','authenticated')),
 'columns', (select coalesce(jsonb_agg(jsonb_build_object('table', table_name, 'col', column_name, 'type', data_type, 'null', is_nullable, 'default', column_default) order by table_name, ordinal_position), '[]') from information_schema.columns where table_schema='public'),
 'migrations', (select coalesce(jsonb_agg(version order by version), '[]') from supabase_migrations.schema_migrations),
 'buckets', (select coalesce(jsonb_agg(to_jsonb(b)), '[]') from storage.buckets b)
) as s;
"@
$st = Invoke-Query $struct
Set-Content (Join-Path $OutDir "prod_structure_complete_$Suffix.json") $st -Encoding UTF8
$x = ($st | ConvertFrom-Json).rows[0].s
"structure : $($x.functions.Count) fonctions, $($x.policies.Count) politiques, $($x.triggers.Count) declencheurs, $($x.indexes.Count) index, $($x.migrations.Count) migrations"

# 3. Auth (comptes, identites, facteurs MFA : contient des empreintes de mots de passe -> toujours chiffrer) et metadonnees Storage
$auth = @"
select jsonb_build_object(
 'users', (select coalesce(jsonb_agg(to_jsonb(u)), '[]') from auth.users u),
 'identities', (select coalesce(jsonb_agg(to_jsonb(i) - 'email'), '[]') from auth.identities i),
 'mfa_factors', (select coalesce(jsonb_agg(to_jsonb(m)), '[]') from auth.mfa_factors m),
 'storage_objects', (select coalesce(jsonb_agg(jsonb_build_object('bucket', bucket_id, 'name', name, 'size', metadata->>'size', 'mime', metadata->>'mimetype', 'created_at', created_at, 'owner', owner)), '[]') from storage.objects)
) as v;
"@
$au = ((Invoke-Query $auth) | ConvertFrom-Json).rows[0].v
$authFile = Join-Path $OutDir "prod_auth_storage_metadonnees_$Suffix.json"
($au | ConvertTo-Json -Depth 20) | Set-Content $authFile -Encoding UTF8
"auth : $($au.users.Count) comptes, $($au.identities.Count) identites, $($au.mfa_factors.Count) facteurs MFA ; storage : $($au.storage_objects.Count) objets"

# 4. fichiers Storage (cle de service lue en memoire seulement)
Push-Location $WorkDir; try { $keys = npx supabase@2.122.0 projects api-keys --project-ref $ProjectRef -o json 2>$null | Out-String | ConvertFrom-Json } finally { Pop-Location }
$key = ($keys | Where-Object { $_.name -eq 'service_role' } | Select-Object -First 1).api_key
if (-not $key) { throw 'Cle de service introuvable (droits insuffisants).' }
$dir = Join-Path $OutDir "storage_$Suffix"; New-Item -ItemType Directory -Force $dir | Out-Null
$ok = 0; $ko = 0
foreach ($o in $au.storage_objects) {
  $dst = Join-Path $dir ($o.bucket + '__' + ($o.name -replace '[\\/:*?"<>|]', '_'))
  curl.exe -s -f -m 600 -H "Authorization: Bearer $key" -H "apikey: $key" -o $dst "https://$ProjectRef.supabase.co/storage/v1/object/$($o.bucket)/$($o.name)"
  if ($LASTEXITCODE -eq 0 -and (Get-Item $dst).Length -eq [int64]$o.size) { $ok++ } else { $ko++; "KO $($o.bucket)/$($o.name)" }
}
$key = $null
"storage fichiers : $ok OK, $ko KO"
Remove-Item $tmp -Recurse -Force
if ($ko -gt 0) { exit 1 }

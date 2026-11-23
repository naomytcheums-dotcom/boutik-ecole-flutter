# Exécute un script de test de migration sur la réplique locale (transaction annulée) et résume les cas.
# Usage : pwsh outils\executer_test_replique.ps1 <script_test.sql> <migration.sql> <sortie.txt>
param([string]$Test, [string]$Migration, [string]$Sortie)
$t = [IO.File]::ReadAllText($Test)
$m = [IO.File]::ReadAllText($Migration)
$marqueur = '(?m)^--@@MIGRATION@@--\r?$'
$n = [regex]::Matches($t, $marqueur).Count
if ($n -ne 1) { throw "Marqueur trouvé $n fois (1 attendu) : arrêt sans exécution" }
$s = [regex]::Replace($t, $marqueur, [System.Text.RegularExpressions.MatchEvaluator] { param($x) $m })
$out = $s | docker exec -i supabase_db_boutik_local psql -U postgres -d postgres -At 2>&1 | ForEach-Object { "$_" }
$out | Set-Content -LiteralPath $Sortie -Encoding utf8
$r = $out | Select-String 'RESULT\|' | ForEach-Object { $_.Line -replace '^.*?RESULT\|', '' }
$r
"PASS=" + ($r | Where-Object { $_ -match '\|PASS\|' }).Count + " FAIL=" + ($r | Where-Object { $_ -match '\|FAIL\|' }).Count
$out | Select-String '^(psql:.*)?ERROR' | Select-Object -First 5

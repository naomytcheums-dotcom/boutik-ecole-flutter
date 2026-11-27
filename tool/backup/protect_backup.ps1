# Chiffrement / dechiffrement d'une sauvegarde Boutik-Ecole (AES-256-GCM, cle derivee par PBKDF2-SHA256, 600 000 iterations).
# Aucun secret n'est ecrit dans le depot ni affiche. La phrase secrete est lue dans un FICHIER (restreint a l'utilisateur) ou demandee a l'invite.
#   Chiffrer  : pwsh tool/backup/protect_backup.ps1 -Mode encrypt -Source <dossier> -Output <fichier.enc> -KeyFile <fichier_cle>
#   Dechiffrer: pwsh tool/backup/protect_backup.ps1 -Mode decrypt -Source <fichier.enc> -Output <dossier_de_sortie> -KeyFile <fichier_cle>
# Format : "BEBK1" | sel (16) | nonce (12) | etiquette (16) | texte chiffre (archive ZIP du dossier).
param(
  [Parameter(Mandatory)][ValidateSet('encrypt', 'decrypt')][string]$Mode,
  [Parameter(Mandatory)][string]$Source,
  [Parameter(Mandatory)][string]$Output,
  [string]$KeyFile
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-Passphrase {
  if ($KeyFile -and (Test-Path $KeyFile)) { return (Get-Content $KeyFile -Raw).Trim() }
  $s = Read-Host 'Phrase secrete' -AsSecureString
  return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
}
function Get-Key([string]$pass, [byte[]]$salt) {
  $kdf = [Security.Cryptography.Rfc2898DeriveBytes]::new($pass, $salt, 600000, [Security.Cryptography.HashAlgorithmName]::SHA256)
  try { return $kdf.GetBytes(32) } finally { $kdf.Dispose() }
}

$pass = Get-Passphrase
if ($pass.Length -lt 20) { throw 'Phrase secrete trop courte (20 caracteres minimum).' }

if ($Mode -eq 'encrypt') {
  $zip = [IO.Path]::GetTempFileName()
  Remove-Item $zip -Force
  [IO.Compression.ZipFile]::CreateFromDirectory((Resolve-Path $Source), $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
  $plain = [IO.File]::ReadAllBytes($zip)
  Remove-Item $zip -Force
  $salt = [byte[]]::new(16); $nonce = [byte[]]::new(12); $tag = [byte[]]::new(16)
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create(); $rng.GetBytes($salt); $rng.GetBytes($nonce)
  $key = Get-Key $pass $salt
  $cipher = [byte[]]::new($plain.Length)
  $gcm = [Security.Cryptography.AesGcm]::new($key, 16)
  $gcm.Encrypt($nonce, $plain, $cipher, $tag, [Text.Encoding]::ASCII.GetBytes('BEBK1'))
  $gcm.Dispose()
  $fs = [IO.File]::Create($Output)
  foreach ($part in @([Text.Encoding]::ASCII.GetBytes('BEBK1'), $salt, $nonce, $tag, $cipher)) { $fs.Write($part, 0, $part.Length) }
  $fs.Dispose()
  $hash = (Get-FileHash $Output -Algorithm SHA256).Hash
  "Chiffre : $Output ($((Get-Item $Output).Length) octets) SHA-256 $hash"
} else {
  $all = [IO.File]::ReadAllBytes($Source)
  if ([Text.Encoding]::ASCII.GetString($all, 0, 5) -ne 'BEBK1') { throw 'Format inconnu.' }
  $salt = $all[5..20]; $nonce = $all[21..32]; $tag = $all[33..48]
  $cipher = $all[49..($all.Length - 1)]
  $key = Get-Key $pass ([byte[]]$salt)
  $plain = [byte[]]::new($cipher.Length)
  $gcm = [Security.Cryptography.AesGcm]::new($key, 16)
  $gcm.Decrypt([byte[]]$nonce, [byte[]]$cipher, [byte[]]$tag, $plain, [Text.Encoding]::ASCII.GetBytes('BEBK1'))
  $gcm.Dispose()
  $zip = [IO.Path]::GetTempFileName(); [IO.File]::WriteAllBytes($zip, $plain)
  New-Item -ItemType Directory -Force $Output | Out-Null
  [IO.Compression.ZipFile]::ExtractToDirectory($zip, (Resolve-Path $Output).Path)
  Remove-Item $zip -Force
  "Dechiffre dans : $Output"
}

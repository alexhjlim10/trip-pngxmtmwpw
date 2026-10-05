# 나고야 여행 페이지: Claude·GitHub 키 넣기
# 키를 사이트 비밀번호로 암호화해 secrets.enc로 저장하고 GitHub에 올립니다. 키는 화면에 보이지 않고, 암호화되지 않은 채로는 어디에도 저장되지 않아요.
# 형식은 tool.js·index.html과 같아요: salt(16) | iv(16) | AES-256-CBC(PBKDF2-SHA256 250000회) of ("NGYOK:" + 본문)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
function Plain($sec) { [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)) }
function Key($pw, $salt) { (New-Object System.Security.Cryptography.Rfc2898DeriveBytes($pw, [byte[]]$salt, 250000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)).GetBytes(32) }
function Aes() { $a = New-Object System.Security.Cryptography.AesCryptoServiceProvider; $a.Mode = "CBC"; $a.Padding = "PKCS7"; $a }
function Decrypt($bytes, $pw) {
  $salt = New-Object byte[] 16; $iv = New-Object byte[] 16; $ct = New-Object byte[] ($bytes.Length - 32)
  [Array]::Copy($bytes, 0, $salt, 0, 16); [Array]::Copy($bytes, 16, $iv, 0, 16); [Array]::Copy($bytes, 32, $ct, 0, $ct.Length)
  $a = Aes; $a.Key = Key $pw $salt; $a.IV = $iv
  try { $pt = $a.CreateDecryptor().TransformFinalBlock($ct, 0, $ct.Length) } catch { throw "사이트 비밀번호가 맞지 않아요." }
  if ([Text.Encoding]::UTF8.GetString($pt, 0, 6) -ne "NGYOK:") { throw "사이트 비밀번호가 맞지 않아요." }
  return [Text.Encoding]::UTF8.GetString($pt, 6, $pt.Length - 6)
}
function Encrypt($text, $pw) {
  $pt = [Text.Encoding]::UTF8.GetBytes("NGYOK:" + $text)
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  $salt = New-Object byte[] 16; $rng.GetBytes($salt); $iv = New-Object byte[] 16; $rng.GetBytes($iv)
  $a = Aes; $a.Key = Key $pw $salt; $a.IV = $iv
  $ct = $a.CreateEncryptor().TransformFinalBlock($pt, 0, $pt.Length)
  $out = New-Object byte[] (32 + $ct.Length)
  [Array]::Copy($salt, 0, $out, 0, 16); [Array]::Copy($iv, 0, $out, 16, 16); [Array]::Copy($ct, 0, $out, 32, $ct.Length)
  return ,$out
}
try {
  Push-Location $here
  git pull -q
  $pw = (Plain (Read-Host "사이트 비밀번호" -AsSecureString)).Trim()
  # 비밀번호 확인 (data.bin이 열리는지)
  $null = Decrypt ([IO.File]::ReadAllBytes((Join-Path $here "data.bin"))) $pw
  $old = @{}
  $secPath = Join-Path $here "secrets.enc"
  if (Test-Path $secPath) { $o = (Decrypt ([IO.File]::ReadAllBytes($secPath)) $pw) | ConvertFrom-Json; if ($o.anthropic) { $old.anthropic = $o.anthropic }; if ($o.github) { $old.github = $o.github } }
  Write-Host ""
  Write-Host "키를 붙여넣고 Enter. 이미 넣은 키를 그대로 두려면 그냥 Enter." -ForegroundColor Cyan
  $ak = (Plain (Read-Host "Claude API 키 (sk-ant-로 시작)" -AsSecureString)).Trim()
  $gk = (Plain (Read-Host "GitHub 토큰 (github_pat_로 시작)" -AsSecureString)).Trim()
  if ($ak) { if (-not $ak.StartsWith("sk-ant-")) { throw "Claude API 키는 sk-ant- 로 시작해야 해요." }; $old.anthropic = $ak }
  if ($gk) { if (-not ($gk.StartsWith("github_pat_") -or $gk.StartsWith("ghp_"))) { throw "GitHub 토큰은 github_pat_ 로 시작해야 해요." }; $old.github = $gk }
  if (-not $old.anthropic -and -not $old.github) { throw "넣은 키가 없어요." }
  $json = (@{ anthropic = $old.anthropic; github = $old.github } | ConvertTo-Json -Compress)
  [IO.File]::WriteAllBytes($secPath, (Encrypt $json $pw))
  Write-Host "GitHub에 올리는 중..."
  git add secrets.enc; git commit -q -m "Update encrypted keys"; git push -q
  Write-Host "`n완료! 1~2분 뒤 사이트의 'Claude에게 요청'을 쓸 수 있어요." -ForegroundColor Green
} catch {
  Write-Host "`n$_" -ForegroundColor Red
} finally { Pop-Location }
Read-Host "Enter를 누르면 닫혀요"

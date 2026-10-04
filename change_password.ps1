# 나고야 여행 페이지 비밀번호 바꾸기
# data.bin(완성 페이지)과 src.enc(원본)를 옛 비밀번호로 풀어서 새 비밀번호로 다시 암호화한 뒤 GitHub에 올립니다.
# 형식은 tool.js와 같아요: salt(16) | iv(16) | AES-256-CBC(PBKDF2-SHA256 250000회) of ("NGYOK:" + 본문)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
function Plain($sec) { [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)) }
function Key($pw, $salt) { (New-Object System.Security.Cryptography.Rfc2898DeriveBytes($pw, [byte[]]$salt, 250000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)).GetBytes(32) }
function Aes() { $a = New-Object System.Security.Cryptography.AesCryptoServiceProvider; $a.Mode = "CBC"; $a.Padding = "PKCS7"; $a }
function Decrypt($bytes, $pw) {
  $salt = New-Object byte[] 16; $iv = New-Object byte[] 16; $ct = New-Object byte[] ($bytes.Length - 32)
  [Array]::Copy($bytes, 0, $salt, 0, 16); [Array]::Copy($bytes, 16, $iv, 0, 16); [Array]::Copy($bytes, 32, $ct, 0, $ct.Length)
  $a = Aes; $a.Key = Key $pw $salt; $a.IV = $iv
  try { $pt = $a.CreateDecryptor().TransformFinalBlock($ct, 0, $ct.Length) } catch { throw "옛 비밀번호가 맞지 않아요." }
  if ([Text.Encoding]::UTF8.GetString($pt, 0, 6) -ne "NGYOK:") { throw "옛 비밀번호가 맞지 않아요." }
  return ,$pt
}
function Encrypt($pt, $pw) {
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
  $old = Plain (Read-Host "지금 비밀번호" -AsSecureString)
  $p1 = Plain (Read-Host "새 비밀번호" -AsSecureString)
  $p2 = Plain (Read-Host "새 비밀번호 한 번 더" -AsSecureString)
  if ($p1 -ne $p2) { throw "두 새 비밀번호가 달라요." }
  if ($p1.Trim().Length -lt 4) { throw "새 비밀번호가 너무 짧아요." }
  Write-Host "다시 암호화하는 중..."
  foreach ($f in "data.bin", "src.enc") {
    $path = Join-Path $here $f
    $pt = Decrypt ([IO.File]::ReadAllBytes($path)) $old.Trim()
    [IO.File]::WriteAllBytes($path, (Encrypt $pt $p1.Trim()))
  }
  Write-Host "GitHub에 올리는 중..."
  git add data.bin src.enc; git commit -q -m "Change page password"; git push -q
  Write-Host "`n완료! 1~2분 뒤부터 새 비밀번호로 열려요. 이미 열어 둔 폰은 다음에 새 비밀번호를 한 번 입력하면 돼요." -ForegroundColor Green
} catch {
  Write-Host "`n$_" -ForegroundColor Red
} finally { Pop-Location }
Read-Host "Enter를 누르면 닫혀요"

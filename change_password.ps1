# 나고야 여행 페이지 비밀번호 바꾸기
# source\nagoya_trip.html(원본)을 새 비밀번호로 다시 암호화해 data.bin을 만들고 GitHub에 올립니다.
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcFile = Join-Path $here "source\nagoya_trip.html"
if (-not (Test-Path $srcFile)) { Write-Host "원본 파일이 없어요: $srcFile" -ForegroundColor Red; Read-Host "Enter를 누르면 닫혀요"; exit 1 }

function Plain($sec) { [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)) }
Write-Host "새 비밀번호를 정해 주세요 (8자 이상 추천)."
$p1 = Plain (Read-Host "새 비밀번호" -AsSecureString)
$p2 = Plain (Read-Host "한 번 더" -AsSecureString)
if ($p1 -ne $p2) { Write-Host "두 비밀번호가 달라요. 다시 실행해 주세요." -ForegroundColor Red; Read-Host "Enter를 누르면 닫혀요"; exit 1 }
if ($p1.Trim().Length -lt 4) { Write-Host "비밀번호가 너무 짧아요." -ForegroundColor Red; Read-Host "Enter를 누르면 닫혀요"; exit 1 }
$pw = $p1.Trim()

Write-Host "암호화 중..."
$plain = [IO.File]::ReadAllBytes($srcFile)
$marker = [Text.Encoding]::UTF8.GetBytes("NGYOK:")
$data = New-Object byte[] ($marker.Length + $plain.Length)
[Array]::Copy($marker, $data, $marker.Length); [Array]::Copy($plain, 0, $data, $marker.Length, $plain.Length)
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$salt = New-Object byte[] 16; $rng.GetBytes($salt); $iv = New-Object byte[] 16; $rng.GetBytes($iv)
$key = (New-Object System.Security.Cryptography.Rfc2898DeriveBytes($pw, $salt, 250000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)).GetBytes(32)
$aes = New-Object System.Security.Cryptography.AesCryptoServiceProvider
$aes.Mode = "CBC"; $aes.Padding = "PKCS7"; $aes.Key = $key; $aes.IV = $iv
$ct = $aes.CreateEncryptor().TransformFinalBlock($data, 0, $data.Length)
$out = New-Object byte[] (32 + $ct.Length)
[Array]::Copy($salt, 0, $out, 0, 16); [Array]::Copy($iv, 0, $out, 16, 16); [Array]::Copy($ct, 0, $out, 32, $ct.Length)
[IO.File]::WriteAllBytes((Join-Path $here "data.bin"), $out)

Write-Host "GitHub에 올리는 중..."
Push-Location $here
git add data.bin
git commit -q -m "Change page password"
git push -q
Pop-Location
Write-Host ""
Write-Host "완료! 1~2분 뒤부터 새 비밀번호로 열려요." -ForegroundColor Green
Write-Host "이미 열어 둔 폰은 다음에 열 때 새 비밀번호를 한 번 입력하면 돼요."
Read-Host "Enter를 누르면 닫혀요"

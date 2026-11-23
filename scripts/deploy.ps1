# Despliega la aplicacion en un entorno (staging o produccion) y hace una prueba de humo.
# Equivalente Windows de scripts/deploy.sh (laboratorio sin Docker; gunicorn no corre en Windows -> waitress).
#
# Uso: powershell -File scripts/deploy.ps1 <entorno> <puerto>
#   staging    -> puerto 5001 (lo escanea OWASP ZAP)
#   produccion -> puerto 5000 (lo vigilan Prometheus y Grafana)
param(
    [Parameter(Mandatory = $true)][ValidateSet('staging', 'produccion')][string]$Entorno,
    [Parameter(Mandatory = $true)][int]$Puerto
)
$ErrorActionPreference = 'Stop'
$version = if ($env:APP_VERSION) { $env:APP_VERSION } else { 'dev' }
$raiz = if ($env:DEPLOY_ROOT) { $env:DEPLOY_ROOT } else { Join-Path $HOME 'despliegues' }
$destino = Join-Path $raiz $Entorno
$pidfile = Join-Path $destino 'app.pid'
$python = if ($env:PYTHON) { $env:PYTHON } else { 'python' }

Write-Host ">> [$Entorno] 1/4 Deteniendo la version anterior (si existe)"
if (Test-Path $pidfile) {
    $old = Get-Content $pidfile -Raw
    Stop-Process -Id ([int]$old) -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Remove-Item $pidfile -Force
}
Get-NetTCPConnection -LocalPort $Puerto -State Listen -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }

Write-Host ">> [$Entorno] 2/4 Copiando artefactos a $destino"
New-Item -ItemType Directory -Force -Path $destino | Out-Null
Remove-Item (Join-Path $destino 'alumnos.db') -Force -ErrorAction SilentlyContinue
Copy-Item app.py, requirements.txt -Destination $destino -Force

Write-Host ">> [$Entorno] 3/4 Instalando dependencias de ejecucion"
Push-Location $destino
try {
    if (-not (Test-Path '.venv\Scripts\python.exe')) { & $python -m venv .venv; if ($LASTEXITCODE) { exit 1 } }
    & .venv\Scripts\python.exe -m pip install --quiet --disable-pip-version-check -r requirements.txt
    if ($LASTEXITCODE) { exit 1 }

    Write-Host ">> [$Entorno] 4/4 Iniciando la aplicacion (version $version)"
    # Se crea con Win32_Process.Create: el proceso queda desacoplado del build (no hereda los
    # descriptores del paso de Jenkins ni su arbol de procesos), equivalente a setsid + nohup en Linux.
    $db = Join-Path $destino 'alumnos.db'
    $exe = Join-Path $destino '.venv\Scripts\waitress-serve.exe'
    $cmd = "cmd.exe /c set `"APP_VERSION=$version`" && set `"DB_PATH=$db`" && `"$exe`" " +
           "--listen=127.0.0.1:$Puerto --threads=4 app:app > app.log 2> app.err.log"
    $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create `
        -Arguments @{ CommandLine = $cmd; CurrentDirectory = $destino }
    if ($r.ReturnValue -ne 0) { Write-Host "ERROR: no se pudo iniciar la app ($($r.ReturnValue))"; exit 1 }
} finally { Pop-Location }

Write-Host ">> [$Entorno] Prueba de humo"
$ok = $false
for ($i = 0; $i -lt 30; $i++) {
    try { Invoke-WebRequest "http://127.0.0.1:$Puerto/health" -UseBasicParsing -TimeoutSec 3 | Out-Null; $ok = $true; break }
    catch { Start-Sleep -Seconds 1 }
}
if (-not $ok) { Write-Host 'ERROR: /health no responde'; Get-Content (Join-Path $destino 'app.err.log') -Tail 30; exit 1 }
$escucha = Get-NetTCPConnection -LocalPort $Puerto -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($escucha) { Set-Content -Path $pidfile -Value $escucha.OwningProcess }
$desplegada = (Invoke-WebRequest "http://127.0.0.1:$Puerto/version" -UseBasicParsing).Content
Write-Host "/version -> $desplegada"
if ($desplegada -notlike "*`"$version`"*") { Write-Host "ERROR: la version desplegada no es $version"; exit 1 }
Write-Host "OK: $Entorno responde en el puerto $Puerto con la version $version"

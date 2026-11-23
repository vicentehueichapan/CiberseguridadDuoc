# Laboratorio EV3 (OCY1102) en Windows sin Docker: Jenkins, OWASP ZAP, Prometheus y Grafana portables.
# Todo escucha solo en 127.0.0.1. Las claves estan en C:\ev3lab\secrets (no compartir).
$ErrorActionPreference = 'Stop'
$lab = 'C:\ev3lab'
New-Item -ItemType Directory -Force -Path "$lab\logs" | Out-Null

function Test-Port([int]$port) {
    [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
}
function Start-Servicio($nombre, $puerto, $exe, $argumentos, $dir, $envs) {
    if (Test-Port $puerto) { Write-Host "$nombre ya responde en :$puerto"; return }
    foreach ($k in $envs.Keys) { Set-Item -Path "env:$k" -Value $envs[$k] }
    Start-Process -FilePath $exe -ArgumentList $argumentos -WorkingDirectory $dir -WindowStyle Hidden `
        -RedirectStandardOutput "$lab\logs\$nombre.out.log" -RedirectStandardError "$lab\logs\$nombre.err.log"
    Write-Host "$nombre iniciado (:$puerto)"
}

$zapKey = (Get-Content "$lab\secrets\zap_api_key.txt" -Raw).Trim()

Start-Servicio 'jenkins' 8080 'java' @('-Xmx1g', "-Djdk.net.unixdomain.tmpdir=$lab\tmp", "-Djava.io.tmpdir=$lab\tmp", '-Djenkins.install.runSetupWizard=false', '-Dhudson.security.ExtendedReadPermission=true',
    '-Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=false', '-jar', "$lab\descargas\jenkins.war",
    '--httpPort=8080', '--httpListenAddress=127.0.0.1') $lab @{ JENKINS_HOME = "$lab\jenkins_home" }

Start-Servicio 'zap' 8090 'java' @('-Xmx1g', "-Djdk.net.unixdomain.tmpdir=$lab\tmp", "-Djava.io.tmpdir=$lab\tmp", '-jar', "$lab\ZAP_2.16.1\zap-2.16.1.jar", '-daemon', '-silent',
    '-host', '127.0.0.1', '-port', '8090', '-dir', "$lab\zap_home", '-config', "api.key=$zapKey") "$lab\ZAP_2.16.1" @{}

Start-Servicio 'prometheus' 9090 "$lab\prometheus-2.54.1.windows-amd64\prometheus.exe" @("--config.file=$lab\prometheus.yml",
    "--storage.tsdb.path=$lab\prometheus_data", '--web.listen-address=127.0.0.1:9090') "$lab\prometheus-2.54.1.windows-amd64" @{}

Start-Servicio 'grafana' 3000 "$lab\grafana-v11.4.0\bin\grafana.exe" @('server', "--homepath=$lab\grafana-v11.4.0") `
    "$lab\grafana-v11.4.0" @{ GF_SECURITY_ADMIN_PASSWORD__FILE = "$lab\secrets\grafana_password.txt" }

Write-Host 'Jenkins http://localhost:8080 | Prometheus http://localhost:9090 | Grafana http://localhost:3000 | ZAP solo API en :8090'

# Laboratorio EV3 en Windows (sin Docker)

El laboratorio del curso usa Docker Compose. Como el equipo de trabajo no tenía WSL2/Docker (instalarlos requiere
permisos de administrador), se montó un laboratorio **equivalente** con versiones portables, todo en `C:\ev3lab`
y escuchando **solo en 127.0.0.1**:

| Servicio | Curso (Docker) | Este laboratorio |
|---|---|---|
| Jenkins | `jenkins/jenkins:lts-jdk21` :8080 | Jenkins LTS 2.580.2 (`jenkins.war`, Java 21) :8080 |
| Producción / Staging | gunicorn en el contenedor Jenkins :5000 / :5001 | waitress (`scripts/deploy.ps1`) :5000 / :5001 |
| OWASP ZAP | `zaproxy/zap-stable:2.16.1`, API con clave | ZAP 2.16.1 multiplataforma en modo demonio, API :8090 con clave |
| Prometheus | `prom/prometheus:v2.54.1` :9090 | Prometheus 2.54.1 :9090 |
| Grafana | `grafana/grafana:11.4.0` :3000 | Grafana 11.4.0 :3000 (fuente, dashboard y alertas provisionadas) |
| Bandit / pip-audit | 1.8.6 / 2.9.0 | 1.8.6 / 2.9.0 (venv `C:\ev3lab\herramientas`) |

Archivos de esta carpeta:

- `iniciar-lab.ps1`: inicia los 4 servicios (equivale a `INICIAR-AQUI.cmd`).
- `jenkins/ev3.groovy`: `init.groovy.d` de Jenkins. Crea el usuario admin, da al anónimo **solo lectura**, define las variables del laboratorio y crea el job `sistema-alumnos` (Pipeline from SCM → este repositorio → `Jenkinsfile`).
- `prometheus.yml`: jobs `produccion` (127.0.0.1:5000) y `staging` (127.0.0.1:5001), scrape cada 5 s.
- `grafana/`: `custom.ini` (anónimo solo Viewer, sin registro), fuente Prometheus, dashboard «Sistema Alumnos - Producción (seguridad)» y reglas de alerta «Fuerza bruta en produccion» y «Peticiones sospechosas en produccion».

Las claves (admin de Jenkins, admin de Grafana, API de ZAP) se generan aleatoriamente en `C:\ev3lab\secrets` y **no** están en el repositorio.

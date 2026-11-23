# Bitácora de actividades · Parcial 3 OCY1102 · Vicente Hueichapan

Registro cronológico de todo lo realizado el 23-11-2026 (hora local de Chile, UTC-3).

| Hora | Actividad (etapa del SDLC) | Resultado | Evidencia |
|---|---|---|---|
| 16:05 | Análisis del enunciado, la pauta y el código entregado (revisión manual) | 10 vulnerabilidades identificadas en `app.py` | — |
| 16:10 | Revisión local previa: Bandit, pip-audit, pytest y `simular_ataque.py` contra el código original | Bandit 2H/2M/1L; 19 CVE; ataque: clave `admin` encontrada, SQLi y XSS exitosos | — |
| 16:25 | Montaje del laboratorio portable en `C:\ev3lab` (Jenkins, ZAP, Prometheus, Grafana, Python 3.13) | Todos los servicios en 127.0.0.1 (ver `laboratorio-windows/`) | — |
| 16:35 | Commit `3f77aaa`: código inicial vulnerable · commit `a01e95d`: pipeline base adaptado a Windows | — | — |
| 16:37 | **Build #1** (Build → Test → Deploy Producción) | SUCCESS, 9/9 pruebas, producción 1.0.1+a01e95d | Ev. 1 |
| 16:47 | Commit `dfbc6e3` (deploy desacoplado) · commit `be750c1` (SEC: SAST, SCA, staging, ZAP, gate) | — | Ev. 5 |
| 16:48 | **Build #2**: revisiones de seguridad sobre el código vulnerable | UNSTABLE: Bandit 2/2/1, pip-audit 19 vuln., ZAP 1/3/1; producción bloqueada por el gate | Ev. 2, 5, 6 |
| 16:57 | Commit `958f42a`: `.github/dependabot.yml` | Dependabot abre 6 PR (#1–#6) | Ev. 10 |
| 16:58 | **Build #3** | UNSTABLE (sin cambios de código) | — |
| 16:59–17:00 | Commits `VULN-01` … `VULN-10` (uno por vulnerabilidad, pytest OK en cada paso) + `95a43b5` (pruebas de regresión de seguridad) | — | Ev. 3 |
| 17:04 | **Build #4** | UNSTABLE solo por dependencias: 19/19 pruebas, Bandit 0/0/0, ZAP 0/0/0, pip-audit 19 vuln. | Ev. 3, 6 |
| 17:09–17:11 | Fusión de los PR de Dependabot #4, #2, #1, #6, #5, #3; verificación local (pytest, pip-audit, Bandit); commit `57b2db1` fija las transitivas | 0 vulnerabilidades | Ev. 11, 12 |
| 17:12 | **Build #5** | **SUCCESS**: 19/19, Bandit 0/0/0, pip-audit 0, ZAP 0/0/0, producción 1.0.5+57b2db1 | Ev. 11, 13, 14 |
| 17:15:23 | Ataque simulado n.º 1 contra producción (`simular_ataque.py`) | 26/31 intentos bloqueados (429); SQLi y XSS sin efecto | Ev. 8 |
| 17:15:40 | Grafana: alerta «Fuerza bruta en produccion» → Alerting | Detectado en ~17 s | Ev. 8 |
| 17:16:20 | Alerta → Normal | Incidente contenido | Ev. 9 |
| 17:16:22 / 17:18:22 | Ataques n.º 2 y 3 | Ambas alertas (fuerza bruta y peticiones sospechosas) en Firing a las 17:18:40 | Ev. 8 |
| 17:19:20 | Alertas → Normal; revisión de logs y métricas | 93 logins fallidos, 88 bloqueados, 0 exitosos | Ev. 9 |
| 17:25 | Documentación: `REGISTRO_SEGURIDAD.md`, `TRAZABILIDAD.md`, esta bitácora, `laboratorio-windows/` | — | Ev. 4, 9, 12, 13, 14 |

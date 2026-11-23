# Registro de trazabilidad - Sistema Alumnos

Cada fila la agrega Jenkins al terminar un build (`scripts/trazabilidad.py`).

| Build | Fecha (UTC) | Versión | Commit | Mensaje del commit | Pruebas | Bandit H/M/L | pip-audit | ZAP H/M/L | Resultado | Producción |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2026-11-23 19:44 | 1.0.1+a01e95d | `a01e95d` | LAB: adapta el pipeline base a Jenkins en Windows (laboratorio sin Doc | 9/9 OK | n/a | n/a | n/a | SUCCESS | 1.0.1+a01e95d |
| 2 | 2026-11-23 19:50 | 1.0.2+be750c1 | `be750c1` | SEC: etapas SAST (Bandit), SCA (pip-audit), Deploy Staging, DAST (OWAS | 9/9 OK | 2/2/1 | 19 vuln. | 1/3/1 | UNSTABLE | no desplegado |
| 3 | 2026-11-23 20:00 | 1.0.3+958f42a | `958f42a` | DEP: configuración de Dependabot (pip, revisión diaria) | 9/9 OK | 2/2/1 | 19 vuln. | 1/3/1 | UNSTABLE | no desplegado |
| 4 | 2026-11-23 20:06 | 1.0.4+95a43b5 | `95a43b5` | TEST: pruebas de regresión de seguridad (VULN-02..VULN-10) y resumen d | 19/19 OK | 0/0/0 | 19 vuln. | 0/0/0 | UNSTABLE | no desplegado |
| 5 | 2026-11-23 20:14 | 1.0.5+57b2db1 | `57b2db1` | DEP: fija dependencias transitivas (MarkupSafe, itsdangerous, click, b | 19/19 OK | 0/0/0 | 0 vuln. | 0/0/0 | SUCCESS | 1.0.5+57b2db1 |

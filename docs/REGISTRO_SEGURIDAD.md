# Registro de seguridad · Sistema Alumnos

Estudiante: **Vicente Hueichapan**   Repositorio: https://github.com/vicentehueichapan/CiberseguridadDuoc   Fecha: **23-11-2026**

Cada fila se puede seguir hasta un **build de Jenkins** (job `sistema-alumnos`) y un **commit** (`VULN-xx` / `DEP` / `SEC` en el mensaje).
Horas en hora local de Chile (UTC-3). Entorno: laboratorio equivalente al del curso, ejecutado en Windows sin Docker (ver `laboratorio-windows/README.md`).

## 1. Revisiones de seguridad realizadas

| # | Etapa del SDLC | Herramienta / técnica | Build | Resultado (resumen) |
|---|---|---|---|---|
| R1 | Código (SAST) | Bandit 1.8.6 en la etapa `Security Review (SAST)` | #2 (antes) → #4 y #5 (después) | **Build #2: 2 High / 2 Medium / 1 Low** (B324 MD5, B201 `debug=True`, B608 SQL por concatenación, B104 bind `0.0.0.0`, B105 clave embebida). **Build #4 y #5: 0 / 0 / 0** («No issues identified») |
| R2 | Dependencias (SCA) | pip-audit 2.9.0 en la etapa `Dependency Management` | #2 (antes) → #5 (después) | **Build #2: 19 vulnerabilidades en 4 paquetes** (Flask 2, Werkzeug 10, Jinja2 5, gunicorn 2). **Build #5: 0** («No known vulnerabilities found») |
| R3 | Pruebas dinámicas (DAST) | OWASP ZAP 2.16.1 (spider + pasivo + activo) sobre staging :5001 | #2 (antes) → #4 y #5 (después) | **Build #2: 1 High / 3 Medium / 1 Low**. **Build #4 y #5: 0 / 0 / 0** (solo 2 informativas) |
| R4 | Revisión manual | Lectura de `app.py` + `scripts/simular_ataque.py` | — | 10 vulnerabilidades (VULN-01…VULN-10); 5 de ellas no las detecta Bandit (XSS, CSRF, fuerza bruta, cabeceras, divulgación de errores) |
| R5 | Pruebas de regresión | `tests/test_seguridad.py` (10 pruebas) en la etapa `Test` | #4, #5 | Con el código original las 10 fallan; desde el build #4: **19/19 OK** |
| R6 | Producción | Grafana + Prometheus (dashboard «Sistema Alumnos - Producción (seguridad)» y 2 reglas de alerta) | — | Incidente de fuerza bruta detectado y contenido (sección 4) |

## 2. Vulnerabilidades identificadas y corregidas

Build que detecta: **#2** (Bandit/ZAP) o revisión manual. Build que verifica: **#4** (código) y **#5** (todo en verde y desplegado en producción).

| ID | Vulnerabilidad (CWE) | Detectada por | Ubicación (original) | Riesgo | Corrección aplicada | Commit | Build que lo verifica |
|---|---|---|---|---|---|---|---|
| VULN-01 | Secreto embebido en el código: `SECRET_KEY` (CWE-798 / CWE-259) | Bandit B105, revisión manual | `app.py:20` | Alto: con la clave publicada se pueden falsificar cookies de sesión | `SECRET_KEY` desde variable de entorno; si falta, `secrets.token_hex(32)` por proceso. Cookie `HttpOnly` + `SameSite=Strict` | `d47a5e3` | #4 (Bandit 0) |
| VULN-02 | Inyección SQL en `/alumnos/buscar` (CWE-89) | Bandit B608, `simular_ataque.py`, revisión manual | `app.py:205` | Crítico: `UNION SELECT … FROM sqlite_master` expuso la estructura de la BD | Consulta parametrizada `LIKE ? ESCAPE '\'`; se escapan `%` y `_`; largo máximo 100 | `14cf531` | #4 (Bandit 0 + prueba `test_vuln02_*`) |
| VULN-03 | Divulgación de información en errores (CWE-209) | Revisión manual | `app.py:209` | Medio: devolvía el error de SQLite y la consulta SQL completa | Mensaje genérico `{"error": "Error interno"}`; detalle solo en el log; `errorhandler(500)` | `1d4af88` | #4 (`test_vuln03_*`) |
| VULN-04 | XSS reflejado en `/hello` (CWE-79) | **ZAP (High)**, `simular_ataque.py`, revisión manual | `app.py:153` | Alto: ejecución de JavaScript en el navegador de la víctima | Plantilla Jinja2 con autoescape (`{{ name }}`) + CSP `script-src 'self'` | `480a7ff` | #4 (ZAP 0 High) |
| VULN-05 | Hash débil (MD5 sin sal) y clave por defecto `admin` embebida (CWE-327 / CWE-916 / CWE-798) | Bandit B324 (High), `simular_ataque.py` (clave encontrada) | `app.py:21-22, 221` | Crítico: acceso de administrador con `admin/admin` | Hash scrypt/pbkdf2 de Werkzeug (`check_password_hash`) desde `ADMIN_CLAVE_HASH`; sin hash configurado el acceso admin queda deshabilitado; comparación en tiempo constante | `aaab413` | #4 (Bandit 0 + `test_vuln05_*`) |
| VULN-06 | Sin protección contra fuerza bruta (CWE-307) | `simular_ataque.py`, revisión manual | `app.py:213` | Alto | Máximo 5 fallos por IP en 300 s → HTTP 429; cada bloqueo suma `peticiones_sospechosas_total{tipo="fuerza_bruta"}` | `f7c2ee8` | #4 (`test_vuln06_*`) y producción (sección 4) |
| VULN-07 | Sin token anti-CSRF en `/login` (CWE-352) | **ZAP (Medium)** «Absence of Anti-CSRF Tokens» | `app.py:69` (formulario) | Medio | Token aleatorio por sesión en campo oculto `csrf_token`, validado con `hmac.compare_digest`; sin token → 400 | `1ed66ee` | #4 (ZAP 0 Medium) |
| VULN-08 | Depurador Werkzeug activo y escucha en todas las interfaces (CWE-94 / CWE-605) | Bandit B201 (High) + B104 (Medium) | `app.py:241` | Alto: el depurador permite ejecutar código remoto | `debug=False`, `host="127.0.0.1"` al ejecutar directo; en los entornos se usa un servidor WSGI | `42fce96` | #4 (Bandit 0) |
| VULN-09 | Faltan cabeceras de seguridad (CWE-693 / CWE-1021) | **ZAP (2 Medium + 1 Low)**: CSP, anti-clickjacking, X-Content-Type-Options | todas las respuestas | Medio | `after_request` agrega CSP, `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy`, `Permissions-Policy`, COOP/CORP, `Cache-Control: no-store` | `af3708d` | #4 (ZAP 0/0/0) |
| VULN-10 | Inyección en logs con el usuario del login (CWE-117) | Revisión manual | `app.py:226` | Bajo | `para_log()` reemplaza caracteres de control y limita el largo | `e2e51e1` | #4 (`test_vuln10_*`) |

Pruebas de regresión: commit `95a43b5` (`tests/test_seguridad.py`).

Ataque simulado (`scripts/simular_ataque.py`), antes y después:

| Ataque | Código original (prueba local) | Producción corregida 1.0.5+57b2db1 (17:15:23) |
|---|---|---|
| Fuerza bruta (31 intentos) | **Clave encontrada: `admin`** | Ninguna clave funcionó; 26 intentos bloqueados (HTTP 429) |
| Inyección SQL | **Expuso la estructura de la BD** | No devolvió datos internos |
| XSS reflejado | **Script reflejado sin escapar** | Escapado (`&lt;script&gt;`) |

Riesgo residual aceptado: `/metrics` no tiene autenticación porque Prometheus lo consulta localmente y la app solo escucha en 127.0.0.1. En un despliegue real se protegería con red privada o autenticación.

## 3. Resultados de OWASP ZAP

Build #2 (código original, staging `1.0.2+be750c1`): **1 High / 3 Medium / 1 Low**. Builds #4 y #5: **0 / 0 / 0** (2 informativas).

| Alerta de ZAP | Riesgo | URL de ejemplo | VULN relacionada | Cómo se mitiga | ¿Mitigada? Build |
|---|---|---|---|---|---|
| Cross Site Scripting (Reflected) | High | `/hello?name=</h1><scrIpt>alert(1);</scRipt><h1>` | VULN-04 | Autoescape Jinja2 + CSP | Sí · #4 |
| Absence of Anti-CSRF Tokens | Medium | `/` (2 URL) | VULN-07 | Token `csrf_token` por sesión | Sí · #4 |
| Content Security Policy (CSP) Header Not Set | Medium | `/` (5 URL) | VULN-09 | Cabecera CSP restrictiva | Sí · #4 |
| Missing Anti-clickjacking Header | Medium | `/` (3 URL) | VULN-09 | `X-Frame-Options: DENY` + `frame-ancestors 'none'` | Sí · #4 |
| X-Content-Type-Options Header Missing | Low | `/` (6 URL) | VULN-09 | `X-Content-Type-Options: nosniff` | Sí · #4 |

Nota: en este escaneo ZAP no levantó la inyección SQL (VULN-02). La detectaron Bandit (B608), la revisión manual y el ataque simulado; por eso el pipeline combina SAST, SCA y DAST.

## 4. Monitoreo e incidentes

Configuración (Evidencia 7): fuente de datos **Prometheus** (scrape cada 5 s de producción :5000 y staging :5001); dashboard **«Sistema Alumnos - Producción (seguridad)»** con disponibilidad, versión desplegada, logins fallidos/min, peticiones sospechosas por tipo, códigos HTTP y latencia p95; 2 reglas de alerta (evaluación cada 10 s):
- **Fuerza bruta en produccion** (severidad alta): `sum(increase(login_fallidos_total{job="produccion"}[1m])) > 10`.
- **Peticiones sospechosas en produccion** (severidad media): `sum(increase(peticiones_sospechosas_total{job="produccion",tipo!="fuerza_bruta"}[1m])) > 0`.

| Hora | Panel / métrica de Grafana | Qué se observó | Entorno | Clasificación | Acción de respuesta | Verificación |
|---|---|---|---|---|---|---|
| 17:15:23 → 17:15:40 | «Logins fallidos por minuto» + alerta «Fuerza bruta en produccion» Pending 17:15:30 → **Alerting 17:15:40** | 31 logins fallidos en ~1 s desde una misma IP (127.0.0.1); panel HTTP muestra 429 | Producción :5000 (1.0.5+57b2db1) | Incidente de seguridad: intento de acceso no autorizado (fuerza bruta), severidad **alta** | Contención automática del control VULN-06: desde el 6º intento la IP recibe HTTP 429. Análisis de `app.err.log`: «Login fallido para el usuario 'admin' desde 127.0.0.1» y «Login bloqueado (fuerza bruta)» | `login_exitosos_total` = 0 (ningún acceso). La alerta volvió a **Normal 17:16:20** |
| 17:16:22 y 17:18:22 | Mismo panel + «Peticiones sospechosas por tipo» (`fuerza_bruta`, `sqli`, `xss`) | Repetición del ataque: logins fallidos, 1 SQLi en `/alumnos/buscar`, 1 XSS en `/hello` | Producción :5000 | Fuerza bruta (alta) + intento de explotación web (media) | Ambas alertas en **Firing** (17:18:40). Se verificó que las respuestas no exponen datos (VULN-02/04 corregidas). Respuesta recomendada en un entorno real: bloquear la IP en el firewall/WAF y revisar cuentas | Historial de la regla: Pending → Alerting → Normal (17:19:20). Total: 93 logins fallidos, 88 bloqueados con 429, 0 accesos exitosos |

## 5. Gestión de dependencias

| Paquete | Versión inicial | Vulnerabilidades (IDs de pip-audit, build #2) | Versión final | Origen del cambio | ¿Pruebas, pip-audit y ZAP siguen OK? Build |
|---|---|---|---|---|---|
| Flask | 2.2.2 | PYSEC-2023-62, PYSEC-2026-2151 | 3.1.3 | PR Dependabot **#2** | 19/19 · 0 vuln. · ZAP 0/0/0 · **#5** |
| Werkzeug | 2.2.2 | PYSEC-2023-57, PYSEC-2023-58, PYSEC-2023-221, PYSEC-2026-2043, -2044, -2045, -2046, PYSEC-2026-2320, PYSEC-2026-3417, PYSEC-2026-4312 | 3.1.9 | PR Dependabot **#4** | 19/19 · 0 vuln. · ZAP 0/0/0 · **#5** |
| Jinja2 | 3.1.2 | PYSEC-2026-1471, -1472, -1473, -1474, -1475 | 3.1.6 | PR Dependabot **#1** | 19/19 · 0 vuln. · ZAP 0/0/0 · **#5** |
| gunicorn | 21.2.0 | PYSEC-2026-1433, PYSEC-2026-1434 | 27.0.1 | PR Dependabot **#6** | 19/19 · 0 vuln. · ZAP 0/0/0 · **#5** |
| prometheus-client | 0.17.1 | — | 0.26.0 | PR Dependabot **#5** | 19/19 · 0 vuln. · **#5** |
| pytest (dev) | 8.3.4 | — | 9.2.0 | PR Dependabot **#3** | 19/19 · **#5** |
| MarkupSafe, itsdangerous, click, blinker | transitivas sin fijar | — | 3.0.4 · 2.2.0 · 8.5.1 · 1.9.0 | Manual, commit `57b2db1` | 0 vuln. · **#5** |
| waitress | — | — | 3.0.2 | Manual, commit `a01e95d` (servidor WSGI del laboratorio Windows) | 0 vuln. · **#5** |

Proceso:
1. `pip-audit` en el pipeline detecta los CVE y marca el build UNSTABLE, lo que bloquea producción (builds #2 a #4).
2. `.github/dependabot.yml` (commit `958f42a`, revisión diaria) hizo que Dependabot abriera 6 PR, uno por paquete.
3. Se fusionaron los 6 PR. Los conflictos en `requirements.txt` (líneas contiguas) se resolvieron conservando cada actualización. Antes del push se verificó localmente: pytest 19/19, pip-audit sin vulnerabilidades y Bandit sin hallazgos.
4. El push disparó el build **#5** por pollSCM: pruebas, Bandit, pip-audit y ZAP en verde, y despliegue en producción `1.0.5+57b2db1`. Esto confirma que las actualizaciones no introdujeron vulnerabilidades ni rompieron funcionalidad.

## 6. Trazabilidad

Registro completo generado por Jenkins: [`docs/TRAZABILIDAD.md`](TRAZABILIDAD.md) (copia del artefacto `reports/TRAZABILIDAD.md` del último build). Bitácora de actividades: [`docs/BITACORA.md`](BITACORA.md).

| Actividad | Hallazgo | Build que lo detectó | Commit / PR que lo resolvió | Build que lo verificó | Versión en producción |
|---|---|---|---|---|---|
| Revisión de seguridad (Bandit) | B324 MD5 / B201 debug / B608 SQL / B104 / B105 | #2 (2/2/1) | `aaab413` (VULN-05), `42fce96` (VULN-08), `14cf531` (VULN-02), `d47a5e3` (VULN-01) | #4 (0/0/0) | 1.0.5+57b2db1 |
| Prueba automatizada (OWASP ZAP) | XSS reflejado / CSRF / CSP / clickjacking / nosniff | #2 (1/3/1) | `480a7ff` (VULN-04), `1ed66ee` (VULN-07), `af3708d` (VULN-09) | #4 (0/0/0) | 1.0.5+57b2db1 |
| Gestión de dependencias (Dependabot) | 19 vulnerabilidades en Flask/Werkzeug/Jinja2/gunicorn | #2 (19 vuln.) | PR #1, #2, #4, #5, #6 (+ #3) y `57b2db1` | #5 (0 vuln.) | 1.0.5+57b2db1 |

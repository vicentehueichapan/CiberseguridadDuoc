"""Pruebas de regresión de seguridad: cada una falla con el código vulnerable original."""
import re

import pytest
from werkzeug.security import generate_password_hash

import app as modulo_app


@pytest.fixture
def client():
    modulo_app.app.config["TESTING"] = True
    with modulo_app.app.test_client() as c:
        yield c


def _token(client):
    return re.search(r'name="csrf_token" value="([^"]+)"', client.get("/").get_data(as_text=True)).group(1)


def test_vuln02_sqli_no_filtra_esquema(client):
    r = client.get("/alumnos/buscar", query_string={"nombre": "zzz' UNION SELECT 0, name, sql, 0 FROM sqlite_master --"})
    assert r.status_code == 200
    assert r.get_json() == []


def test_vuln02_comodines_literales(client):
    assert client.get("/alumnos/buscar?nombre=%25").get_json() == []


def test_vuln03_error_no_expone_consulta(client):
    r = client.get("/alumnos/buscar?nombre='")
    assert "consulta" not in r.get_data(as_text=True)


def test_vuln04_xss_escapado(client):
    r = client.get("/hello", query_string={"name": "<script>alert(1)</script>"})
    cuerpo = r.get_data(as_text=True)
    assert "<script>" not in cuerpo and "&lt;script&gt;" in cuerpo


def test_vuln05_clave_admin_por_defecto_no_funciona(client):
    r = client.post("/login", data={"usuario": "admin", "clave": "admin", "csrf_token": _token(client)})
    assert r.status_code == 401


def test_vuln05_login_correcto_con_hash(client, monkeypatch):
    monkeypatch.setattr(modulo_app, "ADMIN_CLAVE_HASH", generate_password_hash("Clave-de-prueba-123"))
    monkeypatch.setattr(modulo_app, "_fallos_por_ip", {})
    r = client.post("/login", data={"usuario": "admin", "clave": "Clave-de-prueba-123", "csrf_token": _token(client)})
    assert r.status_code == 200


def test_vuln06_fuerza_bruta_bloqueada(client, monkeypatch):
    monkeypatch.setattr(modulo_app, "_fallos_por_ip", {})
    token = _token(client)
    codigos = [client.post("/login", data={"usuario": "admin", "clave": f"x{i}", "csrf_token": token}).status_code
               for i in range(modulo_app.MAX_FALLOS + 2)]
    assert codigos[-1] == 429


def test_vuln07_login_sin_csrf_rechazado(client):
    assert client.post("/login", data={"usuario": "admin", "clave": "admin"}).status_code == 400


def test_vuln09_cabeceras_seguridad(client):
    h = client.get("/").headers
    assert "frame-ancestors 'none'" in h["Content-Security-Policy"]
    assert h["X-Content-Type-Options"] == "nosniff"
    assert h["X-Frame-Options"] == "DENY"


def test_vuln10_log_sin_saltos_de_linea():
    assert "\n" not in modulo_app.para_log("admin\nINFO falso")

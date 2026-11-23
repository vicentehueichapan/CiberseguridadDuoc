// Jenkinsfile - Pipeline de "Sistema Alumnos" (SecureDev · Evaluación Parcial 3 · OCY1102)
//
// Versión COMPLETA: Build -> Test -> SAST (Bandit) -> SCA (pip-audit) -> Deploy Staging -> DAST (ZAP) -> [gate] -> Producción.
// Agente: Jenkins en Windows (laboratorio sin Docker) -> pasos bat/powershell en lugar de sh.
// Las variables PYTHON, DEPLOY_ROOT, REGISTRO_TRAZABILIDAD, etc. las define la configuración global de Jenkins.
// Las etapas de seguridad marcan UNSTABLE ante hallazgos y la condición when impide desplegar a producción.
pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 40, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    // Revisa GitHub cada ~2 minutos: cada push (tuyo o un PR de Dependabot fusionado) dispara un build.
    triggers {
        pollSCM('H/2 * * * *')
    }

    environment {
        PIP_DISABLE_PIP_VERSION_CHECK = '1'
    }

    stages {
        stage('Build') {
            steps {
                script {
                    // Versión = 1.0.<nº de build>+<commit corto>: une cada despliegue con su commit (trazabilidad)
                    def sha = powershell(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    env.APP_VERSION = "1.0.${env.BUILD_NUMBER}+${sha}"
                }
                echo "Versión de este build: ${env.APP_VERSION}"
                bat 'git log -1 --format="Commit %%h de %%an: %%s"'
                // Cada build parte limpio: sin reportes viejos y con un entorno virtual nuevo
                bat 'if exist .venv rmdir /s /q .venv & if exist reports rmdir /s /q reports & mkdir reports'
                bat '"%PYTHON%" -m venv .venv'
                bat '.venv\\Scripts\\python.exe -m pip install --quiet -r requirements.txt -r requirements-dev.txt'
                bat '.venv\\Scripts\\python.exe -m compileall -q app.py'
            }
        }

        stage('Test') {
            steps {
                bat '.venv\\Scripts\\python.exe -m pytest --junitxml=reports/junit.xml'
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'reports/junit.xml'
                }
            }
        }

        // [SEGURIDAD] Revisión estática del código (SAST) con Bandit.
        // Política: cualquier hallazgo Medium o High marca el build UNSTABLE y bloquea producción.
        stage('Security Review (SAST)') {
            steps {
                bat '"%BANDIT%" -f json -o reports/bandit.json app.py & exit /b 0'   // todas las severidades (trazabilidad)
                bat '"%BANDIT%" -f txt -o reports/bandit.txt app.py & exit /b 0'
                bat 'type reports\\bandit.txt'
                script {
                    int rc = bat(returnStatus: true, script: '"%BANDIT%" -q -ll app.py')
                    if (rc != 0) {
                        unstable('Bandit encontró hallazgos Medium/High: revisa reports/bandit.txt')
                    }
                }
            }
        }

        // [SEGURIDAD] Análisis de composición (SCA) de requirements.txt con pip-audit (base OSV/PyPI).
        // Política: cualquier vulnerabilidad conocida en una dependencia marca UNSTABLE y bloquea producción.
        stage('Dependency Management') {
            steps {
                bat '"%PIP_AUDIT%" -r requirements.txt -f json -o reports/pip-audit.json & exit /b 0'
                script {
                    int rc = bat(returnStatus: true, script: '"%PIP_AUDIT%" -r requirements.txt --desc on > reports\\pip-audit.txt 2>&1')
                    bat 'type reports\\pip-audit.txt'
                    if (rc != 0) {
                        unstable('pip-audit encontró dependencias vulnerables: revisa reports/pip-audit.txt')
                    }
                }
            }
        }

        // [ZAP] Despliegue en staging (puerto 5001) para el análisis dinámico.
        stage('Deploy Staging') {
            steps {
                powershell '& .\\scripts\\deploy.ps1 -Entorno staging -Puerto 5001'
            }
        }

        // [ZAP] Análisis dinámico (DAST) con OWASP ZAP: spider + pasivo + activo sobre staging.
        // zap_scan.py termina con código 2 si hay alertas High/Medium -> UNSTABLE.
        stage('DAST - OWASP ZAP') {
            steps {
                script {
                    int rc = bat(returnStatus: true, script: '"%PYTHON%" scripts\\zap_scan.py http://127.0.0.1:5001')
                    if (rc == 2) {
                        unstable('OWASP ZAP encontró alertas High/Medium: revisa reports/zap-report.html')
                    } else if (rc != 0) {
                        error("El escaneo de ZAP falló (código ${rc})")
                    }
                }
            }
        }

        stage('Deploy Producción') {
            // [GATE] Solo se despliega a producción si TODAS las etapas anteriores quedaron en verde
            // (pruebas OK, sin hallazgos Medium/High de Bandit, sin CVE y sin alertas High/Medium de ZAP).
            when {
                expression { currentBuild.currentResult == 'SUCCESS' }
            }
            steps {
                powershell '& .\\scripts\\deploy.ps1 -Entorno produccion -Puerto 5000'
                script { env.PRODUCCION = env.APP_VERSION }
            }
        }
    }

    post {
        always {
            // Registro de trazabilidad: build <-> versión <-> commit <-> pruebas <-> hallazgos <-> despliegue
            withEnv(["RESULTADO=${currentBuild.currentResult}"]) {
                bat '"%PYTHON%" scripts\\trazabilidad.py'
            }
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
        }
    }
}

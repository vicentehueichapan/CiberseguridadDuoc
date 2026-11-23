// Jenkinsfile - Pipeline de "Sistema Alumnos" (SecureDev · Evaluación Parcial 3 · OCY1102)
//
// Versión BASE: construye, prueba y despliega en producción.
// Agente: Jenkins en Windows (laboratorio sin Docker) -> pasos bat/powershell en lugar de sh.
// Las variables PYTHON, DEPLOY_ROOT, REGISTRO_TRAZABILIDAD, etc. las define la configuración global de Jenkins.
// Los marcadores  >>> [ETIQUETA]  indican dónde agregar las etapas de seguridad.
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

        // >>> [SEGURIDAD]: aquí van las etapas "Security Review (SAST)" y "Dependency Management"

        // >>> [ZAP]: aquí van las etapas "Deploy Staging" y "DAST - OWASP ZAP"

        stage('Deploy Producción') {
            // >>> [GATE]: aquí va la condición "when" que protege producción
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

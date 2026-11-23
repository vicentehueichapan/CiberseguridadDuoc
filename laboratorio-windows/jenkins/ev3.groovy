// Configuracion inicial del laboratorio EV3 (idempotente; se ejecuta en cada arranque de Jenkins).
import jenkins.model.*
import hudson.security.*
import hudson.slaves.EnvironmentVariablesNodeProperty
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.*

def j = Jenkins.get()
def S = File.separator
def lab = 'C:' + S + 'ev3lab'
def p = { String rel -> lab + S + rel.replace('/', S) }

// 1) Usuario administrador (clave aleatoria en secrets/jenkins_admin_password.txt)
def clave = new File(p('secrets/jenkins_admin_password.txt')).text.trim()
def realm = new HudsonPrivateSecurityRealm(false)
if (realm.getUser('admin') == null) { realm.createAccount('admin', clave) }
j.setSecurityRealm(realm)

// 2) Permisos: admin todo; anonimo solo lectura (Jenkins escucha solo en 127.0.0.1)
def auth = new GlobalMatrixAuthorizationStrategy()
auth.add(Jenkins.ADMINISTER, 'admin')
auth.add(Jenkins.READ, 'anonymous')
auth.add(hudson.model.Item.READ, 'anonymous')
auth.add(hudson.model.Item.DISCOVER, 'anonymous')
auth.add(hudson.model.Item.EXTENDED_READ, 'anonymous')   // ver la configuracion del job (sin secretos) en modo lectura
auth.add(hudson.model.View.READ, 'anonymous')
j.setAuthorizationStrategy(auth)
j.setNumExecutors(1)

// 3) Variables de entorno del laboratorio (equivalen a la imagen Docker del curso)
def props = j.getGlobalNodeProperties()
props.removeAll(EnvironmentVariablesNodeProperty)
props.add(new EnvironmentVariablesNodeProperty([
  new EnvironmentVariablesNodeProperty.Entry('PYTHON', p('python/cpython-3.13.15-windows-x86_64-none/python.exe')),
  new EnvironmentVariablesNodeProperty.Entry('BANDIT', p('herramientas/Scripts/bandit.exe')),
  new EnvironmentVariablesNodeProperty.Entry('PIP_AUDIT', p('herramientas/Scripts/pip-audit.exe')),
  new EnvironmentVariablesNodeProperty.Entry('ZAP_URL', 'http://127.0.0.1:8090'),
  new EnvironmentVariablesNodeProperty.Entry('ZAP_API_KEY_FILE', p('secrets/zap_api_key.txt')),
  new EnvironmentVariablesNodeProperty.Entry('DEPLOY_ROOT', p('despliegues')),
  new EnvironmentVariablesNodeProperty.Entry('REGISTRO_TRAZABILIDAD', p('registro/TRAZABILIDAD.md')),
  new EnvironmentVariablesNodeProperty.Entry('PYTHONUTF8', '1'),
  new EnvironmentVariablesNodeProperty.Entry('PYTHONIOENCODING', 'utf-8')
]))

// 4) URL de Jenkins
def loc = JenkinsLocationConfiguration.get()
loc.setUrl('http://localhost:8080/')
loc.save()

// 5) Job de pipeline desde GitHub (Jenkinsfile del repositorio)
if (j.getItem('sistema-alumnos') == null) {
  def job = j.createProject(WorkflowJob, 'sistema-alumnos')
  job.setDescription('Pipeline CI/CD seguro de Sistema Alumnos - Evaluacion Parcial 3 OCY1102 - Vicente Hueichapan')
  def scm = new GitSCM(GitSCM.createRepoList('https://github.com/vicentehueichapan/CiberseguridadDuoc.git', null),
                       [new BranchSpec('*/main')], null, null, [])
  job.setDefinition(new CpsScmFlowDefinition(scm, 'Jenkinsfile'))
  job.save()
}
j.save()
println('EV3: configuracion aplicada')

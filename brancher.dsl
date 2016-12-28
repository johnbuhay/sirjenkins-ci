@Grab(group='org.yaml', module='snakeyaml', version='1.17')
import org.yaml.snakeyaml.Yaml

def ci = [:]
ci['repo'] = 'jnbnyc/sirjenkins-ci'
ci['branch'] = 'master'

def repo_path = WORKSPACE
println "Repo source code path: $repo_path"

// discover remote branches
println "Discovering branches"
def branches = [:]
def remote_branches_refs = "$repo_path/.git/refs/remotes/origin/"
new File(remote_branches_refs).eachFileRecurse {
    def ref_path = it.toString()
    branches.put(ref_path - remote_branches_refs,
        readFileFromWorkspace(ref_path))
}

def sirjenkins = new Yaml().load(
  readFileFromWorkspace('sirjenkins.yml')
)

def job_definition = sirjenkins.jessie
def job_name = job_definition.name.replace(' ','-')
def build_type = job_definition.build_type
def docker_repo = job_definition.override_docker_repo
def repo = job_definition.scm

branches.each {
  def this_branch = it.key
  def this_sha = it.value
  println "${this_branch} : ${this_sha}"
  
  folder(job_name)
  job("${job_name}/${job_name}-${this_branch}") {
    multiscm {
      git {
        remote {
            github ci.repo
            branch ci.branch
            credentials 'github-api-jnbnyc'
        }
        extensions {
            relativeTargetDirectory('ci')
        }
      }
      git {
        remote {
            github repo
            branch this_branch
            credentials 'github-api-jnbnyc'
        }
      }
        
    }
    steps {
      shell """
        export BUILD_TYPE=${build_type}
        export DOCKER_REPO=\"${docker_repo}/${job_name}\"
        export PROJECT_BRANCH=${this_branch}
        export CONTAINER_BUILD_CONTEXT=${job_name}
        ci/bin/build.sh
        """.stripIndent()
    }
  }
}

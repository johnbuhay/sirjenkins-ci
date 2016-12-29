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

sirjenkins.each {
    def job_definition = it.job
    def job_name = job_definition.name.replaceAll(' ','-')
    def build_type = job_definition.build_type
    def docker_repo = job_definition.docker.override_repo
    def build_context = job_definition.docker.build_context ?: '.'
    def repo = job_definition.scm
    def job_desc = job_definition.description

    branches.each {
      def this_branch = it.key.replaceAll(' ','-')
      def this_sha = it.value
      println "${this_branch} : ${this_sha}"
      
      folder(job_name)
      job("${job_name}/${job_name}-${this_branch}") {
        description(job_desc)
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
            export CONTAINER_BUILD_CONTEXT=${build_context}
            ci/bin/build.sh
            """.stripIndent()
        }
      }
    }
}

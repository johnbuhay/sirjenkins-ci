@Grab(group='org.yaml', module='snakeyaml', version='1.17')
import org.yaml.snakeyaml.Yaml

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
def repo = 'https://github.com/jnbnyc/docker-shelf.git'
def job_definition = sirjenkins.jessie
def job_name = job_definition.name.replace(' ','-')
def build_type = job_definition.build_type
def docker_repo = job_definition.override_docker_repo

branches.each {
  def branch = it.key
  def sha = it.value
  println "${branch} : ${sha}"
  
  folder(job_name)
  job("${job_name}/${job_name}-${branch}") {
    scm {
        git(repo, branch)
    }
    steps {
      shell ("docker build -t ${docker_repo}/${job_name} ${job_name}")
    }
  }
}

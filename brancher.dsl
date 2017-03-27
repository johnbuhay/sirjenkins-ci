@Grab(group='org.yaml', module='snakeyaml', version='1.17')
import org.yaml.snakeyaml.Yaml
import org.yaml.snakeyaml.DumperOptions

CI_BRANCH = 'master'
CI_DIR = 'ci'
SOURCE_DIR = 'source'
SCANNING_FOR = System.getenv('SCANNING_FOR') ?: 'sirjenkins'
WORKSPACE = System.getenv('WORKSPACE') ?: Thread.currentThread().executable.workspace
DEFAULTS_FILE = new Yaml().load(new File("${WORKSPACE}/${CI_DIR}/${SCANNING_FOR}-defaults-global.yaml").text)

defaults = [:]
defaults['logrotate'] = [:]
defaults += DEFAULTS_FILE

CI_REMOTE_URL = defaults.ci_remote_url ?: "${defaults.scm_url}/${defaults.ci_repo}"
CI_SCM_CREDS = defaults.scm_credentials
SOURCE_PATH = "${WORKSPACE}/${SOURCE_DIR}"
// def ci = [:]
// ci['repo'] = 'jnbnyc/sirjenkins-ci'
// ci['branch'] = 'master'
//
// def repo_path = WORKSPACE
// println "Repo source code path: $repo_path"

// discover remote branches
println "Discovering branches"
def branches = [:]
def remote_branches_refs = "${SOURCE_PATH}/.git/refs/remotes/origin/"
new File(remote_branches_refs).eachFileRecurse {
    def ref_path = it.toString()
    if(it.isFile()) {
      branches.put(ref_path - remote_branches_refs,
          readFileFromWorkspace(ref_path))
    }
}

// def sirjenkins = new Yaml().load(
//   readFileFromWorkspace('sirjenkins.yml')
// )

// sirjenkins.each {
//     def job_definition = it.job
//     def job_name = job_definition.name.replaceAll(' ','-')
//     def build_type = job_definition.build_type
//     def docker_repo = job_definition.docker.override_repo
//     def build_context = job_definition.docker.build_context ?: '.'
//     def repo = job_definition.scm
//     def job_desc = job_definition.description
//
    branches.each {
      def this_branch = it.key.replaceAll(' ','-')
      def this_sha = it.value
      println "${this_branch} : ${this_sha}"

    create_job(new Yaml().load(_app), this_branch)
//
//       folder(job_name)
//       job("${_app}-${this_branch}") {
//         description(job_desc)
//         multiscm {
//           git {
//             remote {
//                 github ci.repo
//                 branch ci.branch
//                 credentials 'github-api-jnbnyc'
//             }
//             extensions {
//                 relativeTargetDirectory('ci')
//             }
//           }
//           git {
//             remote {
//                 github repo
//                 branch this_branch
//                 credentials 'github-api-jnbnyc'
//             }
//           }
//
//         }
//         steps {
//           shell """
//             export BUILD_TYPE=${build_type}
//             export DOCKER_REPO=\"${docker_repo}/${job_name}\"
//             export PROJECT_BRANCH=${this_branch}
//             export CONTAINER_BUILD_CONTEXT=${build_context}
//             ci/bin/build.sh
//             """.stripIndent()
//         }
//       }
    } // end branches
// }

def create_job(_thisJob,_branch) {
  // println prettyYaml(_thisJob)
  _scm_url = _thisJob.scm_url ?: null
  _scm = _thisJob.full_name ?: null
  if(!_scm) {
    println "FATAL: full_name is required to proceed"
    Thread.currentThread().stop()
  }
  _job_name = _thisJob.name.replace(' ', '-')
  _full_name = _scm.replace(' ', '-').split('/')[1]
  _folder_name = _thisJob.folder ? "${_thisJob.folder}/${_full_name}" : _full_name

  _desc = _thisJob.description ?: null
  _nodeLabel = _thisJob['node-label'] ?: null
  _buildSteps = _thisJob['build-steps'] ?: null
  // if(_thisJob.containsKey('builders')) {
  //     build_list = !_thisJob.builders.isEmpty()
  //     build_steps = _thisJob.builders
  // }
  _downstream = _thisJob.downstream ?: null
  _displayName = _thisJob['display-name'] ?: null
  _concurrent = _thisJob.concurrent ?: null
  _quietPeriod = _thisJob['quiet-period'] ?: null
  _blockDownstream = _thisJob.blockDownstream ?: null
  _blockUpstream = _thisJob.blockUpstream ?: null
  _checkoutRetryCount = _thisJob.checkoutRetryCount ?: null
  _logRotate = _thisJob.logrotate ?: null

  REMOTE_URL = "${_scm_url}/${_scm}"
  REMOTE_SCM_CREDS = _thisJob.scm_credentials ?: null

  def build_script = """
      export BUILD_TYPE=docker
      export DOCKER_REPO=\"${docker_repo}/${}\"
      export PROJECT_BRANCH=${_branch}
      export CONTAINER_BUILD_CONTEXT=${_thisJob.build_context}
      ci/bin/build.sh
      """.stripIndent()
  // make folders recursively
  // TODO, dont need to make folders in this scenario
  // _folderPath = _folder_name.split('/')
  // _folderPath.eachWithIndex {folderName, index ->
  //   if(index == 0) {
  //     folder(_folderPath[0])
  //   } else {
  //     // for some reason range 0,0 returns value/value
  //     folder(_folderPath[0,index].join('/'))
  //   }
  // }

    // if(_thisJob.brancher == 'enabled') {
    //   create_brancher_job()
    // } else {
// TODO, this dsl creates jobs in the same folder
      // job("${_folder_name}/${_job_name}-${_branch.replaceAll('/','-')}") {
      job("${_job_name}-${_branch.replaceAll('/','-')}") {
          if(_nodeLabel) { label(_nodeLabel) }
          if(_desc) { description(_desc) }
          if(_displayName) {
              // string
              displayName(_displayName + " (${_branch.replaceAll('/','-')})")
          }

          if(_concurrent) {
              // boolean; defaults to false
              concurrentBuild(_concurrent)
          }

          if(_quietPeriod) {
              // integer
              quietPeriod(_quietPeriod)
          }

          if(_blockDownstream) {
            // boolean
            blockOnDownstreamProjects()
          }

          if(_blockUpstream) {
            // boolean
            blockOnUpstreamProjects()
          }

          if(_checkoutRetryCount) {
            // integer
            checkoutRetryCount(_checkoutRetryCount)
          }

          if(_logRotate) {
              logRotator {
                if(_logRotate.daysToKeep) { daysToKeep(_logRotate.daysToKeep) }
                if(_logRotate.numToKeep) { numToKeep(_logRotate.numToKeep) }
                if(_logRotate.artifactDaysToKeep) { artifactDaysToKeep(_logRotate.artifactDaysToKeep) }
                if(_logRotate.artifactNumToKeep) { artifactNumToKeep(_logRotate.artifactNumToKeep) }
              }
          }

          multiscm {
            if(_scm) {
              git {
                  remote {
                      url(REMOTE_URL)
                      credentials(REMOTE_SCM_CREDS)
                  }
                  branch(_thisJob.default_branch)
                  extensions {
                      relativeTargetDirectory(SOURCE_DIR)
                  }
              }
              if (System.getenv('BUILD_ENV') == 'local') {
                steps {
                  shell('test -L ci || ln -s /sirjenkins-ci ci')
                }
              } else {
                  git {
                      remote {
                          url(CI_REMOTE_URL)
                          credentials(CI_SCM_CREDS)
                      }
                      branch(CI_BRANCH)
                      extensions {
                          relativeTargetDirectory(CI_DIR)
                      }
                  }
              }
            }
          } // end multiscm

          steps {
              if(_buildSteps) {
                  for (step in _buildSteps) {
                      if (step.containsKey('shell')) { shell(step.shell) }
                      if (step.containsKey('system-groovy')) {
                          systemGroovyScriptFile(step['system-groovy'].file)
                      }
                      if (step.containsKey('dsl')) {
                          dsl {
                              external(step.dsl.file)
                              ignoreExisting(false)
                              removeAction('DELETE')
                              removeViewAction('DELETE')
                          }

                      }
                  }
              }
          }  // end steps
          publishers {
              if(_downstream) {
                  for(job in _downstream) {
                      downstream(_downstream)
                  }
              }
          }  // end publishers
      }
    //}
}

def prettyYaml(input) {
    DumperOptions options = new DumperOptions()
    options.setLineBreak(DumperOptions.LineBreak.UNIX)
    options.setDefaultFlowStyle(DumperOptions.FlowStyle.BLOCK)
    return new Yaml(options).dump(input)
}

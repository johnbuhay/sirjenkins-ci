@Grapes([
    @Grab(group='org.yaml', module='snakeyaml', version='1.17')
])

import java.lang.*
import org.yaml.snakeyaml.Yaml
import org.yaml.snakeyaml.DumperOptions

CI_BRANCH = 'master'
CI_DIR = 'ci'
SOURCE_DIR = 'source'
// GITHUB_RAW_CONTENT = 'https://raw.githubusercontent.com'

SCANNING_FOR = System.getenv('SCANNING_FOR') ?: 'sirjenkins'
WORKSPACE = System.getenv('WORKSPACE') ?: Thread.currentThread().executable.workspace
DEFAULTS_FILE = new Yaml().load(new File("${WORKSPACE}/${CI_DIR}/${SCANNING_FOR}-defaults-global.yaml").text)

defaults = [:]
defaults['logrotate'] = [:]
defaults += DEFAULTS_FILE

CI_REMOTE_URL = defaults.ci_remote_url ?: "${defaults.scm_url}/${defaults.ci_repo}"
CI_SCM_CREDS = defaults.scm_credentials
def projectsToCreate = new Yaml().load(
    new File("${WORKSPACE}/projects.yaml").text
)

// projectsToCreateYaml = """\
//     ---
//     - name: jessie
//       disabled: false
//       display-name: 'Fancy job name'
//       node-label: master
//       docker-overrides:
//         build-context: jessie
//         repo: jnbnyc
//       scm: jnbnyc/docker-shelf
//       default_branch: master
//
// """.stripIndent()
//projectsToCreate = new Yaml().load(projectsToCreateYaml)

projectsToCreate.each { createProject(it) }
trigger_project_brancher(projectsToCreate)

//  ################################### METHODS #####################################  //


def createProject(app) {
  _thisJob = defaults + app
  // println prettyYaml(_thisJob)
  // _test = app.something ?: null
  // if(_test) { println _test }

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

  // make folders recursively
  _folderPath = _folder_name.split('/')
  _folderPath.eachWithIndex {folderName, index ->
    if(index == 0) {
      folder(_folderPath[0])
    } else {
      // for some reason range 0,0 returns value/value
      folder(_folderPath[0,index].join('/'))
    }
  }

    if(_thisJob.brancher == 'enabled') {
      create_brancher_job()
    } else {
      job("${_folder_name}/${_job_name}") {
          if(_nodeLabel) { label(_nodeLabel) }
          if(_desc) { description(_desc) }
          if(_displayName) {
              // string
              displayName(_displayName)
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
                shell('test -L ci || ln -s /sirjenkins-ci ci')
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
    }
}


def create_brancher_job() {
  // println prettyYaml(_thisJob)
  _yaml = """_app = \"\"\"\n${prettyYaml(_thisJob)}\n\"\"\"\n\n"""
  job("${_folder_name}/${_job_name}-brancher") {
    disabled(false)
    blockOnUpstreamProjects()
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
      jobDsl {
          scriptText(_yaml + readFileFromWorkspace('ci/brancher.dsl'))
          lookupStrategy('SEED_JOB')
          additionalClasspath('/usr/lib/jvm/java-1.8-openjdk/jre/bin')
          // failOnMissingPlugin(true)
          ignoreExisting(false)
          // ignoreMissingFiles(false)
          removedJobAction('DELETE')
          removedViewAction('DELETE')
      }
    }
    publishers {
        groovyPostBuild {
          script(readFileFromWorkspace('ci/brancher-post-build-trigger.groovy'))
        }
    }
  }
}

// def configureSCM() {
//   if(_scm) {
//     scm {
//       git {
//           remote {
//               url(REMOTE_URL)
//               credentials(REMOTE_SCM_CREDS)
//           }
//           branch(_thisJob.default_branch)
//           extensions {
//               relativeTargetDirectory(SOURCE_DIR)
//           }
//       }
//     } // end scm
//   }
// }


def configureMultiSCM() {
  // if(_thisJob.brancher == 'enabled') {
  //   println 'brancher enabled!'
  // } else {
  //   println 'brancher disabled!'
  // }
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
        shell('test -L ci || ln -s /sirjenkins-ci ci')
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
}


def prettyYaml(input) {
    DumperOptions options = new DumperOptions()
    options.setLineBreak(DumperOptions.LineBreak.UNIX)
    options.setDefaultFlowStyle(DumperOptions.FlowStyle.BLOCK)
    return new Yaml(options).dump(input)
}


def trigger_project_brancher(list_of_projects) {
    folder_name = 'ci'
    job_name = 'master'
    folder(folder_name)
    job("${folder_name}/${job_name}-downstream") {
        logRotator(daysToKeepInt = 14)
        blockOnUpstreamProjects()
        publishers {
            list_of_projects.each {
                project_name = it.name.replace(' ', '-')
                downstream("${project_name}/${project_name}-brancher")
            }
        }
    }
}

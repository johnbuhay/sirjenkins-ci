@Grab(group='org.yaml', module='snakeyaml', version='1.17')
import org.yaml.snakeyaml.Yaml
import org.yaml.snakeyaml.DumperOptions

import groovy.json.JsonSlurper
import groovy.json.JsonOutput

def list = new Yaml().load(
    readFileFromWorkspace('ci/containers.yml')
)

//  https://jenkins-job-builder.readthedocs.io/en/latest/definition.html#job
list.containers.each {
  create_job(it)
}

/*
    Read YAML
    for each container:
        create a job
        multiline string writes a dockerfile
        executes docker_build job
        pushes to docker repository
*/

//  ################################### METHODS #####################################  //

def create_job(job_info) {
    // printy job_info
    build_script = ""
    container_build_context="\${WORKSPACE:-.}/source"
    dockerfile_script = ""
    version_script = ""

    if(job_info.version) {
      version_script = """
cat > source/version.txt <<- EOF
${job_info.version}
EOF
""".stripIndent()
    }

    if(job_info.dockerfile) {
      dockerfile_script = """
cat > source/Dockerfile <<- EOF
${job_info.dockerfile}
EOF
""".stripIndent()
    }

    if(job_info.build_context) {
      container_build_context="${container_build_context}/${job_info.build_context}"
    }

    build_script = """
cat > config.vars <<- EOF
export CONTAINER_BUILD_CONTEXT=${container_build_context}
export DOCKER_REPO=${job_info.name}
EOF
source config.vars || true

[ -d "source" ] || mkdir source

${version_script}

${dockerfile_script}

ci/bin/docker_build.sh
""".stripIndent()

    folder_name = 'ci'
    job_name = job_info.name.replace('/','-')

    folder(folder_name)
    job("${folder_name}/build-${job_name}") {
        disabled(false)
        blockOnUpstreamProjects()
        multiscm {
          git {
            remote {
              github("jnbnyc/sirjenkins-ci")
              branch('master')
              credentials('github-api-jnbnyc')
            }
            extensions {
              relativeTargetDirectory('ci')
            }
          }
          if(job_info.git_repo) {
            git {
              remote {
                github("${job_info.git_repo}")
                branch("${job_info.git_branch}")
                credentials('github-api-jnbnyc')
              }
              extensions {
                relativeTargetDirectory('source')
              }
            }
          }
        }

        steps { shell(build_script) }
    }
}

def printy(yaml) {
    DumperOptions options = new DumperOptions()
    options.setLineBreak(DumperOptions.LineBreak.UNIX)
    options.setDefaultFlowStyle(DumperOptions.FlowStyle.BLOCK)
    println new Yaml(options).dump(yaml)
}

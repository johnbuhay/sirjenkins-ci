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

    if(job_info.version) {
      version_script = """
        cat > version.txt <<- EOF
        ${job_info.version}
        EOF
      """.stripIndent()
    }

    build_script = """
cat > config.vars <<- EOF
export DOCKER_REPO=${job_info.name}
EOF

${version_script ?: ''}

cat > Dockerfile <<- EOF
${job_info.dockerfile}
EOF

source config.vars
bin/docker_build.sh
""".stripIndent()

    folder_name = 'ci'
    job_name = job_info.name.replace('/','-')

    folder(folder_name)
    job("${folder_name}/build-${job_name}") {
        disabled(false)
        blockOnUpstreamProjects()
        scm {
          git {
            remote {
              github("jnbnyc/sirjenkins-ci")
              branch('master')
              credentials('github-api-jnbnyc')
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

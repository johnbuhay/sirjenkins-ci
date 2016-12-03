/* TODO
  twelve (re)factor this!
*/
import groovy.json.JsonSlurper
import groovy.json.JsonOutput

CI_REPO = 'jnbnyc/ci'
CI_BRANCH = 'master'

GITHUB_URL = 'https://github.com'
GITHUB_APIKEY_ID = 'github-api-jnbnyc'
GITHUB_RAW_CONTENT = 'https://raw.githubusercontent.com'

def projects_to_create = new JsonSlurper().parseText(
    new File("${WORKSPACE}/projects.json").text
)


projects_to_create.each { create_project(it) }
trigger_project_brancher(projects_to_create)


//  ################################### METHODS #####################################  //

def create_project(repoInfo) {
    info = """repoJson = \"\"\"\n${JsonOutput.prettyPrint(JsonOutput.toJson(repoInfo))}\n\"\"\"\n\n"""
    job_name = repoInfo.name.replace(' ','-')
    folder(job_name)
    job("${job_name}/${job_name}-brancher") {
        disabled(false)
        blockOnUpstreamProjects()
        logRotator(daysToKeep = 14, numToKeep = 9)
        steps {
            // TODO
            // scm {
            //     git {
            //         remote {
            //             url("${GITHUB_URL}/${CI_REPO}")
            //             credentials(GITHUB_APIKEY_ID)
            //         }
            //         branch(CI_BRANCH)
            //     }
            // }
            // dsl {
            //     text(info + readFileFromWorkspace('create_branches.dsl'))
            // }
            // dsl {
            //     external('brancher_job.dsl')
            //     ignoreExisting(false)
            //     removeAction('DELETE')
            //     removeViewAction('DELETE')
            // }
            systemGroovyCommand(info + readFileFromWorkspace('ci/create_branches.dsl'))
            shell("jenkins-jobs --ignore-cache update ./:/etc/jenkins_jobs/global")
        }
    }
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

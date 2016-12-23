@Grab(group='org.yaml', module='snakeyaml', version='1.17')
import org.yaml.snakeyaml.Yaml
import org.yaml.snakeyaml.DumperOptions

import groovy.json.JsonSlurper
import groovy.json.JsonOutput


// def list = new JsonSlurper().parseText(
//     readFileFromWorkspace('sirjenkins.json')
// )
// println JsonOutput.prettyPrint(JsonOutput.toJson(list))

def list = new Yaml().load(
    readFileFromWorkspace('sirjenkins.yml')
)

printy list


list.jobs.each { create_job(it) }

list.matrix.each { create_job(list["${it}"]) }


//  ################################### METHODS #####################################  //

def create_job(job_info) {
    printy job_info

    //TODO update folder_name
    folder_name = job_info.name.replace(' ','-')
    job_name = job_info.name.replace(' ','-')

    folder(folder_name)
    job("${folder_name}/${job_name}-brancher") {
        disabled(false)
        blockOnUpstreamProjects()
        steps {
            //TODO
            shell("echo ${job_info}")
        }
    }
}

def printy(yaml) {
    DumperOptions options = new DumperOptions()
    options.setLineBreak(DumperOptions.LineBreak.UNIX)
    options.setDefaultFlowStyle(DumperOptions.FlowStyle.BLOCK)
    println new Yaml(options).dump(yaml)
}

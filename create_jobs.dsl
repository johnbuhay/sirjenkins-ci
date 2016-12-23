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

list.matrix.each { println list["${it}"] }


//  ################################### METHODS #####################################  //

def create_job(job_info) {    

    job_name = job_info.name.replace(' ','-')
    folder(job_name)
    job("${job_name}/${job_name}-brancher") {
        disabled(false)
        blockOnUpstreamProjects()
        // TODO
        steps {
            shell('echo hello')
        }
    }
}

def printy(yaml) {
    DumperOptions options = new DumperOptions()
    options.setLineBreak(DumperOptions.LineBreak.UNIX)
    options.setDefaultFlowStyle(DumperOptions.FlowStyle.BLOCK)
    println new Yaml(options).dump(yaml)
}

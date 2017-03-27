@Grab(group='org.yaml', module='snakeyaml', version='1.17')
import org.yaml.snakeyaml.Yaml
import org.yaml.snakeyaml.DumperOptions

/* NOTES
   needs details to get info from github
   figure out if owner is a user or organization
   define which repositories to filter using regex
   define what file to look for
   create brancher jobs for each repo that has that file in a branch
*/

// ONLY WORKS WITH GITHUB USER CURRENTLY

import static hudson.security.ACL.SYSTEM
import java.security.MessageDigest
import groovy.json.JsonSlurper
import groovy.json.JsonOutput

import com.cloudbees.plugins.credentials.CredentialsProvider
import com.cloudbees.plugins.credentials.common.StandardCredentials
import hudson.Plugin
import hudson.util.VersionNumber
import jenkins.model.Jenkins

// TODO
// import org.kohsuke.github.GitHub
// import org.kohsuke.github.GHOrganization
// import org.kohsuke.github.GHUser

env = System.getenv()
JENKINS_SETUP_YAML = env['JENKINS_SETUP_YAML'] ?: "${env['JENKINS_CONFIG_HOME']}/setup.yml"
def config = new Yaml().load(new File(JENKINS_SETUP_YAML).text)

VERBOSE = env['VERBOSE'] ?: false
WORKSPACE = env['WORKSPACE'] ?: Thread.currentThread().executable.workspace
CACHE_DIR = "${WORKSPACE}/cache"
SCANNING_FOR = env['SCANNING_FOR'] ?: 'sirjenkins'

GITHUB_API_URL = env['GITHUB_API_URL'] ?: 'https://api.github.com'
GITHUB_APIKEY_ID = 'github-api-jnbnyc'  // TODO
GITHUB_RAW_CONTENT = 'https://raw.githubusercontent.com'
GITHUB_REPO_REGEX = env['GITHUB_REPO_REGEX'] ?: '.*'

USER = config.github.scan_user ?: env['GITHUB_USER']
USER_REPOS = "${GITHUB_API_URL}/users/${USER}/repos"
OAUTH = getCredentials(GITHUB_APIKEY_ID)

ORG = env['GITHUB_ORGANIZATION'] ?: ''  // TODO
REPOS_URL = USER_REPOS

// ensure cache directory exists
new File("${CACHE_DIR}/").mkdirs()

// TODO
// throw error if this fails to retrive and stop build
if(api_call(REPOS_URL)) { main() }

//  ################################### MAIN #####################################  //
def main() {

  application_map = []
  def repos_url_cache_key = get_cache_key(REPOS_URL)
  def repos_json = new JsonSlurper().parseText(new File("${CACHE_DIR}/${repos_url_cache_key}.json").text)

  repos_json.each {
    if(it.name.find(GITHUB_REPO_REGEX)) {
        application_map.add(it)
    }
  }

  write_file("${WORKSPACE}/github.json", JsonOutput.prettyPrint(JsonOutput.toJson(application_map)))

  projects_to_create = []
  def repos_to_scan = new JsonSlurper().parseText(new File("${WORKSPACE}/github.json").text)
  repos_to_scan.each {
    DEPENDENCY_URL = "${GITHUB_RAW_CONTENT}/${it.full_name}/${it.default_branch}/${SCANNING_FOR}.yaml"
    if(api_call(DEPENDENCY_URL)) {
        println "Found ${SCANNING_FOR} in ${it.name} on branch ${it.default_branch}"
        def yamlInfo = new Yaml().load(getProjectDefinition(DEPENDENCY_URL))
        if(yamlInfo.class == java.util.ArrayList) {
          // TODO
          println 'Add Array to LinkedHashMap'
          // println yamlInfo
        } else {
          println yamlInfo.class
          if(yamlInfo.app) {
            projects_to_create.add(it + yamlInfo.app)
            // println prettyYaml(it + yamlInfo.app)
            println "Added ${it.name} project"
          }
        }
    }
  }

  write_file("${WORKSPACE}/projects.json", JsonOutput.prettyPrint(JsonOutput.toJson(projects_to_create)))
  write_file("${WORKSPACE}/projects.yaml", prettyYaml(projects_to_create))

}

//  ################################### METHODS #####################################  //


Boolean api_call(url, params = [:]) {

    def cache_key = get_cache_key(url)
    try {
        def url_info = url.toURL()
        def connection = url_info.openConnection()
        connection.setRequestProperty("Accept", "application/vnd.github.v3+json")
        connection.setRequestProperty("Authorization", "token ${OAUTH}".toString())
        connection.setRequestProperty("User-Agent", "sir_jenkins/0.1")

        def etag_file = new File("${CACHE_DIR}/${cache_key}-ETag.txt")
        def last_modified = new File("${CACHE_DIR}/${cache_key}-Last-Modified.txt")
        if(etag_file.exists()) {
            //println etag_file.text
            connection.setRequestProperty("If-None-Match", etag_file.text)
        } else if(last_modified.exists()) {
            //println last_modified.text
            connection.setRequestProperty("If-Modified-Since", last_modified.text)
        }

        //connection.getProperties().each { println it}
        isModified = connection.getIfModifiedSince()
        if(isModified != 0) { println "Modified? ${isModified}" }

        remainingLimit = connection.getHeaderField("X-RateLimit-Remaining")
        if(remainingLimit != null) { println "RateLimit-Remaining: ${remainingLimit}" }

        if(connection.responseCode == 304) {
            println 'hooray, saved an api call'
        } else if(connection.responseCode == connection.HTTP_OK ) {
            //println "Etag: " + connection.getHeaderField('ETag')
            if( connection.getHeaderField('ETag') != null ) {
              write_file("${CACHE_DIR}/${cache_key}-ETag.txt", connection.getHeaderField('ETag'))
            }
            //println "Last-Modified: " + connection.getHeaderField('Last-Modified')
            if(connection.getHeaderField('Last-Modified') != null ) {
              write_file("${CACHE_DIR}/${cache_key}-Last-Modified.txt", connection.getHeaderField('Last-Modified'))
            }

            println 'Saving the JSON response'
            write_file("${CACHE_DIR}/${cache_key}.json", connection.inputStream.text)
        } else if(connection.responseCode == 404) {
            if(VERBOSE) { println "${connection.responseCode} ${url} ${cache_key}" }
        } else {
          //connection.getHeaderFields().each { println it }
          throw new Exception("Error: Received unexpected HTTP response code: ${connection.responseCode} from ${url}")
        }

        if(connection.responseCode == connection.HTTP_OK || connection.responseCode == 304) {
            return true
        } else {
            return false
        }

    } catch (ex) {
        println ex
    }
}


def write_file(path_to_file, contents) {
    def writeFile = new File(path_to_file)
    if(writeFile.exists()) {
        println "The file ${path_to_file} already exists, writing over it."
        writeFile.write(contents)
    } else {
        writeFile.write(contents)
    }
}

// make a small unique id based on input for use in multiple calls of this function within a script
String get_cache_key(String s) {
    return generate_MD5(s).substring(0, 9)
}


String generate_MD5(String s) {
    return MessageDigest.getInstance("MD5").digest(s.bytes).encodeHex().toString()
}

// Retrieve credentials from the Credentials Plugin
String getCredentials(credentialsId) {
    Jenkins jenkins = Jenkins.getInstance();
    // Plugin credentialsPlugin = jenkins.getPlugin("credentials");
    // if(credentialsPlugin != null && !credentialsPlugin.getWrapper().getVersionNumber().isOlderThan(new VersionNumber("1.6"))) {
        for(CredentialsProvider credentialsProvider : jenkins.getExtensionList(CredentialsProvider.class)) {
            for(StandardCredentials credentials : credentialsProvider.getCredentials(StandardCredentials.class, jenkins, SYSTEM)) {
                if(credentials.getDescription().equals(credentialsId) || credentials.getId().equals(credentialsId)) {
                    // return credentials.getSecret().toString();
                    return credentials.getPassword().toString();
                }
            }
        }
        throw new IllegalArgumentException("Unable to find credential with ID: ${credentialsId}")
    // }
}


def prettyYaml(input) {
    DumperOptions options = new DumperOptions()
    options.setLineBreak(DumperOptions.LineBreak.UNIX)
    options.setDefaultFlowStyle(DumperOptions.FlowStyle.BLOCK)
    return new Yaml(options).dump(input)
}


def read_file(path) {
    return new File(path).text
}


def getProjectDefinition(url) {
    def cache_key = get_cache_key(url)
    def path = "${CACHE_DIR}/${cache_key}.json"
    return read_file(path)
}

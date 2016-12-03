import static hudson.security.ACL.SYSTEM
import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.CredentialsProvider
import com.cloudbees.plugins.credentials.common.StandardCredentials

@Grapes([
    @Grab(group='org.yaml', module='snakeyaml', version='1.17')
])

import org.yaml.snakeyaml.Yaml
import org.yaml.snakeyaml.DumperOptions
import groovy.json.JsonSlurper
import java.security.MessageDigest

env = System.getenv()
VERBOSE = env['VERBOSE'] ?: false
WORKSPACE = env['WORKSPACE'] ?: Thread.currentThread().executable.workspace
CACHE_DIR = "${WORKSPACE}/cache"
SCANNING_FOR = env['SCANNING_FOR'] ?: 'sirjenkins.yml'

GITHUB_API_URL = env['GITHUB_API_URL'] ?: 'https://api.github.com'
GITHUB_APIKEY_ID = 'github-api-jnbnyc'  // TODO
GITHUB_RAW_CONTENT = 'https://raw.githubusercontent.com'

OAUTH = getCredentials(GITHUB_APIKEY_ID)

// ensure cache directory exists
new File("${CACHE_DIR}/").mkdirs()


branches = []
detected_branches = []
dependency_yml = [:]

def gitflow_branches = [:]
gitflow_branches['feature'] = ['regex': /^(feature\/[^\s\/]+)$/]
gitflow_branches['release'] = ['regex': /^(release\/[^\s\/]+)$/]
gitflow_branches['hotfix']  = ['regex': /^(hotfix\/[^\s\/]+)$/]
gitflow_branches['master']  = ['regex': /^(master)$/]
gitflow_branches['develop'] = ['regex': /^(develop)$/]


repoObj = new JsonSlurper().parseText(repoJson)
BRANCHES_URL = repoObj.branches_url.replace('{/branch}','')
if (api_call(BRANCHES_URL)) {  // get all branches
    def branches_cache_key = get_cache_key(BRANCHES_URL)
    def branches_json = new JsonSlurper().parseText(new File("${CACHE_DIR}/" + branches_cache_key + ".json").text)
    branches_json.each {
        for(branch_type in gitflow_branches) {
            matcher = (it.name =~ branch_type.value.regex)
            if(matcher.matches()) {
                branch_name = matcher[0][1]
                detected_branches.add(branch_name)

                DEPENDENCY_URL = "${GITHUB_RAW_CONTENT}/${repoObj.full_name}/${branch_name}/${SCANNING_FOR}"
                if(api_call(DEPENDENCY_URL)) {
                    // even though this ends in json, it is actually whatever file you tell api_call to get
                    dependency_yml = new Yaml().load(new File("${CACHE_DIR}/${get_cache_key(DEPENDENCY_URL)}.json").text)
                    build = [:]
                    builds = [:]
                    branch = [:]
                    branch['branch'] = branch_name
                    build["${branch_name.replace('/','-')}"] = branch
                    branches.add(build)
                }
            }
        }
    }
}
println "Found these buildable branches: ${detected_branches}"

dependency_yml[0]['project']['repo'] = repoObj.full_name
dependency_yml[0]['project']['build'] = branches

DumperOptions options = new DumperOptions()
options.setLineBreak(DumperOptions.LineBreak.UNIX)
options.setDefaultFlowStyle(DumperOptions.FlowStyle.BLOCK)  // OPTIONS: AUTO BLOCK FLOW
// options.setDefaultScalarStyle(ScalarStyle.DOUBLE_QUOTED)
write_file("${WORKSPACE}/sirjenkins.yml", new Yaml(options).dump(dependency_yml))


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

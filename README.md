# check_elastic_stack

## Summary
- [Plugin Design](#plugin_design)
- [Elasticsearch Monitoring Concepts](./docs/concepts.md#concepts)
- [Usage](#usage)
- [Examples](#examples)
- [References](#plugin_design)

## Dependencies
- printf
- getopt
- curl
- jq

## <a id="plugin_design"></a> Plugin Design
The script is divided into three major sections, as described below.
#### Arguments parsing
User arguments are mapped to named vars to be used later in the script.
The most important input here is the context (--check), which determines the state of the CHECK and CHECK_PATHS variables, and other optional variables if necessary for that specific context.
#### Checks loop
For each path in CHECK_PATHS, cURL is called and its output is passed to a contextual check function according to the value of CHECK.
Every check function call sets the check_code and check_message variables. As soon as they are returned by the function, two vars called nagios_code and nagios_message are updated following these rules:
1. if a check_code is higher than the previous one, nagios_code is updated;
2. check_message is appended in nagios_message in a new line.

The result is that during the "checks loop" a Nagios output is incrementally built. At the end of this loop, you have a coherent nagios_code and nagios_message ready to be printed out.
#### Nagios output compilation
nagios_code and nagios_message are formatted and sent to stdout. The scripts exits with Nagios-compatible exit codes:
- OK
- WARNING
- CRITICAL
- UNKNOWN

Along with some explanations provided by a combination of check messages coming from the various check function calls

### Check Contexts
Currently there are only three contexts available: elasticsearch, kibana and logstash. However, the script's design is modular enough that it can be easily extended with new contexts. This is done in three steps:
 - define a new check case in section [section 1](#section_1), when parsing arguments, together with the corresponding list of API endpoints to check and other env vars you may require;
 - write a check function that must set the check_code and check_message variables. These variables will be ingested by the main script when building the final Nagios output.
 - call the function defined in section [section 2](#section_2) during the "check loop" section of the script.


## <a id="usage"></a> Usage
TODO

## <a id="examples"></a> Examples
TODO

## <a id="plugin_design"></a> References
### Starting example in docker compose (to be adjusted for swarm mode)
https://github.com/elastic/elasticsearch/blob/8.17/docs/reference/setup/install/docker/docker-compose.yml

### Kibana HA
https://www.elastic.co/guide/en/kibana/current/production.html#high-availability
https://www.elastic.co/guide/en/kibana/current/docker.html#configuring-kibana-docker
https://www.elastic.co/guide/en/kibana/8.17/settings.html

### Cluster Health API
https://www.elastic.co/guide/en/elasticsearch/reference/current/cluster-health.html

### Nagios output format
https://nagios-plugins.org/doc/guidelines.html#PLUGOUTPUT

### Some queries to access health API
`curl -vk -u elastic:changeme https://es1:9200/_cat/health`

`curl -vk -u elastic:changeme https://es1:9200/_cluster/health`


### Icinga2
#### Installation https://icinga.com/docs/icinga-2/latest/doc/02-installation/01-Debian/
#### Macros https://icinga.com/docs/icinga-2/latest/doc/03-monitoring-basics/
#### CheckCommand https://icinga.com/docs/icinga-2/latest/doc/09-object-types/
#### Service https://icinga.com/docs/icinga-2/latest/doc/05-service-monitoring/
# check_elastic_stack

## Summary
- [Usage](#usage)
- [Plugin Design](#nagios_plugin_design)
- [Examples](#examples)
- [References](#plugin_design)
- [(Extra) Elasticsearch Monitoring Concepts](./docs/concepts.md#concepts)
- [(Extra) Test against a real ELK stack](./docs/test_scenarios#test_scenarios)

## Dependencies
- printf
- getopt
- curl
- jq

## <a id="usage"></a> Usage
```
Usage: check_elastic_stack [options...]
  -c, --check <elasticsearch|kibana|logstash>
  -h, --host <host_or_endpoint>
  -u, --user <user>
  -p, --password <password>
  [-t, --timeout <seconds>]
  
Perform healthchecks on elasticsearch, kibana or logstash endpoints.
```

To validate icinga2 configurations:
`icinga2 daemon -C`

To list icinga2 objects: `icinga2 object list`

## <a id="nagios_plugin_design"></a> Nagios Plugin Design
The script is divided into three major sections, as described below.
### <a id="context_decision"></a> Context decision
User arguments are mapped to variables to be used later in the script.

These variables determine the *context* for the rest of the script. Incoming arguments such as --check result in the definition of **CHECK** and **CHECK_PATHS** variables. Other optional variables could be defined if the context requires. 

Currently, only three contexts are available: elasticsearch, kibana and logstash. However, adding a new custom context is as easy as adding a new case in the switch.

### Checks loop
Once the context is established, the checks loop starts. 

For each path in **CHECK_PATHS**, curl is called and its output is passed to a contextual check function according to the value of **CHECK** (which was defined during the [Context decision](#context_decision) phase).
Every check function call must set the **check_code** and **check_message** variables. As soon as they are returned by the function, two more vars called **nagios_code** and **nagios_message** are updated at each step according to these simple rules:
1. if the incoming **check_code** is higher than the current one, **nagios_code** is escalated to the new value of **check_code**;
2. **check_message** is appended in **nagios_message** in a new line.

In other words, what happens here is that during the "checks loop" a Nagios output is incrementally built. At the end of this loop, there will be a coherent **nagios_code** and **nagios_message** ready to be returned.
### Nagios output compilation
The third section receives **nagios_code** and **nagios_message**, which are then formatted and sent to stdout. 

The scripts exits with Nagios-compatible exit codes, along with some explanations provided by a combination of all check messages coming from the various check function calls during the "checks loop". As an example, the final output should look something like this:
```
CONTEXT_NAME OK - Some justification
Check function message 1
Check function message 2
Check function message 3
```
And the exit code will match the output message:
- 0 - OK
- 1 - WARNING
- 2 - CRITICAL
- 3 - UNKNOWN


## <a id="examples"></a> Examples

```
check_elastic_stack --check elasticsearch --host localhost --user elastic --password changeme --timeout 60
```

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
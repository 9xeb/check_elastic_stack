## <a id="concepts"></a> Concepts
### Elasticsearch
Elasticsearch is a nosql DB meant to store and index semi-structured data in form of documents. Unlike SQL databases which work in tables, Elasticsearch works more or less with dictionaries, whose keys can change from document to document, hence the term semi-structured. Elasticsearch also features powerful search capabilities, making it useful, for example, for performing CRUD operations on system logs.

Elasticsearch can run in HA mode, where each node coordinates with the others to gaurantee replication of data. 

Elasticsearch stores data in shards. A shard is the main unit of replication within Elasticsearch clusters. Elasticsearch strives to ensure multiple replicas of a shard are available at all times. A cluster's state can either be green, yellow or red. Green means all shards are replicated and available. Yellow means at least one shard is not replicated. Red means a shard has been lost, typically due to sudden failure of all the nodes that hosted replicas of that shard before they could be replicated elsewhere.

#### Monitoring Elasticsearch
`/_cluster/health`

One key point to look at when monitoring Elasticsearch is the state of the shards, which in turn is a reflection of the state of the cluster itself.

Ideally, one should check both the state of the shard and the number of lost nodes.

See https://www.elastic.co/guide/en/elasticsearch/reference/current/cluster-health.html for more information

### Kibana
Kibana is mostly a Web UI to Elasticsearch for visually interacting with your data stored in Elasticsearch. Building dashboards is an example use case. It is feature rich and can be extended with plugins. These plugins are deployed and run on an environment called the Task Manager.

#### Monitoring Kibana
The two major points to look at when monitoring Kibana are:
 1. `/api/status`, to verify if it can connect to Elasticsearch successfully;
 2. `/api/task_manager/_health`, to check if available plugins in the Task Manager are active or degraded.


See https://www.elastic.co/blog/troubleshooting-kibana-health for more information

### Logstash
Logstash works as a middleware between your unstructured data and Elasticsearch. It exposes an API to ingest data, which is formatted to a semi-structured form compatible with Elasticsearch where it is sent to. Logs are usually forwarded to Logstash from local agents called Beats. Logstash is meant to direct all your logs to a unified platform, in a compatible format, hence the name. Inside Logstash, the entities that run to make things work are called Pipelines.

#### Monitoring Logstash
`/_health_report`

Monitoring Logstash means ensuring the healthcheck API does not report any anomaly in the Pipelines.

See https://www.elastic.co/docs/api/doc/logstash/operation/operation-healthreport for more information

### Icinga2
Icinga2 is a modular monitoring architecture based on Nagios. Users can define resources such as Hosts, Services and Commands that run periodically and report back for monitoring purposes.

By default, custom resource files are to be saved in `/etc/icinga2/conf.d` so Icinga2 can pick them up.

See https://www.howtoforge.com/tutorial/add-a-new-host-and-service-to-be-monitored-by-icinga2/ for a full example.

See https://icinga.com/docs/icinga-2/latest/doc/03-monitoring-basics/ for the full documentation

#### Objects
When writing Icinga2 configurations, there are various objects you deal with:
- CheckCommands refer to CLI commands;
- Hosts define target devices to monitor;
- Services link CheckCommands and Hosts; 
- Notifications define where to send messages in case of alerts;

Take a look at this example from the docs:
```
object Host "my-server1" {
  address = "10.0.0.1"
  check_command = "hostalive"
}

object Service "ping4" {
  host_name = "my-server1"
  check_command = "ping4"
}

object Service "http" {
  host_name = "my-server1"
  check_command = "http"
}
```
What each of these object types have in common is that they contain a set of attributes. Attributes are prone to be defined once and recalled multiple times.

For this, there are many helper tools that simplify configuration at scale:
- Templates define a set of attributes to be imported into multiple objects that happen to share those attributes
```
template Service "generic-service" {
  max_check_attempts = 3
  check_interval = 5m
  retry_interval = 1m
  enable_perfdata = true
}

apply Service "ping4" {
  import "generic-service"

  check_command = "ping4"

  assign where host.address
}

apply Service "ping6" {
  import "generic-service"

  check_command = "ping6"

  assign where host.address6
}
```
- Macros allow to access attributes from other objects. One common use case is to use macros in a CheckCommand, attributes in a Host and then create a service that links a CheckCommand to a Host
```
object CheckCommand "my-ping" {
  command = [ PluginDir + "/check_ping" ]

  arguments = {
    "-H" = "$ping_address$"
    "-w" = "$ping_wrta$,$ping_wpl$%"
    "-c" = "$ping_crta$,$ping_cpl$%"
    "-p" = "$ping_packets$"
  }

  // Resolve from a host attribute, or custom variable.
  vars.ping_address = "$address$"

  // Default values
  vars.ping_wrta = 100
  vars.ping_wpl = 5

  vars.ping_crta = 250
  vars.ping_cpl = 10

  vars.ping_packets = 5
}

object Host "router" {
  check_command = "my-ping"
  address = "10.0.0.1"
}
```
- Apply rules are configuration "generators". They contain conditions on attributes instead of attributes themselves. A simple use case is to define an apply rule for a service, that will spawn a service for every host
```
// there will be as many services as there are hosts with a defined address
// just define one single apply rule!

apply Service "ping4" {
  check_command = "ping4"
  assign where host.address

  // here are some other examples:
  // assign where host.vars.application_type == "database"
  // assign where host.vars.app_dict.contains("app")
  // assign where match("webserver*", host.name)
  // assign where host.address && host.vars.os == "Linux"
  // ...
}
```
- Dependencies define parent/child relationships between Hosts and Services. If the checks on the parent fail, the rest should be skipped
```
object Host "dsl-router" {
  import "generic-host"
  address = "192.168.1.1"
}

object Host "google-dns" {
  import "generic-host"
  address = "8.8.8.8"
}

apply Service "ping4" {
  import "generic-service"

  check_command = "ping4"

  assign where host.address
}

apply Dependency "internet" to Host {
  parent_host_name = "dsl-router"
  disable_checks = true
  disable_notifications = true

  assign where host.name != "dsl-router"
}

apply Dependency "internet" to Service {
  parent_host_name = "dsl-router"
  parent_service_name = "ping4"
  disable_checks = true

  assign where host.name != "dsl-router"
}
```


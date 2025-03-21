# check_elastic_stack

## Dependencies
- printf
- getopt
- curl
- jq

## Plugin Design
The script is divided into three major parts:
 - Arguments parsing, where user arguments are mapped to named vars to be used later in the script;
 - Checks loop, where all requested checks are performed and the Nagios output is dynamically and incrementally built;
 - Nagios output and exit code.
### Checks Function
This design is modular enough to be easily extended to other contexts. This is done in three steps:
 1. define a new check case when parsing arguments, together with the corresponding list of API endpoints to check and other env vars you may require;
 2. write a check function that must set the check_code and check_message variables. These variables will be ingested by the main script when building the final Nagios output.
 3. call the function defined in (2.) during the "check loop" section of the script.


## Concepts
### Elasticsearch
Elasticsearch is a nosql DB meant to store and index semi-structured data in form of documents. Unlike SQL databases which work in tables, Elasticsearch works more or less with dictionaries, whose keys can change from document to document, hence the term semi-structured. Elasticsearch also features powerful search capabilities, making it useful, for example, for performing CRUD operations on system logs.

Elasticsearch can run in HA mode, where each node coordinates with the others to form a quorum. 

Elasticsearch stores data in shards. Shards are the main unit of replication within Elasticsearch clusters. Elasticsearch strives to ensure multiple replicas of a shard are available at all times. A cluster's state can either be green, yellow or red. Green means all shards are replicated and available. Yellow means at least one shard is not replicated. Red means a shard has been lost, typically due to sudden failure of all the nodes that hosted replicas of that shard before they could be replicated elsewhere.

#### Monitoring Elasticsearch
`/_cluster/health`

One key point to look at when monitoring Elasticsearch is the state of the shards, which in turn is a reflection of the state of the cluster itself.


See https://www.elastic.co/guide/en/elasticsearch/reference/current/cluster-health.html for more information

### Kibana
Kibana is mostly a Web UI to Elasticsearch for visually interacting with your data stored in Elasticsearch. Building dashboards is an example use case. It is feature rich and can be extended with plugins. These plugins are deployed and run on an environment called the Task Manager.

#### Monitoring Kibana
The two major points to look at when monitoring Kibana are:
 1. `/api/status`, to verify if it can connect to Elasticsearch successfully;
 2. `/api/task_manager/_health`, to check if available plugins in the Task Manager are active or degraded.


See https://www.elastic.co/blog/troubleshooting-kibana-health for more information

### Logstash
Logstash works as a middleware between your unstructured data and Elasticsearch. It exposes an API to ingest data, which is formatted to a semi-structured form compatible with Elasticsearch where it is sent to. Logs are usually forwarded to Logstash from local agents called Beats. Logstash is meant to direct all your logs to a unified platform, in a compatible format, hence the name. Inside Logstash, the entities that receive logs from Beats and forward them to Elasticsearch are called Pipelines.

#### Monitoring Logstash
`/_health_report`

Monitoring Logstash means ensuring the healthcheck API does not report any anomaly in the Pipelines.

See https://www.elastic.co/docs/api/doc/logstash/operation/operation-healthreport for more information

## References
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
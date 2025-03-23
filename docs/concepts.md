## <a id="plugin_design"></a> Concepts
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

### Icinga2
Icinga2 is a modular monitoring architecture based on Nagios. Users can define resources such as Hosts, Services and Commands that run periodically and report back for monitoring purposes.

Custom resources are to be appended to the correct file in `/etc/icinga2/conf.d`.

See https://www.howtoforge.com/tutorial/add-a-new-host-and-service-to-be-monitored-by-icinga2/ for a full example.

See https://icinga.com/docs/icinga-2/latest/doc/03-monitoring-basics/ for the full documentation
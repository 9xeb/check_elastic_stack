# check_elastic_stack

## Dependencies
- getopt
- curl
- jq

## Concepts
### Elasticsearch
Elasticsearch is a nosql DB meant to store and index semi-structured data in form of documents. Unlike SQL databases which work in tables, Elasticsearch works more or less with dictionaries, whose keys can change from document to document, hence the term semi-structured. Elasticsearch also features powerful search capabilities, making it useful, for example, for performing CRUD operations on system logs.
Elasticsearch can run in HA mode, where each node coordinates with the others to form a quorum.
Elasticsearch stores data in shards. Shards are the main unit of replication within Elasticsearch clusters. Elasticsearch strives to ensure multiple replicas of a shard are available at all times. A cluster's state can either be green, yellow or red. Green means all shards are replicated and available. Yellow means at least one shard is not replicated. Red means a shard has been lost (typically due to sudden failure of all the nodes that hosted replicas of that shard).

### Kibana
Kibana ...

### Logstash
Logstash ...

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
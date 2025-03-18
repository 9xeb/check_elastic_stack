# check_elastic_stack

## References
### Starting example in docker compose (to be adjusted for swarm mode)
https://github.com/elastic/elasticsearch/blob/8.17/docs/reference/setup/install/docker/docker-compose.yml

### Kibana HA
https://www.elastic.co/guide/en/kibana/current/production.html#high-availability

### Cluster Health API
https://www.elastic.co/guide/en/elasticsearch/reference/current/cluster-health.html

### Nagios output format
https://nagios-plugins.org/doc/guidelines.html#PLUGOUTPUT

### Some queries to access health API
`curl -vk -u elastic:changeme https://es1:9200/_cat/health`

`curl -vk -u elastic:changeme https://es1:9200/_cluster/health`
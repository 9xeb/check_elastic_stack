# <a id="test_scenarios"></a> Test Scenarios
On a test machine with docker installed, run:
```
docker swarm init
docker stack deploy -c docker/elk/docker-compose.yaml elk
```
This will spin up an ELK stack consisting of 5 Elasticseach instances, 2 Kibana and 2 Logstash. While you wait for the ELK stack to come up, you can check status with:
```
docker service ls
```
or
```
docker stack ps elk
```

Once the ELK cluster is up, you can test the check script under normal (green) conditions:
```
check_elastic_stack.sh --check elasticsearch --host localhost --user elastic --password changeme
```

Next, try to scale down elasticsearch to three replicas
```
docker service scale elk_elastisearch=3
```
Then try again:
```
check_elastic_stack.sh --check elasticsearch --host localhost --user elastic --password changeme
```
You should see elasticsearch turning yellow, and the check script returning the corresponding Nagios output.

Elasticsearch is yellow because some shards replicas have been lost. At this point it begins re-replicating the underreplicated shards.
After a few minutes, Elasticsearch will turn back green and you can check that again with:
```
check_elastic_stack.sh --check elasticsearch --host localhost --user elastic --password changeme
```

Feel free to play with scaling down/up ELK components in the test environment, and see how the check script reacts to ELK failures!

FROM docker.elastic.co/elasticsearch/elasticsearch:8.17.3

COPY instances.yml /instances.yml
COPY setup.sh /setup.sh

CMD ["bash", "/setup.sh"]


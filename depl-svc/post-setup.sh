cd servicemap-conf
source update-ontology.sh localhost
isql-v localhost dba dba /root/servicemap/servicemap.vt
isql-v localhost dba dba /root/servicemap/servicemap-dbpedia.vt

#curl -H 'Content-Type: application/json' -X PUT 'http://localhost:9200/iotdata-organization' -d @mapping_Sensors-ETL-IOT-v3.json

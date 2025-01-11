# help to check health of the cluster
while true; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://os-master:9200/_cluster/health")
    if [ "$RESPONSE" -eq 200 ]; then
        echo "healthy"
        break
    else
        echo "unhealthy"
        sleep 10
    fi
done

# The interval at which the managed index jobs are run.
# default value of plugins.index_state_management.job_interval is 5min. The min value should be >=1
# A randomized delay that is added to a job’s base run time to prevent a surge of activity from all indexes at the same time
# default value of plugins.index_state_management.jitter is 0.6
curl -XPUT "http://os-master:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
{
  "persistent": {
    "plugins.index_state_management.job_interval": 1, 
    "plugins.index_state_management.jitter": 0.1
  }
}'

# help to create a rollover policy to rollover index after a certain condition and delete index if index age is older than 1 day
curl -XPUT "http://os-master:9200/_plugins/_ism/policies/rollover_delete_policy" -H 'Content-Type: application/json' -d'
{
  "policy": {
    "description": "rollover & delete policy",
    "default_state": "hot",
    "states": [
      {
        "name": "hot",
        "actions": [
          {
            "rollover": {
              "min_index_age": "1d",
              "min_doc_count": 5000000
            }
          }
        ],
        "transitions": [
          {
            "state_name": "search"
          }
        ]
      },
      {
        "name": "search",
        "actions": [],
        "transitions": [
          {
            "state_name": "delete",
            "conditions": {
              "min_index_age": "1d"
            }
          }
        ]
      },
      {
        "name": "delete",
        "actions": [
          {
            "delete": {}
          }
        ],
        "transitions": []
      }
    ],
    "ism_template": [
      {
        "index_patterns": [
          "device-log*"
        ]
      }
    ]
  }
}'

# help to create an template for an index 
curl -XPUT "http://os-master:9200/_index_template/device-log" -H 'Content-Type: application/json' -d'
{
  "index_patterns": "device-logs*",
  "data_stream": {},
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 0
    }
  }
}'

# help to create data stream
curl -XPUT "http://os-master:9200/_data_stream/device-logs" 

# Help to create notificatipn channel
curl -XPOST "http://os-master:9200/_plugins/_notifications/configs/" -H 'Content-Type: application/json' -d'
{
  "config_id": "msTeamsId",
  "name": "msTeams",
  "config": {
    "name": "MS Teams Channel",
    "description": "This is a MS Teams channel for sending notifications alerts",
    "config_type": "microsoft_teams",
    "is_enabled": true,
    "microsoft_teams": {
      "url": {WEBHOOK_WRL}
    }
  }
}'

# help to create monitor Alert
curl -XPOST "http://os-master:9200/_plugins/_alerting/monitors" -H 'Content-Type: application/json' -d'
{
  "name": "checkNodeDiskSpaceMonitor",
  "type": "monitor",
  "monitor_type": "cluster_metrics_monitor",
  "enabled": true,
  "schedule": {
    "period": {
      "unit": "MINUTES",
      "interval": 10
    }
  },
  "inputs": [
    {
      "uri": {
        "api_type": "NODES_STATS",
        "path": "_nodes/stats",
        "path_params": "",
        "url": "http://localhost:9200/_nodes/stats",
        "clusters": []
      }
    }
  ],
  "triggers": [
    {
      "name": "checkNodeDiskSpaceTrigger",
      "severity": "1",
      "condition": {
        "script": {
          "source": "for (entry in ctx.results[0].nodes.entrySet()){if ((entry.getValue().fs.total.total_in_bytes -entry.getValue().fs.total.available_in_bytes)*100/entry.getValue().fs.total.total_in_bytes > 80) {return true;}}return false;",
          "lang": "painless"
        }
      },
      "actions": [
        {
          "name": "checkNodeDiskSpaceAction",
          "destination_id": "msTeamsId",
          "message_template": {
            "source": "Monitor {{ctx.monitor.name}} just entered alert status. Please investigate the issue.  - Trigger: {{ctx.trigger.name}}- Severity: {{ctx.trigger.severity}}- Period start: {{ctx.periodStart}}- Period end: {{ctx.periodEnd}}",
            "lang": "mustache"
          },
          "subject_template": {
            "source": "Alerting Notification action",
            "lang": "mustache"
          }
        }
      ]
    }
  ]
}'

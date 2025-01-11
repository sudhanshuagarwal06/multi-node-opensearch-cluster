### OpenSearch Multi Node Cluster

------

**Types of Node:**

1. Data Nodes(Hot/Warm): Data nodes are optimized for storage space and search with less compute power. Data nodes can be further split into hot nodes and warm nodes. Hot nodes run on the fastest available hardware. Warm nodes run on cheaper hardware, such as spinning disks.

2. Master Nodes(Cluster manager): Master nodes(Cluster manager) are important for maintaining a consistent view of the cluster. Typically, you want to have three (3) master nodes.


OpenSearch index is composed of shards. Each document in an index is stored in the shards of an index. An index can have two types of shards, primary and replica. When you write documents to an OpenSearch index, indexing requests first go through primary shards before they are replicated to the replica shard(s). Each primary shard is hosted on a data node in an OpenSearch domain. 

An index can have many primary and replica shards. The number of primary and replica shards is initially set when an index is created. 

Note: 
1. index.number_of_shards(Integer): The number of primary shards in the index. Default is 1. It is a Static index-level index settings are settings that you cannot update while the index is open. To update a static setting, you must close the index, update the setting, and then reopen the index.

2. index.number_of_replicas(Integer): The number of replica shards each primary shard should have. If not set, defaults to cluster.default_number_of_replicas (which is 1 by default).

**Ideal shard size/number**
    OpenSearch indexes have an ideal shard size. Shard size matters with respect to both search latency and write performance. Good place to start is with a number of shards that gives your index shard sizes between 10–30 GB per shard. 

**Some Important Points**
a) Opensearch does a pretty good job with evenly distributed the data across the nodes. If you have more data nodes as compare to shards, Opensearch will distribute shards according to Node availability. In simple words, OpenSearch will usually balance the index shards evenly across all active data nodes in the cluster. This is generally a process which happens automatically without any specific user intervention. 

b) Shards Rebalancing: In this case, shard move from one data node to another. For example, In Opensearch cluster we have 3 data nodes and for each index 3 primany shards and 0 replica shard. Now for high availability we add one more data node(means now we have 4 data node in Opensearch cluster). In this case Opensearch will automatically relocated some old shards to new data node to rebalance the cluster.
        
    index                  shard prirep state      docs    store    ip           node
    .ds-device-log-000005  1     p      STARTED    1696854 901.7mb  100.126.2.4  os-node2
    .ds-device-log-000005  2     p      RELOCATING 1696262 897.5mb  100.126.2.8  os-node3 -> 100.126.2.2 9t0jYG9GS-yTpPhLyNe5Kw os-node4
    .ds-device-log-000024  0     p      STARTED    1904402 999.4mb  100.126.2.5  os-node1
    .ds-device-log-000024  2     p      STARTED    1908420 1006.4mb 100.126.2.8  os-node3
    .ds-device-log-000025  0     p      RELOCATING 1686886 893.3mb  100.126.2.5  os-node1 -> 100.126.2.2 9t0jYG9GS-yTpPhLyNe5Kw os-node4
    .ds-device-log-000025  1     p      STARTED    1688106 895.8mb  100.126.2.4  os-node2
    .ds-device-log-000025  2     p      STARTED    1685682 897.5mb  100.126.2.8  os-node3 
    
**ISM Policy:**
    Index State Management (ISM) allows you to automate routine tasks and then apply them to indices and index patterns in OpenSearch Service. With ISM, you can define policies that help you maintain issues. For example, you can use a rollover operation and an ISM policy to automate deletion of old indices based on conditions. The rollover operation rolls over a target to a new index when an existing index meets the defined condition.

    -- min_size(minimum size of the total primary shard storage (not counting replicas) required to roll over the index)
    -- min_doc_count(index level)
    -- min_index_age(index level)

The ISM policy below is configured to manage index states based on two conditions: index age and document count. Specifically, the policy is set to trigger a rollover when either of the following conditions is met:
    -- The index age reaches 1 day
    -- The document count in the index reaches 5,000,000
    -- Additionally, the policy is configured to delete the index after 10 days.

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
              "min_index_age": "10d"
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

To ensure timely execution of the ISM policy, the default interval at which index jobs run has been adjusted from 5 minutes(default) to 1 minute. This adjustment enables the policy to trigger more frequently, allowing for more responsive management of index states. ISM Setting: **plugins.index_state_management.job_interval** [link](https://opensearch.org/docs/latest/im-plugin/ism/settings/) 

    "persistent": {
        "plugins.index_state_management.job_interval": 1, 
        "plugins.index_state_management.jitter": 0.1
    }

**Transition based on cluster free available space**
Problem: The current ISM (Index State Management) functionality allows for transitioning an index to a new state based on its age, which is effective for managing  cluster size when dealing with consistent and predictable data volumes, such as a daily influx of 50GB. In these scenarios, it's relatively straightforward to calculate the optimal retention period for an index before deletion.

However, this approach becomes challenging when faced with variable or unpredictable data volumes. In such cases, relying solely on age-based transitions may not be sufficient, as it can lead to inefficient index management and potential issues with cluster size and performance.

Solution: To address the challenge of managing index retention with variable or unpredictable data volumes, a potential solution is to implement a script that  monitors the total size of the node. When the total size exceeds a predefined threshold, the script can trigger the deletion of older indices.

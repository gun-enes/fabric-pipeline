# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "31997edc-ff2d-4968-9faf-3fe24bb67f66",
# META       "default_lakehouse_name": "lh_sample_data",
# META       "default_lakehouse_workspace_id": "1f76d21a-09fe-4690-b7a4-d2b30a592264",
# META       "known_lakehouses": [
# META         {
# META           "id": "31997edc-ff2d-4968-9faf-3fe24bb67f66"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

import random, time
from pyspark.sql import functions as F

def make(n, start=0):
    return (spark.range(start, start + n)
        .withColumn("name", F.expr("uuid()"))
        .withColumn("amount", F.rand() * 1000)
        .withColumn("category", (F.rand() * 20).cast("int"))
        .withColumn("created_at", F.current_timestamp()))

tables = [t.name for t in spark.catalog.listTables()]


new_table = f"table_new_{int(time.time())}"
make(50_000).write.format("delta").saveAsTable(new_table)
print(new_table, "created")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

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

import pandas as pd

path = "/lakehouse/default/Tables/dbo/table_02/part-00002-96c63756-0698-43da-888d-bdfffa61ab25-c000.snappy.parquet"

df = pd.read_parquet(path)
df.loc[3, "name"] = "changed"
df.to_parquet(path, index=False)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

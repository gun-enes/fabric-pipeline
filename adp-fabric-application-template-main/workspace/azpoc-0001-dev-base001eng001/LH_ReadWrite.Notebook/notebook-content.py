# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {}
# META }

# CELL ********************

target_workspace_name = "azpoc-0001-dev-base001"
target_workspace_id = "73ded50c-9280-47ab-bc1f-a2bfbbc25e0c"
target_name = "lh_azpoc_0001_dev_base001"


wh_dfurl = f"{target_workspace_id.replace('-','')}.z{target_workspace_id[:2]}.onelake.fabric.microsoft.com"#getOnelakeUrl(wh_workspace_id)
df = spark.sql("select * from dbo.`customers-1000`")
display(df)
df.write.mode("overwrite").format("delta").save(f"abfss://{target_workspace_name}@{wh_dfurl}/{target_name}.Lakehouse/Tables/dbo/customers-1000")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

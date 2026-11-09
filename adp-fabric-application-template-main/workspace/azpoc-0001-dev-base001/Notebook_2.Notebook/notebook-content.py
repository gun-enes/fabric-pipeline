# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {}
# META }

# CELL ********************

# Welcome to your new notebook
# Type here in the cell editor to add code!
# adls source
source = "abfss://sac-base001-f0001@stazpoc0001devext.dfs.core.windows.net"

df = (spark.read
        .format("csv")
        .option("header", "true")
        .option("inferSchema", "true")
        .load(f"{source}/DimAccount.csv"))

df.show(10)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

df.write \
  .format("delta") \
  .mode("overwrite") \
  .save("abfss://022e661d-bb04-42f2-81d7-14c558bd36cc@onelake.dfs.fabric.microsoft.com/b3805ded-90ad-48c6-b3a5-793957bd9eea/Files/Files_Out_SPN/DimAccount")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

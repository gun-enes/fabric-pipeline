# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {}
# META }

# CELL ********************

# abfss://{WorkspaceID}@{WorkspaceFQDN}/{LakehouseID}/Tables/
lhpath_wo_schemas = "abfss://2c328683-4cd9-4835-9c89-2763293ac40e@2c3286834cd948359c892763293ac40e.z2c.onelake.fabric.microsoft.com/9e56824c-e3be-4864-8400-d3319344fc78/"
lhpath_w_schema = "abfss://2c328683-4cd9-4835-9c89-2763293ac40e@2c3286834cd948359c892763293ac40e.z2c.onelake.fabric.microsoft.com/17d01136-3ab5-4f2c-8791-f604815dfec4/"
lhpath = lhpath_wo_schemas
lhpath = lhpath_w_schema

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# List all folders in the given ABFS path
path = lhpath + "Tables/"
#folders = notebookutils.fs.ls(path)
#display(folders)


folders = mssparkutils.fs.ls(path)  # your path (ABFSS or mounted)
rows = [(fi.path, fi.name, fi.size) for fi in folders]
for r in rows:
    print(r)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

path = lhpath + "Tables/" + "schema01/"
#folders = notebookutils.fs.ls(path)
#display(folders)


folders = mssparkutils.fs.ls(path)  # your path (ABFSS or mounted)
rows = [(fi.path, fi.name, fi.size) for fi in folders]
for r in rows:
    print(r)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

dim_account_table_path = path + "dimaccount"
# Read the Delta table
df = spark.read.format("delta").load(dim_account_table_path)
display(df.limit(5))

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

path = lhpath + "Files/" 
#folders = notebookutils.fs.ls(path)
#display(folders)


folders = mssparkutils.fs.ls(path)  # your path (ABFSS or mounted)
rows = [(fi.path, fi.name, fi.size) for fi in folders]
for r in rows:
    print(r)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

csv_path = lhpath + "/Files/Folder01/DimAccount.csv"
delta_out_path = lhpath + "/Files/Folder01/DimAccount"
# Read CSV into Spark DataFrame
df = spark.read.format("csv") \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .load(csv_path)



# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Show first 10 rows
df.show(10)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

df.write.format("delta").mode("overwrite").save(delta_out_path)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

path = lhpath + "Tables/" + "schema01/" + "dimaccount02"
df.write.format("delta").mode("overwrite").save(path)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

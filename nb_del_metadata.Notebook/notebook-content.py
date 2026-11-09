# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {}
# META }

# CELL ********************


from py4j.protocol import Py4JJavaError

root = "abfss://1f76d21a-09fe-4690-b7a4-d2b30a592264@onelake.dfs.fabric.microsoft.com/31997edc-ff2d-4968-9faf-3fe24bb67f66/Tables"
targets = {"_metadata", "metadata"}
dry_run = False  # set to False to actually delete

for schema in notebookutils.fs.ls(root):
    for table in notebookutils.fs.ls(schema.path):
        for item in notebookutils.fs.ls(table.path):
            if item.isDir and item.name.rstrip("/") in targets:
                print(item.path)
                if not dry_run:
                    try:
                        notebookutils.fs.rm(item.path, True)
                    except Py4JJavaError as e:
                        if "PathNotFoundException" not in str(e):
                            raise

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

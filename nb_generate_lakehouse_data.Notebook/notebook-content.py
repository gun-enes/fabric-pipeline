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

# PARAMETERS CELL ********************

GENERATE_TABLES = False
TABLE_COUNT     = 10
ROWS_PER_TABLE  = 180_000 #20000 rows is about 1MB
TABLE_PREFIX    = "table_"

GENERATE_FILES  = True
TOTAL_MB        = 100
MIN_FILE_KB     = 4
MAX_FILE_MB     = 8
ROOT            = "/lakehouse/default/Files/"
SEED            = None

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

if GENERATE_TABLES:
    for i in range(TABLE_COUNT):
        (spark.range(ROWS_PER_TABLE)
            .withColumn("name", F.expr("uuid()"))
            .withColumn("amount", F.rand(SEED) * 1000)
            .withColumn("category", (F.rand(SEED) * 20).cast("int"))
            .withColumn("created_at", F.current_timestamp())
            .write.format("delta").mode("overwrite")
            .saveAsTable(f"{TABLE_PREFIX}{i:02d}"))

    total = 0
    for t in spark.catalog.listTables():
        if t.name.startswith(TABLE_PREFIX):
            size = spark.sql(f"DESCRIBE DETAIL {t.name}").first()["sizeInBytes"] / 1e6
            total += size
            print(t.name, round(size, 1), "MB")
    print("total", round(total, 1), "MB")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import os, random, time

SUBDIRS    = ["", "raw", "raw/2026", "staging", "archive/old", "logs"]
EXTENSIONS = [".bin", ".dat", ".csv", ".json", ".parquet", ".txt"]

if GENERATE_FILES:
    rng = random.Random(SEED)
    min_b, max_b = MIN_FILE_KB * 1024, MAX_FILE_MB * 1024 * 1024

    sizes, remaining = [], TOTAL_MB * 1024 * 1024
    while remaining > 0:
        s = min(rng.randint(min_b, max_b), remaining)
        if 0 < remaining - s < min_b:
            s = remaining
        sizes.append(s)
        remaining -= s

    start = time.time()
    for i, size in enumerate(sizes):
        folder = os.path.join(ROOT, rng.choice(SUBDIRS))
        os.makedirs(folder, exist_ok=True)
        path = os.path.join(folder, f"file_{i:05d}_{rng.getrandbits(32):08x}{rng.choice(EXTENSIONS)}")
        with open(path, "wb") as f:
            left = size
            while left:
                chunk = min(left, 1024 * 1024)
                f.write(os.urandom(chunk))
                left -= chunk

    print(f"{len(sizes)} files, {sum(sizes) / 1024 / 1024:.2f} MB, {time.time() - start:.1f}s -> {ROOT}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

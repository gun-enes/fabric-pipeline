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

from pyspark.sql import functions as F

def make(n, start=0):
    return (spark.range(start, start + n)
        .withColumn("name", F.expr("uuid()"))
        .withColumn("amount", F.rand() * 1000)
        .withColumn("category", (F.rand() * 20).cast("int"))
        .withColumn("created_at", F.current_timestamp()))

for i in range(10):
    w = make(180_000).write.format("delta").mode("overwrite")
    w.saveAsTable(f"table_{i:02d}")

total = 0
for t in spark.catalog.listTables():
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

# --- Ayarlar ---
TOTAL_BYTES = 100 * 1024 * 1024        # toplam 100 MB
MIN_FILE    = 4 * 1024                 # en küçük dosya 4 KB
MAX_FILE    = 8 * 1024 * 1024          # en büyük dosya 8 MB
ROOT        = "/lakehouse/default/Files/random_data"
SUBDIRS     = ["", "raw", "raw/2026", "staging", "archive/old", "logs"]
EXTENSIONS  = [".bin", ".dat", ".csv", ".json", ".parquet", ".txt"]
SEED        = None                     # sabit sonuç için bir sayı ver, örn. 42

rng = random.Random(SEED)

# Toplamı tam olarak TOTAL_BYTES yapacak rastgele boyutları üret
sizes, remaining = [], TOTAL_BYTES
while remaining > 0:
    s = min(rng.randint(MIN_FILE, MAX_FILE), remaining)
    if 0 < remaining - s < MIN_FILE:
        s = remaining
    sizes.append(s)
    remaining -= s

start, written = time.time(), 0
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
    written += size

print(f"{len(sizes)} dosya, {written / 1024 / 1024:.2f} MB, {time.time() - start:.1f}s -> {ROOT}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

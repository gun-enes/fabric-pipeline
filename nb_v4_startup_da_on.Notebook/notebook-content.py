# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {}
# META }

# CELL ********************

# MAGIC %%configure -f
# MAGIC {
# MAGIC   "conf": {
# MAGIC     "spark.dynamicAllocation.enabled": "true",
# MAGIC     "spark.dynamicAllocation.minExecutors": "1",
# MAGIC     "spark.dynamicAllocation.initialExecutors": {"parameterName": "executors", "defaultValue": "1"},
# MAGIC     "spark.dynamicAllocation.maxExecutors": {"parameterName": "executors", "defaultValue": "1"}
# MAGIC   }
# MAGIC }


# PARAMETERS CELL ********************

# Parameters
run_id = ""
results_dir = "/lakehouse/default/Files/lhbackup_v4/results"
# Executor count; only read by %%configure (nb_v4_startup_da_on).
executors = ""


# CELL ********************

probe = "da_on"

import json, os, time

CONF_KEYS = (
    "spark.dynamicAllocation.enabled",
    "spark.dynamicAllocation.minExecutors",
    "spark.dynamicAllocation.initialExecutors",
    "spark.dynamicAllocation.maxExecutors",
    "spark.executor.instances",
)

cell_started = time.time()
# Start of this session's Spark application, i.e. after %%configure restarted it
app_started = spark.sparkContext.startTime / 1000
scheduler = spark.sparkContext._jsc.sc()
first_executor = None
while time.time() - cell_started < 300:
    # getExecutorMemoryStatus includes the driver
    if scheduler.getExecutorMemoryStatus().size() > 1:
        first_executor = time.time()
        break
    time.sleep(1)
job_started = time.time()
spark.sparkContext.parallelize(range(1), 1).count()
job_finished = time.time()

report = {
    "probe": probe,
    "run_id": run_id,
    "conf": {key: spark.conf.get(key, None) for key in CONF_KEYS},
    "app_started_epoch": round(app_started, 1),
    "first_cell_epoch": round(cell_started, 1),
    "first_executor_epoch": None if first_executor is None else round(first_executor, 1),
    "first_job_seconds": round(job_finished - job_started, 1),
    "live_executors": scheduler.getExecutorMemoryStatus().size() - 1,
}
print(json.dumps(report, indent=2))
os.makedirs(results_dir, exist_ok=True)
with open(f"{results_dir}/startup_{run_id or 'interactive'}.json", "w") as handle:
    json.dump(report, handle, indent=2)


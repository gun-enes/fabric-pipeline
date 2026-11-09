# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse_name": "",
# META       "default_lakehouse_workspace_id": "",
# META       "known_lakehouses": []
# META     }
# META   }
# META }

# CELL ********************

# MAGIC %%configure -f
# MAGIC {
# MAGIC   "conf": {
# MAGIC     "spark.dynamicAllocation.enabled": "false",
# MAGIC     "spark.executor.instances": "2"
# MAGIC   }
# MAGIC }


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# PARAMETERS CELL ********************

# Parameters
bundle_uri = "abfss://1f76d21a-09fe-4690-b7a4-d2b30a592264@onelake.dfs.fabric.microsoft.com/31997edc-ff2d-4968-9faf-3fe24bb67f66/Files/lhbackup_v4/lhbackup_spark_v4_bundle.zip"
workspace_id = "1f76d21a-09fe-4690-b7a4-d2b30a592264"
lakehouse_id = "31997edc-ff2d-4968-9faf-3fe24bb67f66"
onelake_url = "https://1f76d21a09fe4690b7a4d2b30a592264.z1f.blob.fabric.microsoft.com"

backup_storage_url = "https://fabric23456.blob.core.windows.net"
run_id = "benchmark"
execution_batch_work_units = ""
token_usable_seconds = ""
bench_id = ""
small_files = "6400"
big_files = "8"
synthetic_sizes = "100000,1000000,3000000"
synthetic_budget_minutes = "75"
sections = "io,spark"


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import base64, json, os, shutil, sys, time, zipfile
from datetime import datetime, timezone

import notebookutils

if not run_id:
    raise ValueError("pipeline must provide run_id")
local_bundle = "/tmp/lhbackup_spark_v4_bundle.zip"
local_package = "/tmp/lhbackup_spark_v4_bundle"
if os.path.exists(local_bundle):
    os.remove(local_bundle)
if os.path.exists(local_package):
    shutil.rmtree(local_package)
notebookutils.fs.cp(bundle_uri, f"file:{local_bundle}")
with zipfile.ZipFile(local_bundle) as archive:
    archive.extractall(local_package)
sys.path.insert(0, local_package)
spark.sparkContext.addPyFile(bundle_uri)

from azure.core.credentials import AccessToken

from lhbackup_spark_v4.tokens import StaticTokenCredential, issue_token_context

# Driver only: notebookutils is unavailable on executors, which receive
# driver-issued batch tokens (StaticTokenCredential) instead.
TOKEN_REFRESH_SECONDS = 900


class WorkspaceIdentityCredential:
    def __init__(self, initial_token=None):
        self.cached = None
        if initial_token:
            initial_claims = token_claims(initial_token)
            self.cached = AccessToken(initial_token, int(initial_claims["exp"]))

    def get_token(self, *scopes, **kwargs):
        now = int(time.time())
        if self.cached is None or self.cached.expires_on <= now + TOKEN_REFRESH_SECONDS:
            fresh = notebookutils.credentials.getToken("storage")
            self.cached = AccessToken(fresh, int(token_claims(fresh)["exp"]))
        return self.cached


def token_claims(token):
    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)
    return json.loads(base64.urlsafe_b64decode(payload))


credential = WorkspaceIdentityCredential()
token = credential.get_token("https://storage.azure.com/.default").token
claims = token_claims(token)
identity = {
    "idtyp": claims.get("idtyp"),
    "appid": claims.get("appid") or claims.get("azp"),
    "oid": claims.get("oid"),
}

from dataclasses import replace

from lhbackup_spark_v4.config import V4Config

# Retention defaults: 30-day minimum, extension runs flagged by the scheduler at
# most every 7 days, each version extended every 14 days to a 51-day target.
config = V4Config(
    minimum_retention_days=30,
    retention_extension_window_days=7,
    retention_extension_cadence_days=14,
    retention_target_days=51,
    parallelism=None,
    work_unit_max_files=10_000,
    work_unit_target_bytes=8 * 1024**3,
    result_micro_batch_work_units=32,
    status_heartbeat_seconds=300,
    immutability_mode="unlocked",
)
for name, cast in (
    ("execution_batch_work_units", int),
    ("token_usable_seconds", int),
    ("io_threads_per_task", int),
    ("execution_batch_target_minutes", int),
):
    raw = str(globals().get(name, "")).strip()
    if raw:
        config = replace(config, **{name: cast(raw)})


def flag(value):
    return str(value).strip().lower() in ("1", "true", "yes", "y")


def batch_context():
    return issue_token_context(credential, config)

import hashlib
import socket
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta

from azure.storage.blob import ContainerClient, ImmutabilityPolicy

from lhbackup_spark_v4.azure import AzureVersionCopyAdapter
from lhbackup_spark_v4.config import V4Config
from lhbackup_spark_v4.delta import SparkDeltaStore
from lhbackup_spark_v4.distributed import (
    SparkAzureWorkExecutor,
    SparkExactVersionValidator,
    SparkV4Orchestrator,
    process_plan_rows,
    validate_result_rows,
)
from lhbackup_spark_v4.models import (
    FinalRow,
    PlannedAction,
    PlanRow,
    ResultRow,
    SourceFile,
    Started,
)
from lhbackup_spark_v4.publication import AzureFinalInventoryPublisher
from lhbackup_spark_v4.tokens import jwt_claims

bench_id = bench_id or datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
SRC_PREFIX = f"{lakehouse_id}/Files/lhbackup_v4/bench/{bench_id}/src"
DELTA_ROOT = (
    f"abfss://{workspace_id}@onelake.dfs.fabric.microsoft.com/"
    f"{lakehouse_id}/Files/lhbackup_v4/bench/{bench_id}/delta"
)
BENCH_CONTAINER = "manifests"
DST_PREFIX = f"_v4bench/{bench_id}"
RESULTS_FILE = f"/lakehouse/default/Files/lhbackup_v4/bench/results/bench_{bench_id}.json"
bench_started = time.time()
run_time = datetime.now(timezone.utc).replace(microsecond=0)
bench_config = V4Config(
    minimum_retention_days=1,
    retention_extension_window_days=1,
    retention_extension_cadence_days=1,
    retention_target_days=3,
    retention_extend_when_remaining_days_lte=1,
    capture_budget_hours=0,
    immutability_mode="unlocked",
)
results = {"bench_id": bench_id, "identity": identity, "started_at": run_time.isoformat(), "sections": {}}
wanted = {item.strip() for item in sections.split(",") if item.strip()} | {"always"}


def save():
    os.makedirs(os.path.dirname(RESULTS_FILE), exist_ok=True)
    with open(RESULTS_FILE, "w") as handle:
        json.dump(results, handle, indent=2, default=str)


def section(name, function, group="io"):
    if group not in wanted:
        return None
    started = time.time()
    try:
        value = function()
        results["sections"][name] = {"ok": True, "seconds": round(time.time() - started, 3), "result": value}
    except Exception as exc:
        import traceback
        results["sections"][name] = {
            "ok": False, "seconds": round(time.time() - started, 3),
            "error": f"{type(exc).__name__}: {exc}"[:3000], "trace": traceback.format_exc()[-3000:],
        }
    save()
    print(name, json.dumps(results["sections"][name], default=str)[:1500])
    return results["sections"][name].get("result")


def run_tasks(name, items, partitions, threads, factory):
    """Run `items` as `partitions` Spark tasks with `threads` threads each.

    `factory(context)` runs on executors and returns `work(list) -> list`; a
    truthy element marks a successful item. One worker (own clients) per thread.
    """
    context = batch_context()

    def task(index, iterator):
        chunk = list(iterator)
        started = time.time()
        if threads <= 1:
            output = factory(context)(chunk)
        else:
            subsets = [chunk[offset::threads] for offset in range(threads)]
            workers = [factory(context) for _ in subsets]
            with ThreadPoolExecutor(threads) as pool:
                parts = list(pool.map(lambda pair: pair[0](pair[1]), zip(workers, subsets)))
            output = [item for part in parts for item in part]
        yield {
            "partition": index,
            "items": len(chunk),
            "ok": sum(1 for item in output if item),
            "seconds": round(time.time() - started, 3),
            "host": socket.gethostname(),
            "details": [item for item in output if isinstance(item, dict)],
        }

    started = time.time()
    stats = spark.sparkContext.parallelize(items, partitions).mapPartitionsWithIndex(task).collect()
    wall = time.time() - started
    details = [item for stat in stats for item in stat.pop("details")]
    task_seconds = [stat["seconds"] for stat in stats]
    return {
        "name": name,
        "partitions": partitions,
        "threads": threads,
        "items": len(items),
        "ok": sum(stat["ok"] for stat in stats),
        "wall_seconds": round(wall, 3),
        "items_per_second": round(len(items) / wall, 2) if wall else None,
        "max_task_seconds": max(task_seconds) if task_seconds else None,
        "hosts": sorted({stat["host"] for stat in stats}),
        "per_thread_items_per_second": round(
            len(items) / (max(task_seconds) * partitions * threads), 2
        ) if task_seconds and max(task_seconds) else None,
    }, details


# ---------------------------------------------------------------- environment
def environment():
    status = spark.sparkContext._jsc.sc().getExecutorMemoryStatus()
    return {
        "default_parallelism": spark.sparkContext.defaultParallelism,
        "executors_including_driver": status.size(),
        "executor_cores": spark.conf.get("spark.executor.cores", None),
        "executor_memory": spark.conf.get("spark.executor.memory", None),
        "driver_cores": spark.conf.get("spark.driver.cores", None),
        "dynamic_allocation": spark.conf.get("spark.dynamicAllocation.enabled", None),
        "spark_version": spark.version,
    }


def token_lifetime():
    first = notebookutils.credentials.getToken("storage")
    time.sleep(2)
    second = notebookutils.credentials.getToken("storage")
    claims = jwt_claims(first)
    now = time.time()
    return {
        "issued_at": claims.get("iat"),
        "expires": claims.get("exp"),
        "lifetime_minutes": round((claims["exp"] - claims.get("iat", claims.get("nbf", now))) / 60, 1),
        "remaining_minutes_at_check": round((claims["exp"] - now) / 60, 1),
        "repeat_call_returns_same_token": first == second,
    }


def trivial_job():
    durations = []
    for _ in range(5):
        started = time.time()
        slots = spark.sparkContext.defaultParallelism
        spark.sparkContext.parallelize(range(slots), slots).map(lambda value: value).count()
        durations.append(round(time.time() - started, 3))
    return {"seconds": durations}


section("environment", environment, "always")
section("token", token_lifetime, "always")
section("trivial_spark_job", trivial_job, "always")


# ---------------------------------------------------------------- generation
def generator(context):
    container = ContainerClient(onelake_url, workspace_id, credential=StaticTokenCredential(context))

    def work(chunk):
        output = []
        for item in chunk:
            container.get_blob_client(item["name"]).upload_blob(os.urandom(item["size"]), overwrite=True)
            output.append(True)
        return output

    return work


N_SMALL = int(small_files)
N_BIG = int(big_files)
small_items = [{"name": f"{SRC_PREFIX}/s100k/f{index:06d}.bin", "size": 100 * 1024} for index in range(N_SMALL)]
big_items = [{"name": f"{SRC_PREFIX}/big/f{index:03d}.bin", "size": 64 * 1024 * 1024} for index in range(N_BIG)]
section("generate_small", lambda: run_tasks("generate_small", small_items, 8, 8, generator)[0])
section("generate_big", lambda: run_tasks("generate_big", big_items, 8, 1, generator)[0])

# ---------------------------------------------------------------- listing
src_container = ContainerClient(onelake_url, workspace_id, credential=credential)
listed = {}


def listing():
    measurements = []
    for page_size in (5000, 1000):
        for repeat in range(2):
            started = time.time()
            pages = 0
            items = []
            for page in src_container.list_blobs(
                name_starts_with=f"{SRC_PREFIX}/", include=["metadata"], results_per_page=page_size
            ).by_page():
                pages += 1
                items.extend(page)
            seconds = time.time() - started
            files = [item for item in items if str((item.metadata or {}).get("hdi_isfolder", "")).lower() != "true"]
            measurements.append({
                "page_size": page_size, "repeat": repeat, "pages": pages, "files": len(files),
                "seconds": round(seconds, 3), "files_per_second": round(len(files) / seconds, 1),
                "seconds_per_page": round(seconds / pages, 3),
            })
            for item in files:
                listed[item.name] = (str(item.etag).strip('"'), int(item.size))
    return measurements


section("listing", listing)
small_rows = [
    {"path": name, "etag": listed[name][0], "size": listed[name][1], "file_id": hashlib.sha256(name.encode()).hexdigest()}
    for name in sorted(listed) if "/s100k/" in name
]
big_rows = [
    {"path": name, "etag": listed[name][0], "size": listed[name][1], "file_id": hashlib.sha256(name.encode()).hexdigest()}
    for name in sorted(listed) if "/big/" in name
]


# ---------------------------------------------------------------- copy
def copier(prefix):
    def factory(context):
        credential_ = StaticTokenCredential(context)
        adapter = AzureVersionCopyAdapter(
            ContainerClient(onelake_url, workspace_id, credential=credential_),
            ContainerClient(backup_storage_url, BENCH_CONTAINER, credential=credential_),
            bench_config,
            lambda row: f"{prefix}/{row.source.source_relative_path.rsplit('/', 1)[1]}",
        )

        def work(chunk):
            sizes = {item["file_id"]: item["size"] for item in chunk}
            rows = [
                PlanRow("bench", item["file_id"], SourceFile(
                    workspace_id, lakehouse_id, item["path"], onelake_url, item["etag"], item["size"],
                    "", "bench", "data",
                ), PlannedAction.COPY_NEW, 0)
                for item in chunk
            ]
            output = []
            # threads=1: the benchmark applies its own T threads around chunks.
            for result in process_plan_rows(
                rows, adapter, bench_config, run_time, context, threads=1
            ):
                if result.status != "SUCCEEDED":
                    output.append(False)
                    continue
                output.append({
                    "file_id": result.file_id, "status": "SUCCEEDED", "backup_blob": result.backup_blob,
                    "backup_version_id": result.backup_version_id, "backup_etag": result.backup_etag,
                    "content_hash": result.content_hash, "immutable_until": result.immutable_until,
                    "source_size": sizes[result.file_id],
                })
            return output

        return work

    return factory


GRID = [(1, 1), (2, 1), (4, 1), (8, 1), (8, 4), (8, 8)]
copied = []


def copy_small():
    measurements = []
    for partitions, threads in GRID:
        count = min(len(small_rows), partitions * threads * 100)
        stats, details = run_tasks(
            f"copy_p{partitions}_t{threads}", small_rows[:count], partitions, threads,
            copier(f"{DST_PREFIX}/copy_p{partitions}_t{threads}"),
        )
        stats["bytes"] = sum(row["size"] for row in small_rows[:count])
        measurements.append(stats)
        if len(details) > len(copied):
            copied[:] = details
    return measurements


def copy_big():
    measurements = []
    for partitions in (1, 8):
        count = 2 if partitions == 1 else len(big_rows)
        stats, _ = run_tasks(
            f"copy_big_p{partitions}", big_rows[:count], partitions, 1,
            copier(f"{DST_PREFIX}/big_p{partitions}"),
        )
        stats["bytes"] = sum(row["size"] for row in big_rows[:count])
        stats["mib_per_second"] = round(stats["bytes"] / 1048576 / stats["wall_seconds"], 1)
        measurements.append(stats)
    return measurements


section("copy_small", copy_small)
section("copy_big", copy_big)


# ---------------------------------------------------------------- validation
def validator_factory(context):
    adapter = AzureVersionCopyAdapter(
        None, ContainerClient(backup_storage_url, BENCH_CONTAINER, credential=StaticTokenCredential(context)),
        bench_config, None,
    )

    def work(chunk):
        valid = {value["backup_version_id"] for value in validate_result_rows(chunk, adapter, run_time, context)}
        return [item["backup_version_id"] in valid for item in chunk]

    return work


VALIDATE_GRID = [(1, 1), (2, 1), (4, 1), (8, 1), (8, 4), (8, 8), (8, 16)]


def validation():
    measurements = []
    for partitions, threads in VALIDATE_GRID:
        count = partitions * threads * 300
        items = [copied[index % len(copied)] for index in range(count)]
        stats, _ = run_tasks(f"validate_p{partitions}_t{threads}", items, partitions, threads, validator_factory)
        measurements.append(stats)
    return measurements


section("validate", validation)


# ---------------------------------------------------------------- extension
def extender(until):
    def factory(context):
        adapter = AzureVersionCopyAdapter(
            None, ContainerClient(backup_storage_url, BENCH_CONTAINER, credential=StaticTokenCredential(context)),
            bench_config, None,
        )

        def work(chunk):
            output = []
            for item in chunk:
                prior = FinalRow(
                    "bench", item["file_id"], workspace_id, lakehouse_id, "p", onelake_url, "e", item["source_size"],
                    "", "bench", "data", item["backup_blob"], item["backup_version_id"], item["backup_etag"],
                    item["content_hash"], item["immutable_until"], "COPY", run_time,
                )
                row = PlanRow("bench", item["file_id"], None, PlannedAction.VERIFY_REUSE, 0, prior)
                adapter.extend_retention(row, until)
                output.append(True)
            return output

        return work

    return factory


def extension():
    measurements = []
    for step, (partitions, threads) in enumerate([(1, 1), (8, 1), (8, 8)]):
        count = min(len(copied), partitions * threads * 100)
        until = run_time + timedelta(days=2, hours=step + 1)
        stats, _ = run_tasks(f"extend_p{partitions}_t{threads}", copied[:count], partitions, threads, extender(until))
        measurements.append(stats)
    return measurements


section("extend", extension)


# ---------------------------------------------------------------- bulk version listing
def version_listing():
    container = ContainerClient(backup_storage_url, BENCH_CONTAINER, credential=credential)
    measurements = []
    for repeat in range(2):
        started = time.time()
        pages = 0
        items = 0
        for page in container.list_blobs(
            name_starts_with=f"{DST_PREFIX}/", include=["versions", "metadata", "immutabilitypolicy"],
            results_per_page=5000,
        ).by_page():
            pages += 1
            items += sum(1 for _ in page)
        seconds = time.time() - started
        measurements.append({"pages": pages, "versions": items, "seconds": round(seconds, 3),
                             "versions_per_second": round(items / seconds, 1)})
    return measurements


section("version_listing", version_listing)


# ---------------------------------------------------------------- discovery
def discovery():
    started = time.time()
    tables = [row.asDict() for row in spark.sql("SHOW TABLES").collect() if not row.asDict().get("isTemporary")]
    show_seconds = time.time() - started
    timings = []
    for table in tables[:40]:
        name = table.get("tableName") or table.get("table_name")
        started = time.time()
        spark.sql(f"DESCRIBE DETAIL `{name}`").first()
        timings.append(time.time() - started)
    return {
        "tables": len(tables), "show_tables_seconds": round(show_seconds, 3),
        "describe_detail_seconds_mean": round(sum(timings) / len(timings), 3) if timings else None,
        "describe_detail_seconds_max": round(max(timings), 3) if timings else None,
        "described": len(timings),
    }


section("discovery", discovery, "spark")


# ---------------------------------------------------------------- Spark data plane (I/O stubbed)
class NullAdapter:
    """Accepts every file instantly so only the Spark/Delta work is measured."""

    def validate_reuse(self, row):
        return True

    def reconcile(self, row, when):
        return None

    def copy(self, row, when):
        return ResultRow(
            row.run_id, row.file_id, row.work_unit_id, str(uuid.uuid4()), "SUCCEEDED",
            f"null/{row.file_id}", "v1", "e1", "0" * 64, when + timedelta(days=40), False,
            datetime.now(timezone.utc), copy_performed=True,
        )

    def extend_retention(self, row, until):
        return None

    def validate_exact_version(self, expected):
        return True


def null_factory(context=None):
    return NullAdapter()


def synthetic_frames(rows):
    from pyspark.sql import functions as F

    partitions = spark.sparkContext.defaultParallelism
    base = spark.range(rows, numPartitions=partitions)
    table = (F.col("id") % 200).cast("string")
    current = base.select(
        F.lit(workspace_id).alias("workspace_id"),
        F.lit(lakehouse_id).alias("lakehouse_id"),
        F.concat(F.lit(f"{lakehouse_id}/Tables/bench_t"), table, F.lit("/part-"),
                 F.sha2(F.col("id").cast("string"), 256).substr(1, 32), F.lit(".snappy.parquet")).alias("source_relative_path"),
        F.lit(onelake_url).alias("source_url"),
        F.concat(F.lit("0x8DF"), F.upper(F.sha2(F.concat(F.col("id").cast("string"), F.lit("e")), 256).substr(1, 13))).alias("source_etag"),
        (F.lit(102400) + F.col("id") % 1000).cast("long").alias("source_size"),
        F.lit("").alias("schema_name"),
        F.concat(F.lit("bench_t"), table).alias("table_name"),
        F.when(F.col("id") % 50 == 0, F.lit("transaction_log")).otherwise(F.lit("data")).alias("category"),
        F.current_timestamp().alias("source_creation_time"),
        F.current_timestamp().alias("source_last_modified"),
        F.col("id"),
    )
    identity_ = F.concat_ws("\u0000", "workspace_id", "lakehouse_id", "source_relative_path")
    reused = current.filter(F.col("id") % 100 != 0)
    previous = reused.select(
        F.lit("previous").alias("run_id"),
        F.sha2(identity_, 256).alias("file_id"),
        "workspace_id", "lakehouse_id", "source_relative_path", "source_url", "source_etag", "source_size",
        "schema_name", "table_name", "category", "source_creation_time", "source_last_modified",
        F.concat(F.lit("backup/"), F.col("source_relative_path")).alias("backup_blob"),
        F.concat(F.lit("2026-10-16T00:00:00."), F.col("id").cast("string"), F.lit("Z")).alias("backup_version_id"),
        F.lit("0x8DF0000000000").alias("backup_etag"),
        F.sha2(F.col("id").cast("string"), 256).alias("content_hash"),
        F.when(F.col("id") % 10 == 1, F.lit(run_time + timedelta(days=29)))
        .otherwise(F.lit(run_time + timedelta(days=35))).cast("timestamp").alias("immutable_until"),
        F.lit("COPY").alias("copy_or_reuse"),
        F.lit(run_time).cast("timestamp").alias("verified_at"),
    )
    return current.drop("id"), previous


def synthetic(rows):
    root = f"{DELTA_ROOT}/n{rows}"
    config_ = V4Config()
    delta = SparkDeltaStore(spark)
    schema = delta._schema("results")
    orchestrator = SparkV4Orchestrator(
        config_, delta, SparkAzureWorkExecutor(null_factory, schema, config_),
        SparkExactVersionValidator(null_factory, schema), context_provider=batch_context,
    )
    started_obj = Started(
        f"syn{rows}", workspace_id, lakehouse_id, run_time, "bench", None,
        f"{root}/plan", f"{root}/results", f"{root}/final", "bench", 30, 10, 40,
    )
    current, previous = synthetic_frames(rows)
    current = current.cache()
    current.count()
    started = time.time()
    plan = orchestrator.prepare_plan(started_obj, current, previous, run_time)
    plan_seconds = time.time() - started
    batches = []
    last = [time.time()]

    def progress(results_version, completed):
        now = time.time()
        batches.append({"results_version": results_version, "completed": completed, "seconds": round(now - last[0], 2)})
        last[0] = now

    started = time.time()
    last[0] = started
    executed = orchestrator.execute_plan(started_obj, run_time, plan_version=plan.plan_version, progress=progress)
    execute_seconds = time.time() - started
    final_prefix = f"{lakehouse_id}/Files/lhbackup_v4/bench/{bench_id}/delta/n{rows}/final/"
    final_files = [
        blob for blob in src_container.list_blobs(name_starts_with=final_prefix, include=["metadata"])
        if str((blob.metadata or {}).get("hdi_isfolder", "")).lower() != "true"
    ]
    started = time.time()
    publisher = AzureFinalInventoryPublisher(
        src_container,
        ContainerClient(backup_storage_url, BENCH_CONTAINER, credential=credential),
        lambda path: f"{lakehouse_id}/{path.split('/' + lakehouse_id + '/', 1)[1]}",
        immutability_policy_for=lambda until: ImmutabilityPolicy(expiry_time=until, policy_mode="unlocked"),
        backup_root=f"{DST_PREFIX}/_inventory",
    )
    archive = publisher.publish(started_obj.final_path, executed.final_version, started_obj.run_id, run_time + timedelta(days=2))
    publish_seconds = time.time() - started
    return {
        "rows": rows,
        "plan_seconds": round(plan_seconds, 2),
        "files_to_copy": plan.files_to_copy,
        "files_to_reuse": plan.files_to_reuse,
        "retention_updates_required": plan.retention_updates_required,
        "execute_seconds": round(execute_seconds, 2),
        "batches": batches,
        "final_rows": executed.source_file_count,
        "copied": executed.copied_file_count,
        "reused": executed.reused_file_count,
        "extended": executed.retention_extended_file_count,
        "final_physical_files_all_versions": len(final_files),
        "final_physical_bytes_all_versions": sum(blob.size for blob in final_files),
        "worm_publish_seconds": round(publish_seconds, 2),
        "worm_files": archive.physical_file_count,
        "worm_bytes": archive.physical_total_bytes,
    }


for size in [int(value) for value in synthetic_sizes.split(",") if value.strip()] if "spark" in wanted else []:
    if (time.time() - bench_started) / 60 > float(synthetic_budget_minutes) and size > 100000:
        results["sections"][f"synthetic_{size}"] = {"ok": False, "skipped": "time budget"}
        save()
        continue
    section(f"synthetic_{size}", lambda size=size: synthetic(size))

results["finished_at"] = datetime.now(timezone.utc).isoformat()
results["total_seconds"] = round(time.time() - bench_started, 1)
save()
notebookutils.notebook.exit(json.dumps({"bench_id": bench_id, "results_file": RESULTS_FILE, "total_seconds": results["total_seconds"]}))

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

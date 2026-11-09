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

# MAGIC %%configure -f
# MAGIC {
# MAGIC   "conf": {
# MAGIC     "spark.dynamicAllocation.enabled": "false",
# MAGIC     "spark.executor.instances": "1"
# MAGIC   }
# MAGIC }


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# PARAMETERS CELL ********************

# Pipeline parameters
bundle_uri = "abfss://1f76d21a-09fe-4690-b7a4-d2b30a592264@onelake.dfs.fabric.microsoft.com/31997edc-ff2d-4968-9faf-3fe24bb67f66/Files/lhbackup_v4/lhbackup_spark_v4_bundle.zip"
workspace_id = "1f76d21a-09fe-4690-b7a4-d2b30a592264"
lakehouse_id = "31997edc-ff2d-4968-9faf-3fe24bb67f66"
onelake_url = "https://1f76d21a09fe4690b7a4d2b30a592264.z1f.blob.fabric.microsoft.com"
# Workspace-specific Fabric API host (Private Link workspaces cannot reach the
# public api.fabric.microsoft.com from Spark).
fabric_api_url = "https://1f76d21a09fe4690b7a4d2b30a592264.z1f.w.api.fabric.microsoft.com"
backup_storage_url = "https://fabric23456.blob.core.windows.net"
inventory_root = "abfss://1f76d21a-09fe-4690-b7a4-d2b30a592264@onelake.dfs.fabric.microsoft.com/31997edc-ff2d-4968-9faf-3fe24bb67f66/Files/lhbackup_v4/inventory"
results_dir = "/lakehouse/default/Files/lhbackup_v4/results"
run_id = ""
backup_scope_kind = "TABLE_SECTION"
backup_schemas_json = "[]"
# Set to "true" by the scheduler for the (weekly) retention-extension run.
retention_extension_run = "false"
audit_on_extension_run = "true"
exclude_shortcuts = "true"
# Optional tuning; empty = library default.
io_threads_per_task = ""
execution_batch_target_minutes = ""
execution_batch_work_units = ""
token_usable_seconds = ""


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
            fresh_claims = token_claims(fresh)
            if fresh_claims.get("idtyp") != "app":
                raise RuntimeError("storage token is not workspace identity")
            self.cached = AccessToken(fresh, int(fresh_claims["exp"]))
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
if identity["idtyp"] != "app":
    raise RuntimeError(
        "staged backup must run through a workspace-identity pipeline connection"
    )

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

from azure.storage.blob import ContainerClient
from pyspark.sql.types import LongType, StringType, StructField, StructType, TimestampType

from lhbackup_spark_v4.azure import (
    AzureBlobObjectStorage,
    AzureVersionCopyAdapter,
    http_transport,
)
from lhbackup_spark_v4.control import ControlRepository
from lhbackup_spark_v4.delta import SparkDeltaStore
from lhbackup_spark_v4.discovery import discover_table_folders, shortcut_prefixes
from lhbackup_spark_v4.distributed import SparkV4Orchestrator
from lhbackup_spark_v4.models import BackupScope, BackupScopeKind
from lhbackup_spark_v4.staged_run import StagedSparkBackupRun

extension_run = flag(retention_extension_run)
warnings = []


def list_shortcuts():
    """OneLake shortcuts point at data owned elsewhere; they are excluded."""
    import requests

    fabric_token = notebookutils.credentials.getToken("pbi")
    url = (
        f"{fabric_api_url}/v1/workspaces/"
        f"{workspace_id}/items/{lakehouse_id}/shortcuts"
    )
    items = []
    while url:
        response = requests.get(
            url, headers={"Authorization": f"Bearer {fabric_token}"}, timeout=(10, 60)
        )
        response.raise_for_status()
        body = response.json()
        items.extend(body.get("value", []))
        url = body.get("continuationUri")
    return items


excluded = ()
if flag(exclude_shortcuts):
    try:
        excluded = shortcut_prefixes(list_shortcuts(), lakehouse_id)
    except Exception as exc:
        # Fail open: backing up a shortcut costs more but loses nothing.
        warnings.append(f"shortcut listing unavailable, shortcuts included: {exc}")

discovery_started = time.time()
discovery_container = ContainerClient(
    onelake_url, workspace_id, credential=credential,
    transport=http_transport(config.discovery_threads * 2),
)
requested_schemas = tuple(json.loads(backup_schemas_json or "[]"))
tables = discover_table_folders(
    discovery_container,
    lakehouse_id,
    schemas=requested_schemas if backup_scope_kind == "SCHEMAS" else (),
    excluded_prefixes=excluded,
    threads=config.discovery_threads,
)
if not tables:
    raise RuntimeError("backup scope discovered no Delta tables")
discovery_seconds = round(time.time() - discovery_started, 3)
listing_context = batch_context()


def list_table(spec):
    local_credential = StaticTokenCredential(listing_context)
    container = ContainerClient(
        onelake_url, workspace_id, credential=local_credential
    )
    prefix = spec["prefix"]
    rows = []
    for item in container.list_blobs(
        name_starts_with=prefix,
        include=["metadata"],
        results_per_page=config.page_size,
    ):
        metadata = item.metadata or {}
        if str(metadata.get("hdi_isfolder", "")).lower() == "true":
            continue
        relative = item.name[len(prefix):]
        if not relative:
            continue
        rows.append((
            workspace_id,
            lakehouse_id,
            item.name,
            onelake_url,
            str(item.etag).strip('"'),
            int(item.size),
            spec["schema_name"],
            spec["table_name"],
            "transaction_log" if relative.startswith("_delta_log/") else "data",
            item.creation_time.replace(tzinfo=None) if item.creation_time else None,
            item.last_modified.replace(tzinfo=None) if item.last_modified else None,
        ))
    return rows


source_schema = StructType([
    StructField("workspace_id", StringType(), False),
    StructField("lakehouse_id", StringType(), False),
    StructField("source_relative_path", StringType(), False),
    StructField("source_url", StringType(), False),
    StructField("source_etag", StringType(), False),
    StructField("source_size", LongType(), False),
    StructField("schema_name", StringType(), False),
    StructField("table_name", StringType(), False),
    StructField("category", StringType(), False),
    StructField("source_creation_time", TimestampType(), True),
    StructField("source_last_modified", TimestampType(), True),
])
partitions = min(
    len(tables),
    max(1, spark.sparkContext.defaultParallelism * config.tasks_per_core),
)
current = spark.createDataFrame(
    spark.sparkContext.parallelize(tables, partitions).flatMap(list_table),
    source_schema,
).cache()
# List now, while listing_context is fresh (the weekly audit below can be long).
listed_files = current.count()

control_container = ContainerClient(
    backup_storage_url, "control", credential=credential
)
control = ControlRepository(
    AzureBlobObjectStorage(control_container), workspace_id, lakehouse_id
)
delta = SparkDeltaStore(spark)
scope_kind = BackupScopeKind(backup_scope_kind)
scope = BackupScope(
    scope_kind,
    tuple(json.loads(backup_schemas_json or "[]"))
    if scope_kind == BackupScopeKind.SCHEMAS
    else (),
)


def covers(marker):
    if marker.backup_scope.kind == BackupScopeKind.TABLE_SECTION:
        return True
    if scope.kind == BackupScopeKind.TABLE_SECTION:
        return False
    return set(scope.schemas).issubset(set(marker.backup_scope.schemas))


completed = [item for item in control.completed_runs() if covers(item)]
previous = (
    max(completed, key=lambda item: (item.finished_at, item.run_id))
    if completed
    else None
)
if previous and previous.final and delta.exists(previous.final.path):
    previous_final = delta.read_frame(
        previous.final.path, previous.final.delta_version
    )
    previous_run_id = previous.run_id
else:
    previous_final = spark.createDataFrame([], delta._schema("final"))
    previous_run_id = None

data_plane = SparkV4Orchestrator(
    config, delta, None, None, context_provider=batch_context
)


def audit_lister(context):
    # Runs on executors: only the driver-issued context is referenced.
    local_credential = StaticTokenCredential(context)
    backup = ContainerClient(
        backup_storage_url, "tables", credential=local_credential
    )
    return AzureVersionCopyAdapter(None, backup, config, None)


def backup_table_prefix(schema_name, table_name):
    schema_part = f"{schema_name}/" if schema_name else ""
    return f"{workspace_id}/{lakehouse_id}/{schema_part}{table_name}/"


# Weekly audit on extension runs: one bulk version listing per table prefix
# checks the ledger against the backup storage account.
audit_failed = None
audit_seconds = 0.0
if extension_run and previous_run_id is not None and flag(audit_on_extension_run):
    audit_started = time.time()
    audit_prefixes = sorted({
        backup_table_prefix(row["schema_name"], row["table_name"])
        for row in previous_final.select("schema_name", "table_name")
        .distinct().toLocalIterator()
    })
    audit_failed = data_plane.audit_ledger(
        previous_final, audit_prefixes, audit_lister
    )
    audit_failed.count()
    audit_seconds = round(time.time() - audit_started, 3)

runner = StagedSparkBackupRun(
    config,
    control,
    data_plane,
    owner_id=f"pipeline-plan-{run_id}",
    started_by="workspace-identity",
    inventory_root=inventory_root,
    final_inventory_publisher=None,
)
started_clock = time.time()
plan = runner.prepare(
    run_id, current, previous_final, previous_run_id, scope,
    retention_extension_run=extension_run,
    audit_failed_frame=audit_failed,
)
result = {
    **plan.__dict__,
    "run_id": run_id,
    "state": "PLANNED",
    "retention_extension_run": extension_run,
    "table_count": len(tables),
    "listed_files": listed_files,
    "discovery_seconds": discovery_seconds,
    "audit_seconds": audit_seconds,
    "warnings": warnings,
    "identity": identity,
    "elapsed_seconds": round(time.time() - started_clock, 3),
}
os.makedirs(results_dir, exist_ok=True)
with open(f"{results_dir}/plan_{run_id}.json", "w") as handle:
    json.dump(result, handle, indent=2, default=str)
notebookutils.notebook.exit(json.dumps(result, separators=(",", ":"), default=str))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

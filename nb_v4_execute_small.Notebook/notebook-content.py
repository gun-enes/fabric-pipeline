# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   }
# META }

# CELL ********************

# MAGIC %%configure -f
# MAGIC {
# MAGIC   "conf": {
# MAGIC     "spark.dynamicAllocation.enabled": "false",
# MAGIC     "spark.executor.instances": "1",
# MAGIC         
# MAGIC     "spark.dynamicAllocation.enabled": "true",
# MAGIC     "spark.dynamicAllocation.minExecutors": "1",
# MAGIC     "spark.dynamicAllocation.initialExecutors": "1",
# MAGIC     "spark.dynamicAllocation.maxExecutors": "1"
# MAGIC   }
# MAGIC }
# MAGIC 
# MAGIC %%configure -f
# MAGIC {
# MAGIC   "conf": {
# MAGIC     "spark.dynamicAllocation.enabled": "true",
# MAGIC     "spark.dynamicAllocation.minExecutors": "1",
# MAGIC     "spark.dynamicAllocation.initialExecutors": "2",
# MAGIC     "spark.dynamicAllocation.maxExecutors": "4"
# MAGIC   }
# MAGIC }
# MAGIC 


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# PARAMETERS CELL ********************

# Pipeline parameters
bundle_uri = ""
workspace_id = ""
lakehouse_id = ""
onelake_url = ""
# Workspace-specific Fabric API host (Private Link workspaces cannot reach the
# public api.fabric.microsoft.com from Spark).
fabric_api_url = ""
backup_storage_url = ""
inventory_root = ""
results_dir = "/lakehouse/default/Files/lhbackup_v4/results"
run_id = ""
# TABLE_SECTION | SCHEMAS | FILES_SECTION | FOLDERS | WHOLE_LAKEHOUSE
backup_scope_kind = "TABLE_SECTION"
backup_schemas_json = "[]"
# FOLDERS scope: folders below Files/, e.g. ["raw/sales", "reference"].
backup_folders_json = "[]"
# Paths relative to the Lakehouse root that are never backed up, e.g.
# ["Tables/*/_metadata", "Files/tmp", "*.crc"]. A pattern without wildcards
# excludes that folder and everything below it; Files/lhbackup_v4 (this tool's
# own folder) is always excluded.
excluded_paths_json = "[]"
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

from azure.storage.blob import ContainerClient, ImmutabilityPolicy

from lhbackup_spark_v4.azure import (
    AzureBlobObjectStorage,
    AzureVersionCopyAdapter,
    http_transport,
)
from lhbackup_spark_v4.control import ControlRepository
from lhbackup_spark_v4.delta import SparkDeltaStore
from lhbackup_spark_v4.distributed import SparkAzureWorkExecutor, SparkV4Orchestrator
from lhbackup_spark_v4.models import to_json_dict
from lhbackup_spark_v4.publication import AzureFinalInventoryPublisher
from lhbackup_spark_v4.scope import backup_blob_name
from lhbackup_spark_v4.staged_run import StagedSparkBackupRun

control_container = ContainerClient(
    backup_storage_url, "control", credential=credential
)
control = ControlRepository(
    AzureBlobObjectStorage(control_container), workspace_id, lakehouse_id
)
started, _ = control.read_started(run_id)
delta = SparkDeltaStore(spark)


def backup_path_for(row):
    # <ws>/<lh>/Tables/... or <ws>/<lh>/Files/... (versions written before the
    # section folder existed keep their recorded names in the ledger).
    return backup_blob_name(workspace_id, lakehouse_id, row.source.source_relative_path)


def adapter_factory(context):
    # Runs on executors: reference only the driver-issued context, never the
    # driver credential (it would pull notebookutils into the task closure).
    local_credential = StaticTokenCredential(context)
    # One HTTP connection pool per task, sized for its I/O threads plus the
    # parallel ranges of large files.
    transport = http_transport(
        config.io_threads_per_task
        + config.large_file_threads * config.large_file_chunk_concurrency
    )
    source = ContainerClient(
        onelake_url, workspace_id, credential=local_credential, transport=transport
    )
    backup = ContainerClient(
        backup_storage_url, "tables", credential=local_credential, transport=transport
    )
    return AzureVersionCopyAdapter(source, backup, config, backup_path_for)


result_schema = delta._schema("results")
executor = SparkAzureWorkExecutor(adapter_factory, result_schema, config)
# Backup trusts its ledger: no exact-version validator (restore keeps one).
data_plane = SparkV4Orchestrator(
    config, delta, executor, None, context_provider=batch_context
)
publication_transport = http_transport(
    config.publication_threads * config.large_file_chunk_concurrency
)
inventory_source = ContainerClient(
    onelake_url, workspace_id, credential=credential,
    transport=publication_transport,
)
inventory_backup = ContainerClient(
    backup_storage_url, "tables", credential=credential,
    transport=publication_transport,
)


def final_source_prefix(final_path):
    marker = f"/{lakehouse_id}/"
    if marker not in final_path:
        raise ValueError(f"unexpected final Delta path: {final_path}")
    return f"{lakehouse_id}/{final_path.split(marker, 1)[1]}"


publisher = AzureFinalInventoryPublisher(
    inventory_source,
    inventory_backup,
    final_source_prefix,
    immutability_policy_for=lambda until: ImmutabilityPolicy(
        expiry_time=until, policy_mode=config.immutability_mode
    ),
    backup_root=f"{workspace_id}/{lakehouse_id}/_inventory",
    max_files_per_work_unit=config.work_unit_max_files,
    target_bytes_per_work_unit=config.work_unit_target_bytes,
    threads=config.publication_threads,
    chunk_bytes=config.large_file_chunk_bytes,
    chunk_concurrency=config.large_file_chunk_concurrency,
)
runner = StagedSparkBackupRun(
    config,
    control,
    data_plane,
    owner_id=f"pipeline-execute-{run_id}",
    started_by="workspace-identity",
    inventory_root=inventory_root,
    final_inventory_publisher=publisher,
)
started_clock = time.time()
marker = runner.execute(run_id)
result = {
    "run_id": run_id,
    "state": "COMPLETED",
    "marker": to_json_dict(marker),
    "identity": identity,
    "spark_default_parallelism": spark.sparkContext.defaultParallelism,
    "elapsed_seconds": round(time.time() - started_clock, 3),
}
os.makedirs(results_dir, exist_ok=True)
with open(f"{results_dir}/execute_{run_id}.json", "w") as handle:
    json.dump(result, handle, indent=2, default=str)
notebookutils.notebook.exit(json.dumps(result, separators=(",", ":"), default=str))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

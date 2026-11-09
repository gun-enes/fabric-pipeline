# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   }
# META }

# PARAMETERS CELL ********************

# Pipeline parameters
bundle_uri = ""
backup_storage_url = ""
target_workspace_id = ""
target_onelake_url = ""
target_lakehouse_id = ""
source_workspace_id = ""
source_lakehouse_id = ""
results_dir = "/lakehouse/default/Files/lhbackup_v4/restore_results"
run_id = ""
restore_mode = "RESTORE"
# TABLE_SECTION | SCHEMAS | TABLES | FILES_SECTION | FOLDERS | WHOLE_LAKEHOUSE
restore_scope_kind = "TABLE_SECTION"
restore_schemas_json = "[]"
restore_tables_json = "[]"
# FOLDERS scope: folders below Files/, e.g. ["raw/sales"].
restore_folders_json = "[]"
recovery_run_id = ""
allow_unprotected = "false"
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

from lhbackup_spark_v4.azure import AzureBlobObjectStorage
from lhbackup_spark_v4.control import ControlRepository
from lhbackup_spark_v4.delta import SparkDeltaStore
from lhbackup_spark_v4.publication import AzureFinalInventoryPublisher
from lhbackup_spark_v4.restore import list_recovery_points
from lhbackup_spark_v4.restore_run import (
    AzureRestoreAdapter,
    RestoreRequest,
    SparkRestoreRun,
)

mode = str(restore_mode or "RESTORE").strip().upper()
if mode not in ("RESTORE", "LIST"):
    raise ValueError("restore_mode must be RESTORE or LIST")
request = RestoreRequest.from_parameters(
    restore_id=run_id,
    source_workspace_id=source_workspace_id,
    source_lakehouse_id=source_lakehouse_id,
    target_workspace_id=target_workspace_id,
    target_lakehouse_id=target_lakehouse_id,
    scope_kind=restore_scope_kind,
    schemas_json=restore_schemas_json,
    tables_json=restore_tables_json,
    folders_json=restore_folders_json,
    recovery_run_id=recovery_run_id,
    allow_unprotected=allow_unprotected,
)
work_root = (
    f"abfss://{target_workspace_id}@onelake.dfs.fabric.microsoft.com/"
    f"{target_lakehouse_id}/Files/lhbackup_v4/restore"
)


def lakehouse_prefix(path):
    marker = f"/{target_lakehouse_id}/"
    if marker not in path:
        raise ValueError(f"unexpected restore work path: {path}")
    return f"{target_lakehouse_id}/{path.split(marker, 1)[1].rstrip('/')}"


control = ControlRepository(
    AzureBlobObjectStorage(
        ContainerClient(backup_storage_url, "control", credential=credential)
    ),
    source_workspace_id,
    source_lakehouse_id,
)
target_container = ContainerClient(
    target_onelake_url, target_workspace_id, credential=credential
)
publisher = AzureFinalInventoryPublisher(
    None,
    ContainerClient(backup_storage_url, "tables", credential=credential),
    None,
    immutability_policy_for=None,
    backup_root="",
    restore_container=target_container,
    restore_prefix_for=lakehouse_prefix,
)


def adapter_factory(context):
    # Runs on executors: reference only the driver-issued context.
    local_credential = StaticTokenCredential(context)
    return AzureRestoreAdapter(
        ContainerClient(backup_storage_url, "tables", credential=local_credential),
        ContainerClient(target_onelake_url, target_workspace_id, credential=local_credential),
        target_lakehouse_id,
    )


def run_restore():
    runner = SparkRestoreRun(
        config,
        control,
        SparkDeltaStore(spark),
        publisher,
        adapter_factory,
        target_container,
        target_container,
        work_root=work_root,
        state_prefix_for=lakehouse_prefix,
        context_provider=batch_context,
    )
    outcome = runner.run(request)
    # Smoke check: every restored table opens as Delta and reports its row count.
    table_root = (
        f"abfss://{target_workspace_id}@onelake.dfs.fabric.microsoft.com/{target_lakehouse_id}"
    )
    for table in outcome["tables"]:
        location = f"{table_root}/{table['target_prefix'].split('/', 1)[1].rstrip('/')}"
        table["row_count"] = spark.read.format("delta").load(location).count()
    return outcome


def list_cycles():
    # LIST mode: show the backup cycles available for this scope; nothing is restored.
    return {
        "mode": "LIST",
        "source_workspace_id": source_workspace_id,
        "source_lakehouse_id": source_lakehouse_id,
        "restore_scope": request.scope.kind.value,
        "recovery_points": list_recovery_points(control, scope=request.scope),
    }


started_clock = time.time()
result = list_cycles() if mode == "LIST" else run_restore()
result["identity"] = identity
result["elapsed_seconds"] = round(time.time() - started_clock, 3)
os.makedirs(results_dir, exist_ok=True)
prefix = "list" if mode == "LIST" else "restore"
with open(f"{results_dir}/{prefix}_{run_id}.json", "w") as handle:
    json.dump(result, handle, indent=2, default=str)
notebookutils.notebook.exit(json.dumps(result, separators=(",", ":"), default=str))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

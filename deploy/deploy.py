"""Deploy the Fabric items in this repo to one workspace using fabric-cicd.

Usage:
  python deploy/deploy.py --env test --workspace-id <guid>

--env / --workspace-id fall back to FABRIC_ENVIRONMENT / FABRIC_WORKSPACE_ID.

Authentication uses DefaultAzureCredential:
  - in CI: service principal via AZURE_TENANT_ID / AZURE_CLIENT_ID / AZURE_CLIENT_SECRET
  - locally: your own account after `az login`
"""

import argparse
import os
from pathlib import Path

import yaml
from azure.identity import DefaultAzureCredential
from fabric_cicd import FabricWorkspace, publish_all_items, unpublish_all_orphan_items

REPO_ROOT = Path(__file__).resolve().parent.parent

parser = argparse.ArgumentParser()
parser.add_argument("--env", default=os.environ.get("FABRIC_ENVIRONMENT"), choices=["dev", "test", "prod"])
parser.add_argument("--workspace-id", default=os.environ.get("FABRIC_WORKSPACE_ID"))
parser.add_argument("--keep-orphans", action="store_true", help="don't delete workspace items missing from the repo")
args = parser.parse_args()
if not args.env or not args.workspace_id:
    parser.error("--env and --workspace-id are required (or set FABRIC_ENVIRONMENT / FABRIC_WORKSPACE_ID)")

parameter_file = REPO_ROOT / "parameters" / f"{args.env}.yml"

# fabric-cicd only logs an error for a missing `extend` file and deploys without its values; fail instead.
for included in yaml.safe_load(parameter_file.read_text()).get("extend", []):
    if not (parameter_file.parent / included).is_file():
        parser.error(f"{parameter_file.relative_to(REPO_ROOT)} extends missing file: {included}")

workspace = FabricWorkspace(
    workspace_id=args.workspace_id,
    environment=args.env,
    repository_directory=str(REPO_ROOT),
    item_type_in_scope=["DataPipeline"],
    token_credential=DefaultAzureCredential(),
    parameter_file_path=str(parameter_file),
)

publish_all_items(workspace)
if not args.keep_orphans:
    # Remove items from the target workspace that no longer exist in the repo.
    unpublish_all_orphan_items(workspace)

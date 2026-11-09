import os
import base64
import argparse
import platform
import requests
from pathlib import Path

# Use Windows certificate store for SSL (handles corporate proxy CAs)
if platform.system() == "Windows":
    try:
        import truststore
        truststore.inject_into_ssl()
    except ImportError:
        pass

# -----------------------------
# CONFIGURATION (via CLI args or env vars)
# -----------------------------
parser = argparse.ArgumentParser(description="Export all items from a Microsoft Fabric workspace.")
parser.add_argument("--tenant-id", default=os.environ.get("TENANT_ID", ""), help="Azure AD tenant ID")
parser.add_argument("--client-id", default=os.environ.get("CLIENT_ID", ""), help="Service principal client ID")
parser.add_argument("--client-secret", default=os.environ.get("CLIENT_SECRET", ""), help="Service principal client secret")
parser.add_argument("--workspace-id", default=os.environ.get("WORKSPACE_ID", ""), help="Fabric workspace ID (if omitted, --workspace-name is used to look it up)")
parser.add_argument("--workspace-name", default=os.environ.get("WORKSPACE_NAME", ""), help="Fabric workspace name (used to look up ID if --workspace-id is not provided)")
parser.add_argument("--output-dir", default=os.environ.get("OUTPUT_DIR", "workspace"), help="Output directory for exported items")
parser.add_argument("--auth-mode", default=os.environ.get("AUTH_MODE", "user"), choices=["service_principal", "user"], help="Authentication mode")
args = parser.parse_args()

TENANT_ID = args.tenant_id
CLIENT_ID = args.client_id
CLIENT_SECRET = args.client_secret
WORKSPACE_NAME = args.workspace_name
OUTPUT_DIR = args.output_dir
AUTH_MODE = args.auth_mode


def resolve_workspace_id(token, workspace_id, workspace_name):
    """Resolve workspace ID from name if ID is not provided."""
    if workspace_id:
        return workspace_id
    if not workspace_name:
        raise ValueError("Either --workspace-id or --workspace-name must be provided.")

    headers = {"Authorization": f"Bearer {token}"}
    url = "https://api.fabric.microsoft.com/v1/workspaces"
    print(f"Listing workspaces to resolve name '{workspace_name}'...")
    while url:
        resp = requests.get(url, headers=headers)
        resp.raise_for_status()
        data = resp.json()
        for ws in data.get("value", []):
            if ws.get("displayName", "").lower() == workspace_name.lower():
                print(f"Resolved workspace '{workspace_name}' -> {ws['id']}")
                return ws["id"]
        url = data.get("continuationUri")

    raise ValueError(f"Workspace with name '{workspace_name}' not found.")


# Workspace ID will be resolved after authentication
_WORKSPACE_ID_ARG = args.workspace_id

# Microsoft Fabric REST API endpoints
AUTH_URL = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"
DEVICE_CODE_URL = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/devicecode"
BULK_EXPORT_URL = None  # Set dynamically after workspace ID is resolved
# -----------------------------
# AUTHENTICATION
# -----------------------------
def get_access_token():
    """Get access token using configured auth mode."""
    if AUTH_MODE == "service_principal":
        return _get_token_service_principal()
    else:
        return _get_token_user_device_code()

def _get_token_service_principal():
    """Get token via client credentials (service principal)."""
    payload = {
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "scope": "https://api.fabric.microsoft.com/.default",
        "grant_type": "client_credentials"
    }
    resp = requests.post(AUTH_URL, data=payload)
    resp.raise_for_status()
    print("✅ Service principal authentication successful!")
    return resp.json()["access_token"]

def _get_token_user_device_code():
    """Get token via interactive browser login (authorization code + PKCE).
    Falls back to device code if browser is unavailable."""
    from azure.identity import InteractiveBrowserCredential

    credential = InteractiveBrowserCredential(
        tenant_id=TENANT_ID
    )
    token = credential.get_token("https://api.fabric.microsoft.com/.default")
    print("✅ Authentication successful!\n")
    return token.token

# -----------------------------
# BULK EXPORT
# -----------------------------
def bulk_export_items(token):
    """Call Fabric Bulk Export API and poll for completion (LRO)."""
    headers = {"Authorization": f"Bearer {token}"}
    resp = requests.post(BULK_EXPORT_URL, headers=headers, json={"mode": "All"})
    resp.raise_for_status()

    # If 200, return directly
    if resp.status_code == 200:
        return resp.json()

    # If 202, poll the operation location until complete
    operation_url = resp.headers.get("Location") or resp.headers.get("Operation-Location")
    if not operation_url:
        raise ValueError("202 response but no Location/Operation-Location header found. "
                         f"Headers: {dict(resp.headers)}")

    retry_after = int(resp.headers.get("Retry-After", 5))
    print(f"Export started (202 Accepted). Polling: {operation_url}")

    import time
    while True:
        time.sleep(retry_after)
        poll_resp = requests.get(operation_url, headers=headers)
        poll_resp.raise_for_status()
        poll_data = poll_resp.json()
        status = poll_data.get("status", "").lower()
        print(f"  Status: {status}")

        if status in ("succeeded", "completed"):
            # Fetch the result from the resource location
            result_url = poll_data.get("resourceLocation") or poll_data.get("resultLocation")
            if not result_url:
                # Fabric LRO convention: append /result to the operation URL
                result_url = operation_url.rstrip("/") + "/result"
            print(f"  Fetching result from: {result_url}")
            result_resp = requests.get(result_url, headers=headers)
            if result_resp.status_code == 404:
                # Fallback: try the base bulk export URL as GET
                fallback_url = BULK_EXPORT_URL.replace("bulkExportDefinitions", "bulkExportDefinitions/result")
                print(f"  Result URL returned 404, trying fallback: {fallback_url}")
                result_resp = requests.get(fallback_url, headers=headers)
            result_resp.raise_for_status()
            return result_resp.json()
        elif status in ("failed", "cancelled"):
            raise RuntimeError(f"Bulk export {status}: {poll_data}")
        # else still running, keep polling
        retry_after = int(poll_resp.headers.get("Retry-After", 5))

# -----------------------------
# SAVE EXPORTED DEFINITIONS
# -----------------------------
def save_items_from_manifest(manifest):
    """Decode Base64 payloads from bulk export response and save to files."""
    import shutil
    output_path = Path(OUTPUT_DIR)
    if output_path.exists():
        print(f"Cleaning output directory (preserving parameter.yml): {output_path}")
        for item in output_path.iterdir():
            if item.name == "parameter.yml":
                continue
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()
    output_path.mkdir(parents=True, exist_ok=True)

    # Log the index of exported items
    index = manifest.get("itemDefinitionsIndex", [])
    print(f"Found {len(index)} item(s) in export index:")
    for entry in index:
        print(f"  - {entry.get('rootPath')} (id: {entry.get('id')})")

    # Save each definition part
    parts = manifest.get("definitionParts", [])
    if not parts:
        print("No definition parts found in response.")
        print(f"Response keys: {list(manifest.keys())}")
        return

    resolved_output = output_path.resolve()
    for part in parts:
        rel_path = part.get("path", "").lstrip("/")
        payload_b64 = part.get("payload", "")
        payload_type = part.get("payloadType", "")

        if not rel_path or not payload_b64:
            continue

        try:
            content_bytes = base64.b64decode(payload_b64)
        except Exception as e:
            print(f"Error decoding {rel_path}: {e}")
            continue

        # Recreate the folder structure under OUTPUT_DIR
        file_path = (output_path / rel_path).resolve()
        if not str(file_path).startswith(str(resolved_output) + os.sep):
            print(f"Skipping unsafe path: {rel_path}")
            continue
        file_path.parent.mkdir(parents=True, exist_ok=True)

        with open(file_path, "wb") as f:
            f.write(content_bytes)

        print(f"Saved: {file_path}")

    print(f"\nTotal parts saved: {len(parts)}")

# -----------------------------
# MAIN EXECUTION
# -----------------------------
if __name__ == "__main__":
    try:
        token = get_access_token()
        WORKSPACE_ID = resolve_workspace_id(token, _WORKSPACE_ID_ARG, WORKSPACE_NAME)
        BULK_EXPORT_URL = f"https://api.fabric.microsoft.com/v1/workspaces/{WORKSPACE_ID}/items/bulkExportDefinitions?beta=True"
        print(f"Exporting from workspace: {WORKSPACE_ID}")
        manifest = bulk_export_items(token)
        save_items_from_manifest(manifest)
        print("✅ Export and decode completed.")
    except requests.HTTPError as http_err:
        print(f"HTTP error: {http_err.response.status_code} - {http_err.response.text}")
        print(f"  Request URL: {http_err.response.request.method} {http_err.response.request.url}")
        import sys
        sys.exit(1)
    except Exception as e:
        print(f"Error when accessing workspace: {e}")
        import sys
        sys.exit(1)
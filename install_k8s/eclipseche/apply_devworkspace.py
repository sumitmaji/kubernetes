import time, yaml, sys, os
from kubernetes import client, config
from kubernetes.client.rest import ApiException

NAMESPACE = os.environ.get("CHE_USER_NAMESPACE", "che-user")  # <-- set this
MANIFEST_FILE = os.environ.get("DW_FILE", "devworkspace.yaml")
GROUP = "workspace.devfile.io"
VERSION = "v1alpha2"
PLURAL = "devworkspaces"

def kget(crd_api, name):
    return crd_api.get_namespaced_custom_object(GROUP, VERSION, NAMESPACE, PLURAL, name)

def kcreate(crd_api, body):
    return crd_api.create_namespaced_custom_object(GROUP, VERSION, NAMESPACE, PLURAL, body)

def kpatch(crd_api, name, body):
    return crd_api.patch_namespaced_custom_object(GROUP, VERSION, NAMESPACE, PLURAL, name, body)

def main():
    # Kube auth (uses your ~/.kube/config by default)
    try:
        config.load_kube_config()
    except Exception:
        # If running inside-cluster (CI Job/Pod)
        config.load_incluster_config()

    with open(MANIFEST_FILE, "r") as f:
        manifest = yaml.safe_load(f)
    name = manifest["metadata"]["name"]

    crd_api = client.CustomObjectsApi()

    # Create or patch the DevWorkspace
    try:
        _ = kget(crd_api, name)
        kpatch(crd_api, name, manifest)
        print(f"Patched DevWorkspace '{name}' in namespace '{NAMESPACE}'.")
    except ApiException as e:
        if e.status == 404:
            kcreate(crd_api, manifest)
            print(f"Created DevWorkspace '{name}' in namespace '{NAMESPACE}'.")
        else:
            raise

    # Poll status until Running (or timeout)
    timeout_s = int(os.environ.get("DW_TIMEOUT_SECONDS", "900"))  # 15 min
    poll = 5
    waited = 0
    last_phase = None

    while waited < timeout_s:
        time.sleep(poll)
        waited += poll
        ws = kget(crd_api, name)
        phase = ws.get("status", {}).get("phase")
        conditions = ws.get("status", {}).get("conditions", [])
        urls = ws.get("status", {}).get("routing", {}).get("endpoints", []) or ws.get("status", {}).get("endpoints", [])

        if phase != last_phase:
            print(f"Status phase: {phase}")
            last_phase = phase

        # Print any endpoint URLs if present
        if urls:
            try:
                # DWO versions differ; handle both simple list and list of dicts
                lines = []
                for ep in urls:
                    if isinstance(ep, dict):
                        name = ep.get("name")
                        url = ep.get("url") or ep.get("exposedEndpoint", {}).get("url")
                        if url:
                            lines.append(f"- {name or 'endpoint'}: {url}")
                    elif isinstance(ep, str):
                        lines.append(f"- {ep}")
                if lines:
                    print("Endpoints:\n" + "\n".join(lines))
            except Exception:
                pass

        if phase in ("Running", "Succeeded"):
            print("Workspace is ready.")
            return 0

        # Surface failing condition quickly
        for c in conditions or []:
            if c.get("type") in ("Failed", "Error") or c.get("status") == "False" and c.get("type") == "Ready":
                print(f"[{c.get('type')}] {c.get('reason')}: {c.get('message')}")
    print("Timed out waiting for DevWorkspace to become Running.")
    return 1

if __name__ == "__main__":
    sys.exit(main())

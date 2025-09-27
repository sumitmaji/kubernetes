import os
import sys
from kubernetes import client, config

def create_configmap(namespace, configmap_name, file_list):
    config.load_kube_config()
    v1 = client.CoreV1Api()

    # Check if ConfigMap exists
    try:
        v1.read_namespaced_config_map(configmap_name, namespace)
        print(f"ConfigMap '{configmap_name}' already exists in namespace '{namespace}'. Skipping creation.")
        return
    except client.exceptions.ApiException as e:
        if e.status != 404:
            print(f"Error checking ConfigMap '{configmap_name}': {e}")
            return
        # If 404, proceed to create

    data = {}
    for filename in file_list:
        with open(filename, 'r') as f:
            # Use just the basename as the key (e.g., "README.md" instead of "./README.md")
            key = os.path.basename(filename)
            data[key] = f.read()

    labels = {
        "controller.devfile.io/mount-to-devworkspace": "true",
        "controller.devfile.io/watch-configmap": "true"
    }
    
    # Set a specific annotation for each file based on its relative path
    file_path = list(file_list)[0]
    relative_path = os.path.relpath(file_path, '.')
    mount_path = f"/tmp/projects/nlp/{os.path.dirname(relative_path)}" if os.path.dirname(relative_path) != '.' else "/tmp/projects"
    
    base_annotations = {
        "controller.devfile.io/mount-as": "subpath",
        "controller.devfile.io/mount-path": mount_path
    }
    annotations = base_annotations.copy()
    configmap = client.V1ConfigMap(
        metadata=client.V1ObjectMeta(name=configmap_name, labels=labels, annotations=annotations),
        data=data
    )

    v1.create_namespaced_config_map(namespace=namespace, body=configmap)
    print(f"ConfigMap '{configmap_name}' created in namespace '{namespace}'.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python create_config.py <namespace>")
        sys.exit(1)

    namespace = sys.argv[1]
    # Traverse through all files in current working directory
    files = []
    for root, dirs, filenames in os.walk('.'):
        for filename in filenames:
            if filename not in ['create_config.py', 'devworkspace.yaml']:  # Skip the script itself and devworkspace.yaml
                files.append(os.path.join(root, filename))
    
    for filepath in files:
        filename = os.path.basename(filepath)
        # Sanitize ConfigMap name: replace invalid chars and ensure it starts/ends with alphanumeric
        configmap_name = filename.replace('.', '-').replace('_', '-').lower()
        # Remove leading/trailing non-alphanumeric characters
        configmap_name = configmap_name.strip('-.')
        # Ensure it starts with alphanumeric if it doesn't
        if configmap_name and not configmap_name[0].isalnum():
            configmap_name = 'file-' + configmap_name
        # Ensure it ends with alphanumeric if it doesn't
        if configmap_name and not configmap_name[-1].isalnum():
            configmap_name = configmap_name + '-file'
        # If empty or still invalid, use a default name
        if not configmap_name or not configmap_name[0].isalnum():
            configmap_name = 'config-' + str(hash(filepath))[:8]
        create_configmap(namespace, configmap_name, [filepath])

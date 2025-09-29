# DevWorkspace V2 Examples and Use Cases

## Real-World Usage Examples

### Example 1: Java Developer Onboarding

**Scenario**: New Java developer needs a Spring Boot development environment

```bash
# Developer runs the command
./gok
> createDevWorkspaceV2

# Interactive session:
=== Create Che DevWorkspace ===
Enter username (user1): john.doe
Select workspace type:
1 => core-java
2 => springboot-web
3 => python-web
4 => springboot-backend
5 => tensorflow
6 => microservice-study
7 => javaparser
8 => nlp
9 => kubeauthentication
Enter workspace type index (1): 2

# Result: 
# - Namespace: john.doe
# - Workspace: spring
# - Type: springboot-web
# - URL: https://spring-john.doe.che.gokcloud.com
```

**What Gets Created**:
- DevWorkspace with Spring Boot template
- PVC with 2GB storage for Maven repository
- ConfigMaps for project files
- Ingress routes for web access and debugging
- Container with JDK 21, Maven, Spring Boot CLI

---

### Example 2: Data Science Team Setup

**Scenario**: Data science team needs TensorFlow environments

```bash
#!/bin/bash
# Batch setup script for data science team

team_members=("alice.data" "bob.analyst" "carol.ml")

for member in "${team_members[@]}"; do
    echo "Setting up workspace for $member..."
    
    # Use expect or heredoc to automate input
    cat <<EOF | createDevWorkspaceV2
$member
5
EOF
    
    echo "Workspace created for $member"
    sleep 30  # Allow time for workspace startup
done

echo "All data science workspaces ready!"
```

**Result**: Each team member gets:
- TensorFlow 2.x environment with GPU support
- Jupyter notebook server
- Pre-installed data science libraries (pandas, numpy, scipy)
- Shared data volume mounting
- 6GB memory allocation for large datasets

---

### Example 3: Microservices Development

**Scenario**: Developer working on multiple microservices

```bash
# Create different workspace types for different services

# API Gateway service (Spring Boot)
echo -e "dev.gateway\n2" | createDevWorkspaceV2

# User service (Java core)
echo -e "dev.userservice\n1" | createDevWorkspaceV2  

# Analytics service (Python)
echo -e "dev.analytics\n3" | createDevWorkspaceV2

# Study environment for architecture
echo -e "dev.architecture\n6" | createDevWorkspaceV2
```

**Benefits**:
- Isolated development environments per service
- Different runtime configurations per service type
- Independent scaling and resource allocation
- Service-specific tooling and dependencies

---

### Example 4: Educational Environment

**Scenario**: Computer science course with 50 students

```bash
#!/bin/bash
# Course setup script

course_code="cs401"
students_file="students.txt"  # Contains student IDs

while IFS= read -r student_id; do
    username="${course_code}-${student_id}"
    
    echo "Creating workspace for $username..."
    
    # Core Java for beginners
    echo -e "$username\n1" | createDevWorkspaceV2
    
    # Log creation
    echo "$(date): Created workspace for $student_id" >> course_setup.log
    
done < "$students_file"

echo "Course environments ready for $(wc -l < $students_file) students"
```

**Features**:
- Standardized development environment for all students
- Pre-configured with course materials
- Isolated namespaces prevent student interference
- Easy cleanup at course end

---

### Example 5: CI/CD Integration

**Scenario**: Automated testing in ephemeral environments

```yaml
# GitLab CI Pipeline
stages:
  - setup
  - test
  - cleanup

variables:
  WORKSPACE_USER: "ci-$CI_PIPELINE_ID"

setup-environment:
  stage: setup
  script:
    - source /opt/gok/gok
    - export CHE_USER_NAME="$WORKSPACE_USER"
    - echo -e "$WORKSPACE_USER\n2" | createDevWorkspaceV2
    - kubectl wait --for=condition=Ready devworkspace/spring -n "$WORKSPACE_USER" --timeout=600s
  artifacts:
    reports:
      dotenv: workspace.env
    paths:
      - workspace.env

run-tests:
  stage: test
  dependencies:
    - setup-environment
  script:
    - source workspace.env
    - kubectl exec -n "$WORKSPACE_USER" deployment/spring -- mvn test
    - kubectl exec -n "$WORKSPACE_USER" deployment/spring -- mvn integration-test

cleanup-environment:
  stage: cleanup
  when: always
  script:
    - source /opt/gok/gok
    - echo -e "$WORKSPACE_USER\n2" | deleteDevWorkspaceV2
```

---

### Example 6: Multi-Environment Development

**Scenario**: Developer needs different environments for different projects

```bash
#!/bin/bash
# Project-based workspace management script

create_project_workspace() {
    local project=$1
    local type_index=$2
    local description=$3
    
    echo "Creating $description workspace for project: $project"
    username="dev.$(whoami).${project}"
    
    echo -e "$username\n$type_index" | createDevWorkspaceV2
    
    # Store workspace info
    echo "$project,$username,$type_index,$(date)" >> ~/.workspaces.csv
}

# Create workspaces for different projects
create_project_workspace "web-frontend" 2 "Spring Boot web"
create_project_workspace "data-analysis" 5 "TensorFlow"
create_project_workspace "auth-service" 9 "Kubernetes authentication"
create_project_workspace "parser-tool" 7 "Java parser"

echo "All project workspaces created!"
echo "Track your workspaces in: ~/.workspaces.csv"
```

---

### Example 7: Temporary Development Environment

**Scenario**: Quick prototype development with auto-cleanup

```bash
#!/bin/bash
# Temporary workspace for prototyping

TEMP_USER="prototype-$(date +%s)"
WORKSPACE_TYPE="2"  # Spring Boot web

echo "Creating temporary workspace: $TEMP_USER"
echo -e "$TEMP_USER\n$WORKSPACE_TYPE" | createDevWorkspaceV2

# Wait for workspace to be ready
kubectl wait --for=condition=Ready devworkspace/spring -n "$TEMP_USER" --timeout=300s

# Get workspace URL
WORKSPACE_URL=$(kubectl get devworkspace spring -n "$TEMP_USER" -o jsonpath='{.status.mainUrl}')
echo "Workspace ready at: $WORKSPACE_URL"

# Auto-cleanup after 2 hours
(
    sleep 7200  # 2 hours
    echo "Auto-cleaning temporary workspace: $TEMP_USER"
    echo -e "$TEMP_USER\n$WORKSPACE_TYPE" | deleteDevWorkspaceV2
    echo "Temporary workspace cleaned up"
) &

echo "Workspace will auto-delete in 2 hours"
echo "To delete manually: echo -e '$TEMP_USER\\n$WORKSPACE_TYPE' | deleteDevWorkspaceV2"
```

---

## Advanced Use Cases

### Use Case 1: Multi-Tenant Development Platform

```bash
#!/bin/bash
# Enterprise multi-tenant setup

create_tenant_workspaces() {
    local tenant=$1
    local team_size=$2
    local workspace_type=$3
    
    echo "Setting up $team_size workspaces for tenant: $tenant"
    
    for i in $(seq 1 $team_size); do
        username="${tenant}-dev-$(printf "%02d" $i)"
        echo -e "$username\n$workspace_type" | createDevWorkspaceV2
        
        # Apply tenant-specific RBAC
        kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: $username
  name: $tenant-access
subjects:
- kind: User
  name: $tenant-admin
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: tenant-admin
  apiGroup: rbac.authorization.k8s.io
EOF
    done
}

# Create tenant environments
create_tenant_workspaces "acme-corp" 5 2      # 5 Spring Boot workspaces
create_tenant_workspaces "tech-startup" 3 1   # 3 Core Java workspaces
create_tenant_workspaces "data-company" 4 5   # 4 TensorFlow workspaces
```

### Use Case 2: Development Environment as Code

```yaml
# workspace-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: workspace-definitions
data:
  teams.json: |
    {
      "frontend-team": {
        "members": ["alice", "bob", "charlie"],
        "workspace_type": 2,
        "resources": {"memory": "4Gi", "cpu": "2"}
      },
      "backend-team": {
        "members": ["david", "eve", "frank"],
        "workspace_type": 4,
        "resources": {"memory": "6Gi", "cpu": "3"}
      },
      "data-team": {
        "members": ["grace", "henry"],
        "workspace_type": 5,
        "resources": {"memory": "8Gi", "cpu": "4"}
      }
    }
```

```bash
#!/bin/bash
# Deploy teams from configuration

kubectl apply -f workspace-config.yaml

# Parse configuration and create workspaces
kubectl get configmap workspace-definitions -o jsonpath='{.data.teams\.json}' | \
jq -r 'to_entries[] | "\(.key) \(.value.members | join(" ")) \(.value.workspace_type)"' | \
while read team members workspace_type; do
    echo "Setting up $team..."
    for member in $members; do
        username="${team}-${member}"
        echo -e "$username\n$workspace_type" | createDevWorkspaceV2
    done
done
```

### Use Case 3: Disaster Recovery Testing

```bash
#!/bin/bash
# Create backup workspace for disaster recovery testing

DR_ENV="dr-test-$(date +%Y%m%d)"

echo "Creating disaster recovery test environment: $DR_ENV"

# Create multiple workspace types for comprehensive testing
workspace_types=(1 2 3 4 5)
for type in "${workspace_types[@]}"; do
    username="${DR_ENV}-type${type}"
    echo -e "$username\n$type" | createDevWorkspaceV2
    
    # Simulate some work
    kubectl wait --for=condition=Ready devworkspace -n "$username" --timeout=300s
    
    # Create test data
    kubectl exec -n "$username" deployment/* -- bash -c "echo 'DR test data' > /projects/dr-test.txt"
done

echo "DR test environment ready. Test your backup/restore procedures."

# Cleanup function for later use
cleanup_dr_test() {
    for type in "${workspace_types[@]}"; do
        username="${DR_ENV}-type${type}"
        echo -e "$username\n$type" | deleteDevWorkspaceV2
    done
}
```

---

## Integration Examples

### Example 1: Slack Integration

```bash
#!/bin/bash
# Slack webhook integration for workspace notifications

SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

notify_slack() {
    local message=$1
    local color=$2
    
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"attachments\":[{\"color\":\"$color\",\"text\":\"$message\"}]}" \
        "$SLACK_WEBHOOK"
}

create_and_notify() {
    local username=$1
    local workspace_type=$2
    
    echo -e "$username\n$workspace_type" | createDevWorkspaceV2
    
    if [ $? -eq 0 ]; then
        notify_slack "✅ Workspace created for $username (type: $workspace_type)" "good"
    else
        notify_slack "❌ Failed to create workspace for $username" "danger"
    fi
}

# Usage
create_and_notify "new.developer" 2
```

### Example 2: Monitoring Integration

```bash
#!/bin/bash
# Prometheus metrics integration

METRICS_FILE="/var/lib/node_exporter/workspace_metrics.prom"

update_workspace_metrics() {
    # Count active workspaces by type
    for type in {1..9}; do
        count=$(kubectl get devworkspace -A -o json | \
                jq ".items | map(select(.metadata.labels.\"workspace-type\" == \"$type\")) | length")
        
        echo "workspace_count{type=\"$type\"} $count" >> "$METRICS_FILE.tmp"
    done
    
    # Total workspace count
    total=$(kubectl get devworkspace -A --no-headers | wc -l)
    echo "workspace_total $total" >> "$METRICS_FILE.tmp"
    
    # Atomic update
    mv "$METRICS_FILE.tmp" "$METRICS_FILE"
}

# Hook into workspace creation
original_createDevWorkspaceV2() {
    # Call original function
    createDevWorkspaceV2
    local result=$?
    
    # Update metrics
    update_workspace_metrics
    
    return $result
}

# Override the function
alias createDevWorkspaceV2=original_createDevWorkspaceV2
```

---

## Performance Optimization Examples

### Example 1: Resource-Aware Scheduling

```bash
#!/bin/bash
# Check cluster resources before creating workspace

check_resources() {
    local required_memory=$1
    local required_cpu=$2
    
    # Get available resources
    available_memory=$(kubectl top nodes --no-headers | awk '{sum+=$4} END {print sum}')
    available_cpu=$(kubectl top nodes --no-headers | awk '{sum+=$3} END {print sum}')
    
    if [ $available_memory -lt $required_memory ] || [ $available_cpu -lt $required_cpu ]; then
        echo "Insufficient resources. Available: ${available_memory}Mi memory, ${available_cpu}m CPU"
        return 1
    fi
    
    return 0
}

smart_create_workspace() {
    local username=$1
    local workspace_type=$2
    
    # Resource requirements by workspace type
    case $workspace_type in
        5) # TensorFlow
            if check_resources 6144 2000; then
                echo -e "$username\n$workspace_type" | createDevWorkspaceV2
            else
                echo "Insufficient resources for TensorFlow workspace"
                return 1
            fi
            ;;
        *) # Other types
            if check_resources 4096 1000; then
                echo -e "$username\n$workspace_type" | createDevWorkspaceV2
            else
                echo "Insufficient resources for workspace"
                return 1
            fi
            ;;
    esac
}
```

### Example 2: Load Balancing

```bash
#!/bin/bash
# Distribute workspaces across nodes for better performance

get_least_loaded_node() {
    kubectl top nodes --no-headers | \
    sort -k3,3n | \
    head -1 | \
    awk '{print $1}'
}

create_with_affinity() {
    local username=$1
    local workspace_type=$2
    
    # Get least loaded node
    target_node=$(get_least_loaded_node)
    
    # Set node affinity for workspace
    export NODE_AFFINITY="$target_node"
    
    echo -e "$username\n$workspace_type" | createDevWorkspaceV2
    
    unset NODE_AFFINITY
}

# Usage
create_with_affinity "balanced.user" 2
```

---

## Testing and Validation Examples

### Example 1: Automated Workspace Testing

```bash
#!/bin/bash
# Comprehensive workspace testing suite

test_workspace_creation() {
    local test_user="test-$(date +%s)"
    local workspace_type=$1
    
    echo "Testing workspace type $workspace_type..."
    
    # Create workspace
    timeout 600 bash -c "echo -e '$test_user\n$workspace_type' | createDevWorkspaceV2"
    
    if [ $? -eq 0 ]; then
        # Test workspace access
        kubectl wait --for=condition=Ready devworkspace -n "$test_user" --timeout=300s
        
        # Test application startup
        kubectl exec -n "$test_user" deployment/* -- ps aux | grep java
        
        # Cleanup
        echo -e "$test_user\n$workspace_type" | deleteDevWorkspaceV2
        
        echo "✅ Workspace type $workspace_type: PASS"
        return 0
    else
        echo "❌ Workspace type $workspace_type: FAIL"
        return 1
    fi
}

# Test all workspace types
for type in {1..9}; do
    test_workspace_creation $type
    sleep 30  # Cool down between tests
done
```

### Example 2: Load Testing

```bash
#!/bin/bash
# Load test workspace creation

CONCURRENT_USERS=10
TEST_DURATION=300  # 5 minutes

load_test() {
    local user_id=$1
    local start_time=$(date +%s)
    local end_time=$((start_time + TEST_DURATION))
    
    while [ $(date +%s) -lt $end_time ]; do
        test_user="load-test-${user_id}-$(date +%s)"
        
        # Random workspace type
        workspace_type=$((RANDOM % 9 + 1))
        
        echo -e "$test_user\n$workspace_type" | createDevWorkspaceV2 &>/dev/null
        
        # Keep workspace for 30 seconds
        sleep 30
        
        echo -e "$test_user\n$workspace_type" | deleteDevWorkspaceV2 &>/dev/null
        
        sleep 10  # Cool down
    done
}

# Start concurrent load test users
for i in $(seq 1 $CONCURRENT_USERS); do
    load_test $i &
done

wait
echo "Load test completed"
```

These examples demonstrate the versatility and power of the DevWorkspace V2 functions across various real-world scenarios, from simple development setups to complex enterprise deployments and automated testing environments.
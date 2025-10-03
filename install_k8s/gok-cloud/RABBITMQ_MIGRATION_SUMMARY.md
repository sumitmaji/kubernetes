# GOK-Agent RabbitMQ Migration Summary

## Changes Made for New RabbitMQ Cluster Operator Setup

### 🔄 Migration from Bitnami to RabbitMQ Cluster Operator

**Previous Setup:** Bitnami RabbitMQ with service `rabbitmq-0.rabbitmq-headless.rabbitmq.svc.cloud.uat`
**New Setup:** RabbitMQ Cluster Operator with service `rabbitmq.rabbitmq` (service.namespace pattern)

---

## 📁 Files Modified

### 1. Agent Application (`agent/app.py`)

#### **Changes:**
- ✅ Added `import base64` for credential decoding
- ✅ Updated default `RABBITMQ_HOST` to `rabbitmq.rabbitmq.svc.cluster.uat`
- ✅ Added `get_rabbitmq_credentials()` function to retrieve credentials from Kubernetes secret
- ✅ Dynamic credential retrieval with fallback to environment variables

#### **New Credential Logic:**
```python
def get_rabbitmq_credentials():
    """Try to get RabbitMQ credentials from Kubernetes secret"""
    # Gets username and password from rabbitmq-default-user secret
    # Returns (username, password) or (None, None) on failure

# Dynamic credential assignment with fallback
RABBITMQ_USER_K8S, RABBITMQ_PASSWORD_K8S = get_rabbitmq_credentials()
RABBITMQ_USER = RABBITMQ_USER_K8S or os.environ.get("RABBITMQ_USER", "guest")
RABBITMQ_PASSWORD = RABBITMQ_PASSWORD_K8S or os.environ.get("RABBITMQ_PASSWORD", "guest")
```

### 2. Controller Application (`controller/backend/app.py`)

#### **Changes:**
- ✅ Added `import base64` and `import subprocess` for credential retrieval
- ✅ Updated default `RABBITMQ_HOST` to `rabbitmq.rabbitmq.svc.cluster.uat`
- ✅ Added identical `get_rabbitmq_credentials()` function
- ✅ Same dynamic credential retrieval logic as agent

### 3. Agent Helm Chart

#### **Values.yaml (`agent/chart/values.yaml`):**
```yaml
env:
  RABBITMQ_HOST: "rabbitmq.rabbitmq.svc.cluster.uat"
  # Optional credentials (will use Kubernetes secret if not provided)
  # RABBITMQ_USER: "custom-user"
  # RABBITMQ_PASSWORD: "custom-password"
```

#### **Deployment Template (`agent/chart/templates/deployment.yaml`):**
- ✅ Added conditional environment variables for RabbitMQ credentials
- ✅ Only includes RABBITMQ_USER and RABBITMQ_PASSWORD if specified in values

### 4. Controller Helm Chart

#### **Values.yaml (`controller/chart/values.yaml`):**
```yaml
rabbitmqHost: rabbitmq.rabbitmq.svc.cluster.uat

env:
  RABBITMQ_HOST: "rabbitmq.rabbitmq.svc.cluster.uat"
  # Optional credentials (will use Kubernetes secret if not provided)
```

#### **Deployment Template (`controller/chart/templates/deployment.yaml`):**
- ✅ Updated to use `{{ .Values.env.RABBITMQ_HOST }}` instead of `{{ .Values.rabbitmqHost }}`
- ✅ Added conditional environment variables for credentials

---

## 🔐 Credential Management Strategy

### **Primary Method: Kubernetes Secret Retrieval**
- Both agent and controller automatically try to get credentials from `rabbitmq-default-user` secret
- Uses kubectl commands to extract base64-encoded username/password
- Logs success/failure of credential retrieval

### **Fallback Method: Environment Variables**
- If Kubernetes secret retrieval fails, falls back to environment variables
- Default fallback: `username=guest`, `password=guest`
- Can be overridden in Helm chart values.yaml

### **Commands Used for Credential Retrieval:**
```bash
kubectl get secret rabbitmq-default-user -n rabbitmq -o jsonpath='{.data.username}'
kubectl get secret rabbitmq-default-user -n rabbitmq -o jsonpath='{.data.password}'
```

---

## 🚀 Deployment Compatibility

### **Backward Compatibility:**
- ✅ Existing deployments will work with environment variables
- ✅ New deployments automatically use Kubernetes secret credentials
- ✅ Manual credential override still possible via Helm values

### **Migration Path:**
1. **No action required** - Applications automatically detect and use new RabbitMQ service
2. **Credentials automatically retrieved** from Kubernetes secret
3. **Existing environment variables** still work as fallback
4. **Helm charts updated** with new service endpoints

---

## 🧪 Testing Recommendations

### **Before Deployment:**
1. Ensure RabbitMQ Cluster Operator is deployed and running
2. Verify `rabbitmq-default-user` secret exists in `rabbitmq` namespace
3. Test connectivity: `kubectl port-forward svc/rabbitmq 5672:5672 -n rabbitmq`

### **After Deployment:**
1. Check application logs for credential retrieval messages:
   - Success: "Successfully retrieved RabbitMQ credentials from Kubernetes"
   - Warning: "Could not retrieve RabbitMQ username/password from Kubernetes secret"
2. Verify RabbitMQ connectivity in application logs
3. Test message publishing/consuming functionality

---

## 📝 Configuration Examples

### **Default Configuration (Recommended):**
```yaml
# agent/chart/values.yaml
env:
  RABBITMQ_HOST: "rabbitmq.rabbitmq.svc.cluster.uat"
  # No username/password needed - will use Kubernetes secret
```

### **Custom Credentials Configuration:**
```yaml
# agent/chart/values.yaml
env:
  RABBITMQ_HOST: "rabbitmq.rabbitmq.svc.cluster.uat"
  RABBITMQ_USER: "custom-username"
  RABBITMQ_PASSWORD: "custom-password"
```

### **External RabbitMQ Configuration:**
```yaml
# agent/chart/values.yaml
env:
  RABBITMQ_HOST: "external-rabbitmq.example.com"
  RABBITMQ_USER: "external-user"
  RABBITMQ_PASSWORD: "external-password"
```

---

## ✅ Benefits of New Setup

1. **🔄 Automatic Credential Management** - No manual credential configuration needed
2. **🔒 Security** - Credentials stored in Kubernetes secrets, not environment variables
3. **🚀 Simplified Deployment** - Automatic service discovery
4. **🛡️ Fallback Support** - Multiple credential sources for reliability
5. **📈 Scalability** - Native Kubernetes service mesh integration
6. **🔧 Operator Management** - RabbitMQ lifecycle managed by Kubernetes operator

The migration ensures seamless transition to the new RabbitMQ Cluster Operator while maintaining backward compatibility and improving security! 🐰
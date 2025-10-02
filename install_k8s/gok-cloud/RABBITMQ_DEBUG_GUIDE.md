# 🛠️ RabbitMQ Debugging Tool - User Guide

## Overview

The `debug_rabbitmq.sh` script is a comprehensive diagnostic tool that automates all the debugging commands we used to identify and resolve RabbitMQ connectivity issues in the GOK-Agent system.

## 📋 What This Script Does

### **Automated Diagnostics:**
1. **✅ RabbitMQ Service Status** - Checks pods, services, and IPs
2. **✅ Controller Status** - Verifies GOK-Agent controller pods and configuration  
3. **✅ DNS Resolution Tests** - Tests different hostname formats
4. **✅ Network Connectivity** - Validates TCP connections to RabbitMQ
5. **✅ Application Logs** - Examines recent logs for errors
6. **✅ Agent Status** - Optional check of agent pods
7. **✅ Configuration Recommendations** - Provides fix suggestions
8. **✅ Diagnostic Summary** - Complete results overview

---

## 🚀 Usage

### **Basic Usage:**
```bash
cd /path/to/gok-agent
./debug_rabbitmq.sh
```

### **Update Configuration Variables:**
Edit the script to match your environment:
```bash
# Configuration section in script
RABBITMQ_NAMESPACE="rabbitmq"           # RabbitMQ namespace
CONTROLLER_NAMESPACE="gok-controller"   # Controller namespace  
CONTROLLER_APP_LABEL="app=gok-controller"  # Controller pod selector
AGENT_NAMESPACE="skmaji1"               # Agent namespace
AGENT_APP_LABEL="app=agent-backend"    # Agent pod selector
```

---

## 📊 Script Output Sections

### **1. RabbitMQ Service Status**
```
Step 1: RabbitMQ Service Status
========================================
✅ RabbitMQ namespace 'rabbitmq' exists
RabbitMQ Pods Status:
NAME                  READY   STATUS    RESTARTS   AGE
rabbitmq-server-0     1/1     Running   0          60m

RabbitMQ Services:
NAME       TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)
rabbitmq   ClusterIP   10.111.60.136  <none>        5672/TCP,15672/TCP
```

### **2. Controller Status**
```
Step 2: Controller Status  
========================================
✅ Controller namespace 'gok-controller' exists
Controller Environment Variables (RabbitMQ related):
RABBITMQ_HOST=rabbitmq.rabbitmq
```

### **3. DNS Resolution Tests**
```
Step 3: DNS Resolution Tests
========================================
Test 1: Short DNS name (rabbitmq.rabbitmq)
✅ Success: rabbitmq.rabbitmq → 10.111.60.136

Test 2: Full FQDN (rabbitmq.rabbitmq.svc.cluster.local)  
❌ Failed: [Errno -2] Name or service not known

Test 3: Cluster.uat suffix (rabbitmq.rabbitmq.svc.cluster.uat)
❌ Failed: [Errno -2] Name or service not known
```

### **4. Network Connectivity Tests**
```
Step 4: Network Connectivity Tests
========================================
Test 1: Connection to rabbitmq.rabbitmq:5672
✅ Successfully connected to RabbitMQ!

Test 2: Connection to RabbitMQ service IP (10.111.60.136:5672)
✅ Successfully connected to RabbitMQ via IP!
```

### **5. Configuration Recommendations**
```
Step 7: Configuration Recommendations
========================================
✅ RECOMMENDED RabbitMQ Host Configuration:
   RABBITMQ_HOST: "rabbitmq.rabbitmq"

❌ AVOID these configurations if they're causing issues:
   ❌ RABBITMQ_HOST: "rabbitmq.rabbitmq.svc.cluster.local"
   ❌ RABBITMQ_HOST: "rabbitmq.rabbitmq.svc.cluster.uat"

🔧 To fix DNS issues in running deployments:
   kubectl patch deployment gok-controller -n gok-controller -p '...'
```

---

## 🎯 Common Issues & Solutions

### **Issue 1: DNS Resolution Failed**
**Symptoms:**
```
❌ Failed: [Errno -2] Name or service not known
ERROR Address resolution failed: gaierror(-2, 'Name or service not known')
```

**Solution:**
```bash
# Update to use short DNS name
kubectl patch deployment gok-controller -n gok-controller -p \
'{"spec":{"template":{"spec":{"containers":[{"name":"api","env":[{"name":"RABBITMQ_HOST","value":"rabbitmq.rabbitmq"}]}]}}}}'
```

### **Issue 2: Network Connectivity Failed**  
**Symptoms:**
```
❌ Connection failed: [Errno 111] Connection refused
```

**Solutions:**
1. Check if RabbitMQ pods are running
2. Verify service exists and has correct ports
3. Check firewall/network policies
4. Ensure RabbitMQ is listening on correct port

### **Issue 3: Controller Pod Not Found**
**Symptoms:**
```
❌ No controller pod found with label 'app=gok-controller'
```

**Solutions:**
1. Update `CONTROLLER_APP_LABEL` in script
2. Check if controller is deployed
3. Verify namespace is correct

---

## 📚 Commands Reference

### **Manual Commands Used in Script:**

#### **Check RabbitMQ Status:**
```bash
kubectl get pods,svc -n rabbitmq -o wide
kubectl get svc rabbitmq -n rabbitmq -o jsonpath='{.spec.clusterIP}'
```

#### **Check Controller:**
```bash
kubectl get pods -n gok-controller -l app=gok-controller -o wide
kubectl describe pod -n gok-controller <pod-name>
kubectl exec -n gok-controller <pod-name> -c api -- env | grep RABBITMQ
```

#### **DNS Resolution Tests:**
```bash
kubectl exec -n gok-controller <pod-name> -c api -- python3 -c \
  "import socket; print(socket.gethostbyname('rabbitmq.rabbitmq'))"
```

#### **Connectivity Tests:**
```bash
kubectl exec -n gok-controller <pod-name> -c api -- python3 -c \
  "import socket; s=socket.socket(); s.connect(('rabbitmq.rabbitmq', 5672))"
```

#### **Check Logs:**
```bash
kubectl logs -n gok-controller <pod-name> -c api --tail=20
kubectl logs -n gok-controller <pod-name> -c api | grep -i rabbitmq
```

#### **Update Configuration:**
```bash
kubectl patch deployment gok-controller -n gok-controller -p \
'{"spec":{"template":{"spec":{"containers":[{"name":"api","env":[{"name":"RABBITMQ_HOST","value":"rabbitmq.rabbitmq"}]}]}}}}'
```

---

## 🔧 Customization

### **For Different Environments:**
1. **Update namespaces** - Change `RABBITMQ_NAMESPACE`, `CONTROLLER_NAMESPACE`
2. **Update labels** - Modify `CONTROLLER_APP_LABEL`, `AGENT_APP_LABEL`
3. **Add custom tests** - Extend script with environment-specific checks
4. **Change RabbitMQ service** - Update service name if different

### **Adding New Tests:**
```bash
# Add custom connectivity test
print_section "Custom Test: My RabbitMQ Check"
if kubectl exec -n $CONTROLLER_NAMESPACE $CONTROLLER_POD -c api -- \
   your-custom-command; then
    print_success "Custom test: PASSED"
else
    print_error "Custom test: FAILED"
fi
```

---

## 📈 Interpreting Results

### **✅ Healthy System:**
- RabbitMQ pods running
- DNS resolves `rabbitmq.rabbitmq` 
- Network connectivity successful
- No errors in controller logs
- Correct environment variables

### **❌ Problematic System:**
- DNS resolution failures
- Connection timeouts/refused
- Error logs showing connectivity issues
- Wrong hostname configuration

---

## 💡 Pro Tips

1. **Run after any RabbitMQ changes** - Always test connectivity after updates
2. **Save output** - Redirect to file for troubleshooting: `./debug_rabbitmq.sh > debug.log 2>&1`
3. **Compare environments** - Run on working vs broken systems to identify differences
4. **Regular monitoring** - Include in CI/CD health checks
5. **Custom alerts** - Parse script output for automated monitoring

---

## 🐰 Future Enhancements

The script can be extended with:
- **Credential testing** - Verify RabbitMQ authentication
- **Performance tests** - Measure connection latency
- **Queue inspection** - Check message queues
- **Multi-environment** - Test across multiple clusters
- **Alert integration** - Send notifications on failures

This debugging tool encapsulates all the knowledge from our troubleshooting session and makes it reusable for future RabbitMQ connectivity issues! 🚀
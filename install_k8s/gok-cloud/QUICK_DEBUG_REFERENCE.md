# 🚀 RabbitMQ Quick Debug Commands

## Instant Diagnostics (Copy & Paste)

### **1. Check RabbitMQ Status**
```bash
kubectl get pods,svc -n rabbitmq -o wide
```

### **2. Get Controller Pod**  
```bash
CONTROLLER_POD=$(kubectl get pods -n gok-controller -l app=gok-controller -o jsonpath='{.items[0].metadata.name}')
echo "Controller Pod: $CONTROLLER_POD"
```

### **3. Test DNS Resolution**
```bash
kubectl exec -n gok-controller $CONTROLLER_POD -c api -- python3 -c \
  "import socket; print('DNS Test:', socket.gethostbyname('rabbitmq.rabbitmq'))"
```

### **4. Test Connectivity**
```bash
kubectl exec -n gok-controller $CONTROLLER_POD -c api -- python3 -c \
  "import socket; s=socket.socket(); s.settimeout(5); s.connect(('rabbitmq.rabbitmq', 5672)); print('✅ Connected!'); s.close()"
```

### **5. Check Environment**
```bash
kubectl exec -n gok-controller $CONTROLLER_POD -c api -- env | grep RABBITMQ_HOST
```

### **6. Check Recent Logs**
```bash
kubectl logs -n gok-controller $CONTROLLER_POD -c api --tail=20
```

### **7. Fix DNS Issues (if needed)**
```bash
kubectl patch deployment gok-controller -n gok-controller -p \
'{"spec":{"template":{"spec":{"containers":[{"name":"api","env":[{"name":"RABBITMQ_HOST","value":"rabbitmq.rabbitmq"}]}]}}}}'
```

## **🛠️ Full Diagnostic Script**
```bash
./debug_rabbitmq.sh
```

## **💡 Expected Working Configuration**
- **DNS Name**: `rabbitmq.rabbitmq` ✅
- **Service IP**: Resolves to cluster IP
- **Port**: 5672 accessible  
- **Logs**: No DNS/connection errors
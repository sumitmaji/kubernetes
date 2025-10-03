# RabbitMQ Test Script - Quick Reference

## Files in this directory:
- `test_rabbitmq.sh` - Complete RabbitMQ test automation script
- `rabbitmq_test.py` - Python test program for RabbitMQ messaging
- `README.md` - This reference file

## 🔐 RabbitMQ Credentials Flow

### How Credentials Are Obtained:
The credentials are retrieved from **Kubernetes secrets** using the `get_rabbitmq_credentials()` function in `rabbitmq_test.py`:

```python
def get_rabbitmq_credentials():
    # Get username from Kubernetes secret
    result = subprocess.run([
        'kubectl', 'get', 'secret', 'rabbitmq-default-user', 
        '-n', 'rabbitmq', '-o', 'jsonpath={.data.username}'
    ], capture_output=True, text=True)
    
    username = base64.b64decode(result.stdout).decode()
    
    # Get password from Kubernetes secret
    result = subprocess.run([
        'kubectl', 'get', 'secret', 'rabbitmq-default-user', 
        '-n', 'rabbitmq', '-o', 'jsonpath={.data.password}'
    ], capture_output=True, text=True)
    
    password = base64.b64decode(result.stdout).decode()
    return username, password
```

### Where Credentials Come From:
The **RabbitMQ Cluster Operator** automatically creates a Kubernetes secret called `rabbitmq-default-user` in the `rabbitmq` namespace when it sets up the RabbitMQ cluster. This secret contains:

- **Username**: Base64-encoded default username
- **Password**: Base64-encoded randomly generated password

### How Credentials Are Passed:
```python
def main():
    # Step 1: Get credentials from Kubernetes
    username, password = get_rabbitmq_credentials()
    
    # Step 2: Create config with credentials or fallback
    config = {
        'host': 'localhost',
        'port': 5672,
        'username': username or 'guest',  # Use retrieved username or fallback
        'password': password or 'guest'   # Use retrieved password or fallback
    }
    
    # Step 3: Pass to RabbitMQ connection
    tester = RabbitMQTester(**config)
```

### Where Credentials Are Used:
In the `RabbitMQTester` class constructor:
```python
def __init__(self, host='localhost', port=5672, username='user', password='password'):
    self.credentials = pika.PlainCredentials(username, password)
    self.connection_params = pika.ConnectionParameters(
        host=self.host,
        port=self.port,
        credentials=self.credentials  # Used here for RabbitMQ connection
    )
```

### Manual Credential Verification:
You can manually check these credentials by running:
```bash
# Get username
kubectl get secret rabbitmq-default-user -n rabbitmq -o jsonpath='{.data.username}' | base64 --decode

# Get password
kubectl get secret rabbitmq-default-user -n rabbitmq -o jsonpath='{.data.password}' | base64 --decode

# View the entire secret
kubectl get secret rabbitmq-default-user -n rabbitmq -o yaml
```

### Fallback Logic:
If the script cannot retrieve credentials from Kubernetes:
- **Falls back to**: `username='guest'`, `password='guest'`
- **Shows warning**: "Using default credentials (guest/guest)"

When you see "✅ Retrieved credentials from Kubernetes" in successful test runs, it means the script successfully got the real RabbitMQ credentials from the Kubernetes secret created by the RabbitMQ Cluster Operator!

## Usage:

### Quick Test:
```bash
./test_rabbitmq.sh
```

### What the script does:
1. ✅ Checks Python dependencies
2. ✅ Handles externally-managed Python environments
3. ✅ Installs pika via multiple methods:
   - apt install python3-pika
   - pip3 install --break-system-packages pika
   - Virtual environment as fallback
4. ✅ Validates Kubernetes cluster connectivity
5. ✅ Checks RabbitMQ pod and service health
6. ✅ Sets up port-forwarding automatically
7. ✅ Runs comprehensive messaging tests
8. ✅ Cleans up resources automatically

### Externally-Managed Environment Support:
The script automatically handles the "externally-managed-environment" error by trying:
1. **APT installation** - `sudo apt install python3-pika`
2. **Pip with flags** - `pip3 install --break-system-packages pika`
3. **Virtual environment** - Creates isolated Python environment

### Manual Installation (if script fails):
```bash
# Option 1: System package
sudo apt install python3-pika

# Option 2: Pip with override
pip3 install --break-system-packages pika

# Option 3: Virtual environment
python3 -m venv rabbitmq_venv
source rabbitmq_venv/bin/activate
pip install pika
```

### Test Output:
- Creates topic exchange with routing patterns
- Publishes 5 test messages with different routing keys
- Consumes messages in real-time
- Verifies topic exchange routing functionality
- Shows connection status and message flow

### Troubleshooting:
- **Connection refused**: Check if port-forwarding is active
- **Authentication failed**: Verify RabbitMQ credentials
- **Pod not running**: Check RabbitMQ deployment status
- **Import errors**: Ensure pika is installed correctly

### Files Created During Test:
- `rabbitmq_test_venv/` - Virtual environment (if created)
- Port-forwarding process (cleaned up automatically)

## Examples:

### Successful Test Output:
```
🐰 RabbitMQ Topic Exchange Test
========================================
✅ Retrieved credentials from Kubernetes
✅ RabbitMQ connection successful
✅ Created exchange 'test_topic_exchange' (topic)
✅ Created queue 'test_queue'
✅ Bound queue with routing key 'test.messages.*'

📤 Published: 'Hello RabbitMQ! (1)' with routing key 'test.messages.info'
📥 Received: 'Hello RabbitMQ! (1)' (routing: test.messages.info)
...
✅ RabbitMQ test completed!
   Published: 5 messages
   Topic exchange and routing working correctly
```
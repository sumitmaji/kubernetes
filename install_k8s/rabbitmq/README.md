# RabbitMQ Test Script - Quick Reference

## Files in this directory:
- `test_rabbitmq.sh` - Complete RabbitMQ test automation script
- `rabbitmq_test.py` - Python test program for RabbitMQ messaging
- `README.md` - This reference file

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
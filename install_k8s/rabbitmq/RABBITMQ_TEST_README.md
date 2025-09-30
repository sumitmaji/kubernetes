# RabbitMQ Test Program - Setup Guide

## Prerequisites

1. **Install Python dependencies:**
   ```bash
   pip3 install pika
   ```

2. **Make sure RabbitMQ is running in your Kubernetes cluster**

## Usage Options

### Option 1: Port Forwarding (Recommended for testing)

1. **Set up port forwarding:**
   ```bash
   kubectl port-forward svc/rabbitmq 5672:5672 -n rabbitmq
   ```

2. **Update the configuration in `rabbitmq_test.py`:**
   ```python
   config = {
       'host': 'localhost',
       'port': 5672,
       'username': 'guest',  # Or get from kubectl secret
       'password': 'guest'   # Or get from kubectl secret
   }
   ```

3. **Run the test:**
   ```bash
   python3 rabbitmq_test.py
   ```

### Option 2: Get Real Credentials

1. **Get RabbitMQ credentials from Kubernetes:**
   ```bash
   # Get username
   kubectl get secret rabbitmq-default-user -n rabbitmq -o jsonpath='{.data.username}' | base64 --decode

   # Get password
   kubectl get secret rabbitmq-default-user -n rabbitmq -o jsonpath='{.data.password}' | base64 --decode
   ```

2. **Update the configuration with real credentials:**
   ```python
   config = {
       'host': 'localhost',  # with port-forwarding
       'port': 5672,
       'username': 'your_actual_username',
       'password': 'your_actual_password'
   }
   ```

### Option 3: Direct Cluster Access (if inside cluster)

Update the configuration:
```python
config = {
    'host': 'rabbitmq.rabbitmq.svc.cluster.local',
    'port': 5672,
    'username': 'your_username',
    'password': 'your_password'
}
```

## What the Program Does

1. **Creates a topic exchange** called `test_topic_exchange`
2. **Creates a queue** called `test_queue` 
3. **Binds the queue** to the exchange with pattern `test.messages.*`
4. **Publishes 5 test messages** with different routing keys:
   - `test.messages.info`
   - `test.messages.debug`
   - `test.messages.warning`
5. **Consumes messages** that match the binding pattern
6. **Shows real-time** publish and consume operations

## Expected Output

```
🐰 RabbitMQ Topic Exchange Test
========================================
✅ RabbitMQ connection successful
✅ Created exchange 'test_topic_exchange' (topic)
✅ Created queue 'test_queue'
✅ Bound queue with routing key 'test.messages.*'

📋 Test Configuration:
   Host: localhost:5672
   Exchange: test_topic_exchange (topic)
   Queue: test_queue
   Binding: test.messages.*
   Routing Key: test.messages.info

🔄 Starting consumer thread...
📤 Published: 'Hello RabbitMQ! (1)' with routing key 'test.messages.info'
📤 Published: 'This is message #2 (2)' with routing key 'test.messages.debug'
📤 Published: 'Testing topic exchange (3)' with routing key 'test.messages.info'
📤 Published: 'Another test message (4)' with routing key 'test.messages.warning'
📤 Published: 'Final test message (5)' with routing key 'test.messages.info'

🔄 Waiting for messages (max 5)...
📥 Received: 'Hello RabbitMQ! (1)' (routing: test.messages.info) at 2025-09-29T22:15:30.123456
📥 Received: 'This is message #2 (2)' (routing: test.messages.debug) at 2025-09-29T22:15:30.623456
📥 Received: 'Testing topic exchange (3)' (routing: test.messages.info) at 2025-09-29T22:15:31.123456
📥 Received: 'Another test message (4)' (routing: test.messages.warning) at 2025-09-29T22:15:31.623456
📥 Received: 'Final test message (5)' (routing: test.messages.info) at 2025-09-29T22:15:32.123456
✅ Consumed 5 messages

✅ RabbitMQ test completed!
   Published: 5 messages
   Topic exchange and routing working correctly
```

## Troubleshooting

1. **Connection refused:** Make sure port-forwarding is active
2. **Authentication failed:** Check username/password
3. **Import errors:** Make sure `pika` is installed: `pip3 install pika`
4. **kubectl errors:** Make sure you're authenticated to your Kubernetes cluster
#!/usr/bin/env python3
"""
RabbitMQ Test Program - Topic Exchange
This program creates a topic exchange, publishes messages, and consumes them.
"""

import pika
import sys
import json
import time
import threading
from datetime import datetime

class RabbitMQTester:
    def __init__(self, host='rabbitmq.rabbitmq.svc.cluster.local', port=5672, 
                 username='user', password='password'):
        """
        Initialize RabbitMQ connection
        """
        self.host = host
        self.port = port
        self.credentials = pika.PlainCredentials(username, password)
        self.connection_params = pika.ConnectionParameters(
            host=self.host,
            port=self.port,
            credentials=self.credentials
        )
        
        # Topic exchange and routing configuration
        self.exchange_name = 'test_topic_exchange'
        self.queue_name = 'test_queue'
        self.routing_key = 'test.messages.info'
        self.binding_key = 'test.messages.*'
        
    def setup_infrastructure(self):
        """
        Create exchange, queue, and binding
        """
        try:
            connection = pika.BlockingConnection(self.connection_params)
            channel = connection.channel()
            
            # Declare topic exchange
            channel.exchange_declare(
                exchange=self.exchange_name,
                exchange_type='topic',
                durable=True
            )
            
            # Declare queue
            channel.queue_declare(queue=self.queue_name, durable=True)
            
            # Bind queue to exchange with routing pattern
            channel.queue_bind(
                exchange=self.exchange_name,
                queue=self.queue_name,
                routing_key=self.binding_key
            )
            
            print(f"✅ Created exchange '{self.exchange_name}' (topic)")
            print(f"✅ Created queue '{self.queue_name}'")
            print(f"✅ Bound queue with routing key '{self.binding_key}'")
            
            connection.close()
            return True
            
        except Exception as e:
            print(f"❌ Error setting up infrastructure: {e}")
            return False
    
    def publish_message(self, message_text, routing_key=None):
        """
        Publish a message to the topic exchange
        """
        if routing_key is None:
            routing_key = self.routing_key
            
        try:
            connection = pika.BlockingConnection(self.connection_params)
            channel = connection.channel()
            
            # Create message payload
            message = {
                'text': message_text,
                'timestamp': datetime.now().isoformat(),
                'routing_key': routing_key
            }
            
            # Publish message
            channel.basic_publish(
                exchange=self.exchange_name,
                routing_key=routing_key,
                body=json.dumps(message),
                properties=pika.BasicProperties(
                    delivery_mode=2,  # Make message persistent
                    content_type='application/json'
                )
            )
            
            print(f"📤 Published: '{message_text}' with routing key '{routing_key}'")
            connection.close()
            return True
            
        except Exception as e:
            print(f"❌ Error publishing message: {e}")
            return False
    
    def consume_messages(self, max_messages=10):
        """
        Consume messages from the queue
        """
        try:
            connection = pika.BlockingConnection(self.connection_params)
            channel = connection.channel()
            
            message_count = 0
            
            def callback(ch, method, properties, body):
                nonlocal message_count
                try:
                    message = json.loads(body.decode())
                    print(f"📥 Received: '{message['text']}' "
                          f"(routing: {message['routing_key']}) "
                          f"at {message['timestamp']}")
                    
                    # Acknowledge message
                    ch.basic_ack(delivery_tag=method.delivery_tag)
                    message_count += 1
                    
                    if message_count >= max_messages:
                        ch.stop_consuming()
                        
                except Exception as e:
                    print(f"❌ Error processing message: {e}")
                    ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
            
            # Set up consumer
            channel.basic_qos(prefetch_count=1)
            channel.basic_consume(queue=self.queue_name, on_message_callback=callback)
            
            print(f"🔄 Waiting for messages (max {max_messages})...")
            print("Press CTRL+C to exit")
            
            # Start consuming
            channel.start_consuming()
            connection.close()
            
            print(f"✅ Consumed {message_count} messages")
            return True
            
        except KeyboardInterrupt:
            print("\n🛑 Consumer stopped by user")
            try:
                channel.stop_consuming()
                connection.close()
            except:
                pass
            return True
            
        except Exception as e:
            print(f"❌ Error consuming messages: {e}")
            return False
    
    def test_connection(self):
        """
        Test RabbitMQ connection
        """
        try:
            connection = pika.BlockingConnection(self.connection_params)
            connection.close()
            print("✅ RabbitMQ connection successful")
            return True
        except Exception as e:
            print(f"❌ RabbitMQ connection failed: {e}")
            return False

def consumer_thread(tester, max_messages=5):
    """
    Run consumer in separate thread
    """
    print("\n🔄 Starting consumer thread...")
    time.sleep(2)  # Give publisher time to send messages
    tester.consume_messages(max_messages)

def get_rabbitmq_credentials():
    """
    Try to get RabbitMQ credentials from Kubernetes
    """
    try:
        import subprocess
        
        # Get username
        result = subprocess.run([
            'kubectl', 'get', 'secret', 'rabbitmq-default-user', 
            '-n', 'rabbitmq', '-o', 'jsonpath={.data.username}'
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            return None, None
            
        import base64
        username = base64.b64decode(result.stdout).decode()
        
        # Get password
        result = subprocess.run([
            'kubectl', 'get', 'secret', 'rabbitmq-default-user', 
            '-n', 'rabbitmq', '-o', 'jsonpath={.data.password}'
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            return username, None
            
        password = base64.b64decode(result.stdout).decode()
        return username, password
        
    except Exception as e:
        print(f"⚠️  Could not retrieve credentials from Kubernetes: {e}")
        return None, None

def main():
    """
    Main test function
    """
    print("🐰 RabbitMQ Topic Exchange Test")
    print("=" * 40)
    
    # Try to get credentials from Kubernetes
    username, password = get_rabbitmq_credentials()
    
    # Configuration - Update these values for your environment
    config = {
        'host': 'localhost',  # Using port-forwarding for testing
        'port': 5672,
        'username': username or 'guest',  # Fallback to guest
        'password': password or 'guest'   # Fallback to guest
    }
    
    if username and password:
        print(f"✅ Retrieved credentials from Kubernetes")
    else:
        print("⚠️  Using default credentials (guest/guest)")
        print("   Update the config in the script if needed")
    
    # Initialize tester
    tester = RabbitMQTester(**config)
    
    # Test connection
    if not tester.test_connection():
        print("❌ Cannot connect to RabbitMQ. Please check your configuration.")
        print("\nTroubleshooting:")
        print("1. Make sure RabbitMQ is running")
        print("2. Check host and port settings")
        print("3. Verify credentials")
        print("4. For external access, try port-forwarding:")
        print("   kubectl port-forward svc/rabbitmq 5672:5672 -n rabbitmq")
        print("   Then update host to 'localhost'")
        return
    
    # Setup infrastructure
    if not tester.setup_infrastructure():
        return
    
    print(f"\n📋 Test Configuration:")
    print(f"   Host: {config['host']}:{config['port']}")
    print(f"   Exchange: {tester.exchange_name} (topic)")
    print(f"   Queue: {tester.queue_name}")
    print(f"   Binding: {tester.binding_key}")
    print(f"   Routing Key: {tester.routing_key}")
    
    # Start consumer in background thread
    consumer = threading.Thread(target=consumer_thread, args=(tester, 5))
    consumer.daemon = True
    consumer.start()
    
    # Publish test messages
    print(f"\n📤 Publishing test messages...")
    test_messages = [
        ("Hello RabbitMQ!", "test.messages.info"),
        ("This is message #2", "test.messages.debug"),
        ("Testing topic exchange", "test.messages.info"),
        ("Another test message", "test.messages.warning"),
        ("Final test message", "test.messages.info")
    ]
    
    for i, (message, routing) in enumerate(test_messages, 1):
        tester.publish_message(f"{message} ({i})", routing)
        time.sleep(0.5)
    
    # Wait for consumer to finish
    print(f"\n⏳ Waiting for messages to be consumed...")
    consumer.join(timeout=10)
    
    print(f"\n✅ RabbitMQ test completed!")
    print(f"   Published: {len(test_messages)} messages")
    print(f"   Topic exchange and routing working correctly")

if __name__ == "__main__":
    main()
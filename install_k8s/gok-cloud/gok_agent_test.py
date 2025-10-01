#!/usr/bin/env python3
"""
End-to-End GOK-Agent Command Test
This script tests the complete workflow:
1. Agent publishes a command to RabbitMQ
2. Controller receives and executes the command
3. Controller publishes results back to RabbitMQ
4. Agent receives and displays the results
"""

import os
import sys
import json
import time
import uuid
import threading
import logging
import signal
from datetime import datetime
from typing import Dict, List, Optional, Any

# Add the agent directory to Python path for vault_credentials
import os
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(CURRENT_DIR, 'agent'))

try:
    import pika
    from vault_credentials import get_rabbitmq_credentials
    PIKA_AVAILABLE = True
except ImportError as e:
    print(f"Error: Required dependencies not available: {e}")
    print("Please install: pip install pika")
    PIKA_AVAILABLE = False
    sys.exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('gok-test')

class TestAgent:
    """Test agent that publishes commands and receives results"""
    
    def __init__(self):
        self.connection = None
        self.channel = None
        self.results = {}
        self.running = False
        self.result_thread = None
        
    def connect(self):
        """Connect to RabbitMQ using Vault credentials"""
        logger.info("Connecting to RabbitMQ...")
        
        # Get credentials from Vault
        credentials = get_rabbitmq_credentials(prefer_vault=True)
        if not credentials:
            raise Exception("Failed to get RabbitMQ credentials")
        
        logger.info(f"Using RabbitMQ host: {credentials.host}:{credentials.port}")
        logger.info(f"Using username: {credentials.username}")
        
        # Create connection
        connection_params = pika.ConnectionParameters(
            host=credentials.host,
            port=credentials.port,
            virtual_host=credentials.virtual_host,
            credentials=pika.PlainCredentials(credentials.username, credentials.password),
            heartbeat=600,
            blocked_connection_timeout=300
        )
        
        self.connection = pika.BlockingConnection(connection_params)
        self.channel = self.connection.channel()
        
        # Declare queues
        self.channel.queue_declare(queue='commands', durable=True)
        self.channel.queue_declare(queue='results', durable=True)
        
        logger.info("Successfully connected to RabbitMQ")
    
    def disconnect(self):
        """Disconnect from RabbitMQ"""
        self.running = False
        if self.result_thread:
            self.result_thread.join(timeout=5)
        
        if self.connection and not self.connection.is_closed:
            self.connection.close()
            logger.info("Disconnected from RabbitMQ")
    
    def start_result_consumer(self):
        """Start consuming results in a separate thread"""
        def consume_results():
            """Consumer function for results queue"""
            try:
                # Create a separate connection for consuming
                credentials = get_rabbitmq_credentials(prefer_vault=True)
                connection_params = pika.ConnectionParameters(
                    host=credentials.host,
                    port=credentials.port,
                    virtual_host=credentials.virtual_host,
                    credentials=pika.PlainCredentials(credentials.username, credentials.password)
                )
                
                connection = pika.BlockingConnection(connection_params)
                channel = connection.channel()
                channel.queue_declare(queue='results', durable=True)
                
                def on_result_received(ch, method, properties, body):
                    """Handle received result message"""
                    try:
                        message = json.loads(body.decode('utf-8'))
                        batch_id = message.get('batch_id')
                        
                        logger.info(f"Received result for batch: {batch_id}")
                        
                        if batch_id:
                            self.results[batch_id] = message
                        
                        ch.basic_ack(delivery_tag=method.delivery_tag)
                        
                    except Exception as e:
                        logger.error(f"Error processing result: {e}")
                        ch.basic_ack(delivery_tag=method.delivery_tag)
                
                channel.basic_consume(queue='results', on_message_callback=on_result_received)
                
                logger.info("Started result consumer thread")
                
                # Consume messages while running
                while self.running:
                    try:
                        connection.process_data_events(time_limit=1.0)
                    except Exception as e:
                        logger.error(f"Error in result consumer: {e}")
                        break
                
                connection.close()
                logger.info("Result consumer thread stopped")
                
            except Exception as e:
                logger.error(f"Failed to start result consumer: {e}")
        
        self.running = True
        self.result_thread = threading.Thread(target=consume_results, daemon=True)
        self.result_thread.start()
    
    def publish_command(self, commands: List[str], user_info: Dict = None) -> str:
        """Publish a command batch to RabbitMQ"""
        if not user_info:
            user_info = {
                "sub": "test-user",
                "name": "Test User", 
                "groups": ["administrators"],
                "id_token": "test-token"
            }
        
        # Create batch ID
        batch_id = f"test-{user_info['sub']}-{int(time.time())}-{uuid.uuid4().hex[:8]}"
        
        # Create message
        message = {
            "commands": [{"command": cmd, "command_id": i} for i, cmd in enumerate(commands)],
            "user_info": user_info,
            "batch_id": batch_id
        }
        
        # Publish to commands queue
        self.channel.basic_publish(
            exchange='',
            routing_key='commands',
            body=json.dumps(message),
            properties=pika.BasicProperties(
                delivery_mode=2,  # Make message persistent
                timestamp=int(time.time())
            )
        )
        
        logger.info(f"Published command batch {batch_id}: {commands}")
        return batch_id
    
    def wait_for_result(self, batch_id: str, timeout: int = 30) -> Optional[Dict]:
        """Wait for result of a specific batch"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            if batch_id in self.results:
                return self.results[batch_id]
            time.sleep(0.5)
        
        return None


class TestController:
    """Test controller that simulates the GOK-Agent controller behavior"""
    
    def __init__(self):
        self.connection = None
        self.channel = None
        self.running = False
    
    def connect(self):
        """Connect to RabbitMQ"""
        logger.info("Controller connecting to RabbitMQ...")
        
        credentials = get_rabbitmq_credentials(prefer_vault=True)
        if not credentials:
            raise Exception("Failed to get RabbitMQ credentials")
        
        connection_params = pika.ConnectionParameters(
            host=credentials.host,
            port=credentials.port,
            virtual_host=credentials.virtual_host,
            credentials=pika.PlainCredentials(credentials.username, credentials.password)
        )
        
        self.connection = pika.BlockingConnection(connection_params)
        self.channel = self.connection.channel()
        
        # Declare queues
        self.channel.queue_declare(queue='commands', durable=True)
        self.channel.queue_declare(queue='results', durable=True)
        
        logger.info("Controller connected to RabbitMQ")
    
    def disconnect(self):
        """Disconnect from RabbitMQ"""
        self.running = False
        if self.connection and not self.connection.is_closed:
            self.connection.close()
            logger.info("Controller disconnected from RabbitMQ")
    
    def process_commands(self, duration: int = 60):
        """Process commands for a specified duration"""
        def on_command_received(ch, method, properties, body):
            """Handle received command message"""
            try:
                message = json.loads(body.decode('utf-8'))
                batch_id = message.get('batch_id')
                commands = message.get('commands', [])
                user_info = message.get('user_info', {})
                
                logger.info(f"Controller received batch {batch_id} with {len(commands)} commands")
                
                # Process each command
                results = []
                for cmd_info in commands:
                    command = cmd_info.get('command', '')
                    command_id = cmd_info.get('command_id', 0)
                    
                    # Simulate command execution
                    result = self.execute_command(command)
                    
                    results.append({
                        'command_id': command_id,
                        'command': command,
                        'stdout': result.get('stdout', ''),
                        'stderr': result.get('stderr', ''),
                        'return_code': result.get('return_code', 0),
                        'execution_time': result.get('execution_time', 0.0)
                    })
                
                # Send result back
                result_message = {
                    'batch_id': batch_id,
                    'user_info': user_info,
                    'results': results,
                    'processed_at': datetime.now().isoformat()
                }
                
                ch.basic_publish(
                    exchange='',
                    routing_key='results',
                    body=json.dumps(result_message),
                    properties=pika.BasicProperties(delivery_mode=2)
                )
                
                logger.info(f"Controller sent results for batch {batch_id}")
                
                ch.basic_ack(delivery_tag=method.delivery_tag)
                
            except Exception as e:
                logger.error(f"Controller error processing command: {e}")
                ch.basic_ack(delivery_tag=method.delivery_tag)
        
        # Set up consumer
        self.channel.basic_qos(prefetch_count=1)
        self.channel.basic_consume(queue='commands', on_message_callback=on_command_received)
        
        logger.info(f"Controller started processing commands for {duration} seconds...")
        
        # Process commands for specified duration
        self.running = True
        start_time = time.time()
        
        while self.running and (time.time() - start_time) < duration:
            try:
                self.connection.process_data_events(time_limit=1.0)
            except Exception as e:
                logger.error(f"Controller processing error: {e}")
                break
        
        logger.info("Controller stopped processing commands")
    
    def execute_command(self, command: str) -> Dict:
        """Execute a command and return results (simulated)"""
        start_time = time.time()
        
        try:
            # Simulate different commands
            if command == "whoami":
                return {
                    'stdout': 'gok-test-user',
                    'stderr': '',
                    'return_code': 0,
                    'execution_time': time.time() - start_time
                }
            elif command == "uptime":
                return {
                    'stdout': 'up 1 day, 2:30, load average: 0.1, 0.2, 0.1',
                    'stderr': '',
                    'return_code': 0,
                    'execution_time': time.time() - start_time
                }
            elif command.startswith("echo"):
                text = command[5:].strip() if len(command) > 5 else ""
                return {
                    'stdout': text,
                    'stderr': '',
                    'return_code': 0,
                    'execution_time': time.time() - start_time
                }
            elif command == "date":
                return {
                    'stdout': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                    'stderr': '',
                    'return_code': 0,
                    'execution_time': time.time() - start_time
                }
            elif command == "ls":
                return {
                    'stdout': 'file1.txt\nfile2.txt\ndirectory1\n',
                    'stderr': '',
                    'return_code': 0,
                    'execution_time': time.time() - start_time
                }
            else:
                # Unknown command
                return {
                    'stdout': '',
                    'stderr': f'command not found: {command}',
                    'return_code': 127,
                    'execution_time': time.time() - start_time
                }
                
        except Exception as e:
            return {
                'stdout': '',
                'stderr': f'execution error: {str(e)}',
                'return_code': 1,
                'execution_time': time.time() - start_time
            }


def run_end_to_end_test():
    """Run complete end-to-end test"""
    print("=" * 80)
    print("GOK-AGENT END-TO-END COMMAND EXECUTION TEST")
    print("=" * 80)
    
    agent = TestAgent()
    controller = TestController()
    
    try:
        # Connect both components
        print("\n1. Connecting to RabbitMQ...")
        agent.connect()
        controller.connect()
        
        # Start result consumer
        print("\n2. Starting result consumer...")
        agent.start_result_consumer()
        
        # Start controller in background
        print("\n3. Starting controller...")
        controller_thread = threading.Thread(
            target=controller.process_commands, 
            args=(120,), 
            daemon=True
        )
        controller_thread.start()
        
        # Wait a moment for controller to be ready
        time.sleep(2)
        
        # Test cases
        test_cases = [
            {
                'name': 'Simple whoami command',
                'commands': ['whoami'],
                'expected_return_codes': [0]
            },
            {
                'name': 'Multiple basic commands',
                'commands': ['whoami', 'uptime', 'date'],
                'expected_return_codes': [0, 0, 0]
            },
            {
                'name': 'Echo command with text',
                'commands': ['echo "Hello from GOK-Agent test!"'],
                'expected_return_codes': [0]
            },
            {
                'name': 'List directory command',
                'commands': ['ls'],
                'expected_return_codes': [0]
            },
            {
                'name': 'Invalid command (should fail)',
                'commands': ['invalidcommandthatdoesnotexist'],
                'expected_return_codes': [127]
            },
            {
                'name': 'Mixed valid and invalid commands',
                'commands': ['whoami', 'invalidcommand', 'date'],
                'expected_return_codes': [0, 127, 0]
            }
        ]
        
        print(f"\n4. Running {len(test_cases)} test cases...")
        
        passed = 0
        failed = 0
        
        for i, test_case in enumerate(test_cases, 1):
            print(f"\n   Test {i}: {test_case['name']}")
            print(f"   Commands: {test_case['commands']}")
            
            # Publish command
            batch_id = agent.publish_command(test_case['commands'])
            
            # Wait for result
            print(f"   Waiting for results (batch: {batch_id})...")
            result = agent.wait_for_result(batch_id, timeout=30)
            
            if result:
                results = result.get('results', [])
                print(f"   ✓ Received {len(results)} results")
                
                # Verify results
                test_passed = True
                for j, cmd_result in enumerate(results):
                    expected_code = test_case['expected_return_codes'][j] if j < len(test_case['expected_return_codes']) else 0
                    actual_code = cmd_result.get('return_code', -1)
                    
                    if actual_code == expected_code:
                        print(f"     Command {j}: ✓ (exit code: {actual_code})")
                    else:
                        print(f"     Command {j}: ✗ (expected: {expected_code}, got: {actual_code})")
                        test_passed = False
                    
                    # Show output for informational purposes
                    stdout = cmd_result.get('stdout', '').strip()
                    stderr = cmd_result.get('stderr', '').strip()
                    if stdout:
                        print(f"       stdout: {stdout}")
                    if stderr:
                        print(f"       stderr: {stderr}")
                
                if test_passed:
                    print(f"   ✓ Test PASSED")
                    passed += 1
                else:
                    print(f"   ✗ Test FAILED")
                    failed += 1
            else:
                print(f"   ✗ Test FAILED (no result received)")
                failed += 1
            
            # Small delay between tests
            time.sleep(1)
        
        print(f"\n5. Test Summary:")
        print(f"   Total tests: {len(test_cases)}")
        print(f"   Passed: {passed}")
        print(f"   Failed: {failed}")
        print(f"   Success rate: {(passed/len(test_cases)*100):.1f}%")
        
        success = failed == 0
        
        if success:
            print(f"\n🎉 ALL TESTS PASSED! GOK-Agent end-to-end functionality is working correctly.")
        else:
            print(f"\n❌ Some tests failed. Please review the results above.")
        
        return success
        
    except Exception as e:
        logger.error(f"Test execution failed: {e}")
        return False
        
    finally:
        # Cleanup
        print(f"\n6. Cleaning up...")
        agent.disconnect()
        controller.disconnect()


def run_simple_connectivity_test():
    """Run a simple connectivity test to verify Vault and RabbitMQ integration"""
    print("=" * 80)
    print("SIMPLE CONNECTIVITY TEST")
    print("=" * 80)
    
    try:
        print("\n1. Testing Vault credential retrieval...")
        credentials = get_rabbitmq_credentials(prefer_vault=True)
        
        if credentials:
            print(f"   ✓ Successfully retrieved credentials")
            print(f"   Username: {credentials.username}")
            print(f"   Host: {credentials.host}:{credentials.port}")
            print(f"   Virtual Host: {credentials.virtual_host}")
        else:
            print("   ✗ Failed to retrieve credentials")
            return False
        
        print("\n2. Testing RabbitMQ connection...")
        connection_params = pika.ConnectionParameters(
            host=credentials.host,
            port=credentials.port,
            virtual_host=credentials.virtual_host,
            credentials=pika.PlainCredentials(credentials.username, credentials.password),
            connection_attempts=3,
            retry_delay=1
        )
        
        connection = pika.BlockingConnection(connection_params)
        channel = connection.channel()
        
        # Test queue operations
        test_queue = f"test-queue-{int(time.time())}"
        channel.queue_declare(queue=test_queue, durable=True)
        
        # Publish test message
        test_message = json.dumps({"test": "message", "timestamp": time.time()})
        channel.basic_publish(
            exchange='',
            routing_key=test_queue,
            body=test_message
        )
        
        # Clean up test queue
        channel.queue_delete(queue=test_queue)
        connection.close()
        
        print("   ✓ RabbitMQ connection and operations successful")
        
        print(f"\n🎉 CONNECTIVITY TEST PASSED!")
        print("   Vault integration and RabbitMQ connectivity are working correctly.")
        
        return True
        
    except Exception as e:
        print(f"   ✗ Connectivity test failed: {e}")
        return False


def signal_handler(signum, frame):
    """Handle interrupt signals gracefully"""
    print(f"\nReceived signal {signum}. Stopping test...")
    sys.exit(0)


def main():
    """Main function"""
    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    if not PIKA_AVAILABLE:
        print("Error: pika library not available. Please install it first.")
        return 1
    
    # Parse command line arguments
    if len(sys.argv) > 1:
        if sys.argv[1] == "connectivity":
            success = run_simple_connectivity_test()
        elif sys.argv[1] == "full":
            success = run_end_to_end_test()
        else:
            print("Usage: gok_agent_test.py [connectivity|full]")
            print("  connectivity: Run simple connectivity test")
            print("  full: Run complete end-to-end test (default)")
            return 1
    else:
        # Default to full test
        success = run_end_to_end_test()
    
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
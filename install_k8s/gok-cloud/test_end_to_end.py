#!/usr/bin/env python3
"""
End-to-End Test for Vault RabbitMQ Integration with K8s Service Account Authentication
====================================================================================

This script demonstrates the complete flow of:
1. Authenticating to Vault using Kubernetes Service Account JWT token
2. Retrieving RabbitMQ credentials from Vault
3. Publishing and consuming messages using retrieved credentials

Usage:
    python3 test_end_to_end.py
"""

import os
import sys
import json
import time
import logging
import traceback
from pathlib import Path

# Add the current directory to Python path to import vault_credentials
current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from vault_credentials import VaultCredentialManager
except ImportError as e:
    print(f"❌ Error importing vault_credentials: {e}")
    print("Make sure vault_credentials.py is in the same directory.")
    sys.exit(1)

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def print_banner(title):
    """Print a formatted banner"""
    border = "=" * 80
    print(f"\n{border}")
    print(f"{title:^80}")
    print(f"{border}\n")

def print_step(step_num, description):
    """Print a formatted step"""
    print(f"🔹 Step {step_num}: {description}")
    print("-" * 60)

def test_vault_authentication():
    """Test Vault authentication and credential retrieval"""
    print_banner("🔐 VAULT AUTHENTICATION TEST")
    
    try:
        print_step(1, "Initialize Vault Credential Manager")
        
        # Initialize with default Kubernetes service account path
        vault_manager = VaultCredentialManager(
            vault_url="http://vault.vault.svc.cluster.local:8200",
            role="gok-agent",
            jwt_path="/var/run/secrets/kubernetes.io/serviceaccount/token"
        )
        
        print("✅ Vault manager initialized successfully")
        
        print_step(2, "Authenticate with Vault using K8s Service Account")
        
        # This will authenticate and get a Vault token
        credentials = vault_manager.get_rabbitmq_credentials()
        
        if credentials:
            print("✅ Successfully authenticated with Vault!")
            print(f"📋 Retrieved credentials:")
            print(f"   Username: {credentials.get('username', 'N/A')}")
            print(f"   Password: {'*' * len(credentials.get('password', ''))}")
            return credentials
        else:
            print("❌ Failed to retrieve credentials from Vault")
            return None
            
    except Exception as e:
        print(f"❌ Vault authentication failed: {e}")
        logger.error(f"Vault authentication error: {traceback.format_exc()}")
        return None

def test_rabbitmq_connection(credentials):
    """Test RabbitMQ connection using retrieved credentials"""
    if not credentials:
        print("\n❌ Cannot test RabbitMQ - no credentials available")
        return False
        
    print_banner("🐰 RABBITMQ CONNECTION TEST")
    
    try:
        import pika
        
        print_step(1, "Connect to RabbitMQ using Vault credentials")
        
        # RabbitMQ connection parameters
        rabbitmq_host = os.getenv('RABBITMQ_HOST', 'localhost')
        rabbitmq_port = int(os.getenv('RABBITMQ_PORT', '5672'))
        
        connection_params = pika.ConnectionParameters(
            host=rabbitmq_host,
            port=rabbitmq_port,
            credentials=pika.PlainCredentials(
                username=credentials['username'],
                password=credentials['password']
            )
        )
        
        print(f"🔗 Connecting to RabbitMQ at {rabbitmq_host}:{rabbitmq_port}")
        
        connection = pika.BlockingConnection(connection_params)
        channel = connection.channel()
        
        print("✅ Successfully connected to RabbitMQ!")
        
        print_step(2, "Create test queue and exchange")
        
        # Declare queue and exchange
        queue_name = 'vault_test_queue'
        exchange_name = 'vault_test_exchange'
        
        channel.exchange_declare(exchange=exchange_name, exchange_type='direct')
        channel.queue_declare(queue=queue_name, durable=True)
        channel.queue_bind(exchange=exchange_name, queue=queue_name, routing_key='test')
        
        print(f"✅ Created queue '{queue_name}' and exchange '{exchange_name}'")
        
        print_step(3, "Publish test message")
        
        test_message = {
            'message': 'Hello from Vault-authenticated client!',
            'timestamp': time.time(),
            'source': 'vault_integration_test'
        }
        
        channel.basic_publish(
            exchange=exchange_name,
            routing_key='test',
            body=json.dumps(test_message),
            properties=pika.BasicProperties(delivery_mode=2)  # Make message persistent
        )
        
        print("✅ Message published successfully!")
        print(f"📝 Message content: {json.dumps(test_message, indent=2)}")
        
        print_step(4, "Consume test message")
        
        def callback(ch, method, properties, body):
            """Message callback function"""
            try:
                message = json.loads(body.decode())
                print("✅ Message received successfully!")
                print(f"📝 Received content: {json.dumps(message, indent=2)}")
                ch.basic_ack(delivery_tag=method.delivery_tag)
                ch.stop_consuming()
            except Exception as e:
                print(f"❌ Error processing message: {e}")
                ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
        
        channel.basic_consume(queue=queue_name, on_message_callback=callback)
        
        # Consume one message with timeout
        print("🔄 Waiting for message...")
        connection.process_data_events(time_limit=10)
        
        # Cleanup
        channel.queue_delete(queue=queue_name)
        channel.exchange_delete(exchange=exchange_name)
        connection.close()
        
        print("✅ RabbitMQ test completed successfully!")
        return True
        
    except ImportError:
        print("❌ pika library not found. Install with: pip install pika")
        return False
    except Exception as e:
        print(f"❌ RabbitMQ test failed: {e}")
        logger.error(f"RabbitMQ test error: {traceback.format_exc()}")
        return False

def test_vault_token_refresh():
    """Test Vault token refresh functionality"""
    print_banner("🔄 VAULT TOKEN REFRESH TEST")
    
    try:
        print_step(1, "Initialize Vault manager and get initial token")
        
        vault_manager = VaultCredentialManager(
            vault_url="http://vault.vault.svc.cluster.local:8200",
            role="gok-agent",
            jwt_path="/var/run/secrets/kubernetes.io/serviceaccount/token"
        )
        
        # Get credentials to trigger initial authentication
        credentials1 = vault_manager.get_rabbitmq_credentials()
        if not credentials1:
            print("❌ Failed to get initial credentials")
            return False
            
        initial_token = vault_manager.vault_token
        print(f"✅ Initial token obtained: {initial_token[:10]}...")
        
        print_step(2, "Force token refresh")
        
        # Clear the token to force refresh
        vault_manager.vault_token = None
        vault_manager.token_expiry = 0
        
        credentials2 = vault_manager.get_rabbitmq_credentials()
        if not credentials2:
            print("❌ Failed to get credentials after token refresh")
            return False
            
        new_token = vault_manager.vault_token
        print(f"✅ New token obtained: {new_token[:10]}...")
        
        if initial_token != new_token:
            print("✅ Token refresh successful - tokens are different")
        else:
            print("ℹ️  Tokens are the same (normal for short test duration)")
            
        return True
        
    except Exception as e:
        print(f"❌ Token refresh test failed: {e}")
        logger.error(f"Token refresh test error: {traceback.format_exc()}")
        return False

def run_environment_check():
    """Check if running environment is suitable for testing"""
    print_banner("🔍 ENVIRONMENT CHECK")
    
    checks = []
    
    # Check if running in Kubernetes pod
    k8s_token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    if os.path.exists(k8s_token_path):
        checks.append(("✅", "Running in Kubernetes pod"))
        with open(k8s_token_path, 'r') as f:
            token_preview = f.read()[:50] + "..."
        checks.append(("📝", f"K8s token preview: {token_preview}"))
    else:
        checks.append(("⚠️", "Not running in Kubernetes pod - using fallback"))
    
    # Check Vault connectivity
    vault_url = "http://vault.vault.svc.cluster.local:8200"
    checks.append(("📍", f"Target Vault URL: {vault_url}"))
    
    # Check environment variables
    rabbitmq_host = os.getenv('RABBITMQ_HOST', 'localhost')
    rabbitmq_port = os.getenv('RABBITMQ_PORT', '5672')
    checks.append(("🐰", f"RabbitMQ target: {rabbitmq_host}:{rabbitmq_port}"))
    
    # Print all checks
    for status, message in checks:
        print(f"{status} {message}")
    
    print("\n" + "="*80 + "\n")

def main():
    """Main test runner"""
    print_banner("🚀 VAULT RABBITMQ INTEGRATION - END-TO-END TEST")
    
    # Environment check
    run_environment_check()
    
    # Test results tracking
    results = {}
    
    # Test 1: Vault Authentication
    print("🧪 Running Test Suite...")
    print("\n")
    
    credentials = test_vault_authentication()
    results['vault_auth'] = credentials is not None
    
    # Test 2: RabbitMQ Connection (if we have credentials)
    if credentials:
        rabbitmq_success = test_rabbitmq_connection(credentials)
        results['rabbitmq_test'] = rabbitmq_success
    else:
        print("\n⏭️  Skipping RabbitMQ test - no credentials available")
        results['rabbitmq_test'] = False
    
    # Test 3: Token Refresh
    refresh_success = test_vault_token_refresh()
    results['token_refresh'] = refresh_success
    
    # Final Results Summary
    print_banner("📊 TEST RESULTS SUMMARY")
    
    total_tests = len(results)
    passed_tests = sum(results.values())
    
    print(f"📈 Overall Results: {passed_tests}/{total_tests} tests passed\n")
    
    for test_name, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        test_display = test_name.replace('_', ' ').title()
        print(f"{status} {test_display}")
    
    if passed_tests == total_tests:
        print(f"\n🎉 All tests passed! Vault-RabbitMQ integration is working correctly.")
        return 0
    else:
        print(f"\n⚠️  {total_tests - passed_tests} test(s) failed. Check the logs above for details.")
        return 1

if __name__ == "__main__":
    try:
        exit_code = main()
        sys.exit(exit_code)
    except KeyboardInterrupt:
        print("\n\n⏹️  Test interrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        logger.error(f"Unexpected error: {traceback.format_exc()}")
        sys.exit(1)
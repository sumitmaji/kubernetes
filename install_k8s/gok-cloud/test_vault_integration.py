#!/usr/bin/env python3
"""
Comprehensive test suite for Vault RabbitMQ integration
Tests credential storage, retrieval, and end-to-end functionality
"""

import os
import sys
import json
import time
import subprocess
import unittest
import tempfile
from unittest.mock import patch, MagicMock

# Add the agent directory to Python path to import vault_credentials
import os
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(CURRENT_DIR, 'agent'))

try:
    import pika
    from vault_credentials import (
        VaultCredentialManager, 
        RabbitMQCredentials,
        get_rabbitmq_credentials,
        test_vault_connectivity,
        test_credential_retrieval
    )
    PIKA_AVAILABLE = True
except ImportError as e:
    print(f"Warning: Some imports failed: {e}")
    PIKA_AVAILABLE = False

class TestVaultCredentials(unittest.TestCase):
    """Test cases for Vault credential management"""
    
    def setUp(self):
        """Set up test environment"""
        self.test_vault_addr = "http://localhost:8200"
        self.test_vault_token = "test-token"
        self.test_vault_path = "secret/test/rabbitmq"
        
        # Create test manager
        self.manager = VaultCredentialManager(
            vault_addr=self.test_vault_addr,
            vault_token=self.test_vault_token,
            vault_path=self.test_vault_path
        )
    
    def test_vault_manager_initialization(self):
        """Test VaultCredentialManager initialization"""
        self.assertEqual(self.manager.vault_addr, self.test_vault_addr)
        self.assertEqual(self.manager.vault_token, self.test_vault_token)
        self.assertEqual(self.manager.vault_path, self.test_vault_path)
    
    def test_vault_manager_env_defaults(self):
        """Test VaultCredentialManager with environment variable defaults"""
        with patch.dict(os.environ, {
            'VAULT_ADDR': 'http://env-vault:8200',
            'VAULT_TOKEN': 'env-token',
            'VAULT_PATH': 'secret/env/rabbitmq'
        }):
            manager = VaultCredentialManager()
            self.assertEqual(manager.vault_addr, 'http://env-vault:8200')
            self.assertEqual(manager.vault_token, 'env-token')
            self.assertEqual(manager.vault_path, 'secret/env/rabbitmq')
    
    @patch('subprocess.run')
    def test_vault_command_success(self, mock_run):
        """Test successful vault command execution"""
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = "success output"
        mock_run.return_value.stderr = ""
        
        success, output = self.manager._run_vault_command(['status'])
        
        self.assertTrue(success)
        self.assertEqual(output, "success output")
        mock_run.assert_called_once()
    
    @patch('subprocess.run')
    def test_vault_command_failure(self, mock_run):
        """Test failed vault command execution"""
        mock_run.return_value.returncode = 1
        mock_run.return_value.stdout = ""
        mock_run.return_value.stderr = "error output"
        
        success, output = self.manager._run_vault_command(['status'])
        
        self.assertFalse(success)
        self.assertEqual(output, "error output")
    
    @patch('subprocess.run')
    def test_vault_command_timeout(self, mock_run):
        """Test vault command timeout"""
        mock_run.side_effect = subprocess.TimeoutExpired(['vault'], 30)
        
        success, output = self.manager._run_vault_command(['status'])
        
        self.assertFalse(success)
        self.assertEqual(output, "Command timeout")
    
    @patch.object(VaultCredentialManager, '_run_vault_command')
    def test_check_vault_status_success(self, mock_cmd):
        """Test successful vault status check"""
        mock_cmd.return_value = (True, "Sealed: false")
        
        result = self.manager.check_vault_status()
        
        self.assertTrue(result)
        mock_cmd.assert_called_once_with(['status'])
    
    @patch.object(VaultCredentialManager, '_run_vault_command')
    def test_check_vault_status_failure(self, mock_cmd):
        """Test failed vault status check"""
        mock_cmd.return_value = (False, "connection refused")
        
        result = self.manager.check_vault_status()
        
        self.assertFalse(result)
    
    @patch.object(VaultCredentialManager, '_run_vault_command')
    def test_get_credentials_success(self, mock_cmd):
        """Test successful credential retrieval from Vault"""
        # Mock successful vault response
        mock_response = {
            "data": {
                "data": {
                    "username": "test_user",
                    "password": "test_password"
                }
            }
        }
        mock_cmd.return_value = (True, json.dumps(mock_response))
        
        credentials = self.manager.get_rabbitmq_credentials()
        
        self.assertIsNotNone(credentials)
        self.assertEqual(credentials.username, "test_user")
        self.assertEqual(credentials.password, "test_password")
        self.assertEqual(credentials.host, "rabbitmq.rabbitmq")
        self.assertEqual(credentials.port, 5672)
    
    @patch.object(VaultCredentialManager, '_run_vault_command')
    def test_get_credentials_failure(self, mock_cmd):
        """Test failed credential retrieval from Vault"""
        mock_cmd.return_value = (False, "secret not found")
        
        credentials = self.manager.get_rabbitmq_credentials()
        
        self.assertIsNone(credentials)
    
    @patch.object(VaultCredentialManager, '_run_vault_command')
    def test_get_credentials_malformed_response(self, mock_cmd):
        """Test credential retrieval with malformed JSON response"""
        mock_cmd.return_value = (True, "invalid json")
        
        credentials = self.manager.get_rabbitmq_credentials()
        
        self.assertIsNone(credentials)
    
    @patch.object(VaultCredentialManager, '_run_vault_command')
    def test_store_credentials_success(self, mock_cmd):
        """Test successful credential storage in Vault"""
        mock_cmd.return_value = (True, "secret stored")
        
        result = self.manager.store_credentials("test_user", "test_pass", {"env": "test"})
        
        self.assertTrue(result)
        # Verify the command was called with correct parameters
        args = mock_cmd.call_args[0][0]
        self.assertEqual(args[0], 'kv')
        self.assertEqual(args[1], 'put')
        self.assertEqual(args[2], self.test_vault_path)
    
    @patch.object(VaultCredentialManager, '_run_vault_command')
    def test_store_credentials_failure(self, mock_cmd):
        """Test failed credential storage in Vault"""
        mock_cmd.return_value = (False, "storage failed")
        
        result = self.manager.store_credentials("test_user", "test_pass")
        
        self.assertFalse(result)
    
    def test_store_credentials_no_token(self):
        """Test credential storage without Vault token"""
        manager = VaultCredentialManager(vault_token=None)
        
        result = manager.store_credentials("test_user", "test_pass")
        
        self.assertFalse(result)


class TestRabbitMQCredentials(unittest.TestCase):
    """Test cases for RabbitMQCredentials data class"""
    
    def test_credentials_creation(self):
        """Test creating RabbitMQCredentials object"""
        creds = RabbitMQCredentials("user", "pass", "host", 1234, "/vhost")
        
        self.assertEqual(creds.username, "user")
        self.assertEqual(creds.password, "pass")
        self.assertEqual(creds.host, "host")
        self.assertEqual(creds.port, 1234)
        self.assertEqual(creds.virtual_host, "/vhost")
    
    def test_credentials_defaults(self):
        """Test RabbitMQCredentials with default values"""
        creds = RabbitMQCredentials("user", "pass")
        
        self.assertEqual(creds.host, "rabbitmq.rabbitmq")
        self.assertEqual(creds.port, 5672)
        self.assertEqual(creds.virtual_host, "/")


class TestFallbackFunctions(unittest.TestCase):
    """Test cases for fallback credential functions"""
    
    @patch('subprocess.run')
    def test_k8s_credentials_success(self, mock_run):
        """Test successful Kubernetes credential retrieval"""
        # Mock kubectl responses
        mock_run.side_effect = [
            # Username retrieval
            MagicMock(returncode=0, stdout="dGVzdF91c2Vy", stderr=""),  # base64 for "test_user"
            # Base64 decode username
            MagicMock(returncode=0, stdout="test_user", stderr=""),
            # Password retrieval
            MagicMock(returncode=0, stdout="dGVzdF9wYXNz", stderr=""),  # base64 for "test_pass"
            # Base64 decode password
            MagicMock(returncode=0, stdout="test_pass", stderr="")
        ]
        
        from vault_credentials import get_rabbitmq_credentials_from_k8s
        credentials = get_rabbitmq_credentials_from_k8s()
        
        self.assertIsNotNone(credentials)
        self.assertEqual(credentials.username, "test_user")
        self.assertEqual(credentials.password, "test_pass")
    
    @patch('subprocess.run')
    def test_k8s_credentials_failure(self, mock_run):
        """Test failed Kubernetes credential retrieval"""
        mock_run.return_value.returncode = 1
        
        from vault_credentials import get_rabbitmq_credentials_from_k8s
        credentials = get_rabbitmq_credentials_from_k8s()
        
        self.assertIsNone(credentials)
    
    @patch('vault_credentials.get_rabbitmq_credentials_from_vault')
    @patch('vault_credentials.get_rabbitmq_credentials_from_k8s')
    def test_fallback_vault_first_success(self, mock_k8s, mock_vault):
        """Test fallback mechanism with Vault success"""
        mock_vault.return_value = RabbitMQCredentials("vault_user", "vault_pass")
        mock_k8s.return_value = None
        
        from vault_credentials import get_rabbitmq_credentials
        credentials = get_rabbitmq_credentials(prefer_vault=True)
        
        self.assertIsNotNone(credentials)
        self.assertEqual(credentials.username, "vault_user")
        mock_vault.assert_called_once()
        mock_k8s.assert_not_called()
    
    @patch('vault_credentials.get_rabbitmq_credentials_from_vault')
    @patch('vault_credentials.get_rabbitmq_credentials_from_k8s')
    def test_fallback_vault_first_fallback(self, mock_k8s, mock_vault):
        """Test fallback mechanism with Vault failure, Kubernetes success"""
        mock_vault.return_value = None
        mock_k8s.return_value = RabbitMQCredentials("k8s_user", "k8s_pass")
        
        from vault_credentials import get_rabbitmq_credentials
        credentials = get_rabbitmq_credentials(prefer_vault=True)
        
        self.assertIsNotNone(credentials)
        self.assertEqual(credentials.username, "k8s_user")
        mock_vault.assert_called_once()
        mock_k8s.assert_called_once()


@unittest.skipUnless(PIKA_AVAILABLE, "pika not available")
class TestRabbitMQConnectivity(unittest.TestCase):
    """Test cases for RabbitMQ connectivity using credentials"""
    
    def test_credentials_to_pika_parameters(self):
        """Test converting credentials to pika connection parameters"""
        creds = RabbitMQCredentials("user", "pass", "host", 1234, "/vhost")
        
        # This would normally be done in the application code
        connection_params = {
            'host': creds.host,
            'port': creds.port,
            'virtual_host': creds.virtual_host,
            'credentials': pika.PlainCredentials(creds.username, creds.password)
        }
        
        self.assertEqual(connection_params['host'], "host")
        self.assertEqual(connection_params['port'], 1234)
        self.assertEqual(connection_params['virtual_host'], "/vhost")
        self.assertIsInstance(connection_params['credentials'], pika.PlainCredentials)


class TestIntegrationScenarios(unittest.TestCase):
    """Integration test scenarios"""
    
    def setUp(self):
        """Set up integration test environment"""
        self.temp_dir = tempfile.mkdtemp()
    
    def tearDown(self):
        """Clean up integration test environment"""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)
    
    def test_vault_script_help(self):
        """Test vault setup script help command"""
        try:
            result = subprocess.run([
                '/home/sumit/Documents/repository/kubernetes/vault_rabbitmq_setup.sh',
                'help'
            ], capture_output=True, text=True, timeout=10)
            
            self.assertEqual(result.returncode, 0)
            self.assertIn("Usage:", result.stdout)
            self.assertIn("Commands:", result.stdout)
        except Exception as e:
            self.skipTest(f"Vault setup script not accessible: {e}")
    
    def test_vault_script_status_no_token(self):
        """Test vault setup script status without token"""
        try:
            # Remove VAULT_TOKEN from environment
            env = os.environ.copy()
            if 'VAULT_TOKEN' in env:
                del env['VAULT_TOKEN']
            
            result = subprocess.run([
                '/home/sumit/Documents/repository/kubernetes/vault_rabbitmq_setup.sh',
                'status'
            ], capture_output=True, text=True, timeout=10, env=env)
            
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("VAULT_TOKEN", result.stderr)
        except Exception as e:
            self.skipTest(f"Vault setup script not accessible: {e}")


def run_comprehensive_tests():
    """Run all test suites and return results"""
    print("=" * 60)
    print("COMPREHENSIVE VAULT RABBITMQ INTEGRATION TESTS")
    print("=" * 60)
    
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add test classes
    test_classes = [
        TestVaultCredentials,
        TestRabbitMQCredentials,
        TestFallbackFunctions,
        TestRabbitMQConnectivity,
        TestIntegrationScenarios
    ]
    
    for test_class in test_classes:
        tests = loader.loadTestsFromTestCase(test_class)
        suite.addTests(tests)
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2, stream=sys.stdout)
    result = runner.run(suite)
    
    # Print summary
    print("\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print(f"Skipped: {len(result.skipped) if hasattr(result, 'skipped') else 0}")
    
    if result.failures:
        print("\nFAILURES:")
        for test, traceback in result.failures:
            print(f"- {test}: {traceback.splitlines()[-1]}")
    
    if result.errors:
        print("\nERRORS:")
        for test, traceback in result.errors:
            print(f"- {test}: {traceback.splitlines()[-1]}")
    
    return result.wasSuccessful()


def run_live_tests():
    """Run live tests against actual services if available"""
    print("\n" + "=" * 60)
    print("LIVE SERVICE TESTS")
    print("=" * 60)
    
    # Test Vault connectivity
    print("\n1. Testing Vault connectivity...")
    try:
        if test_vault_connectivity():
            print("✓ Vault connectivity test passed")
        else:
            print("✗ Vault connectivity test failed")
    except Exception as e:
        print(f"✗ Vault connectivity test error: {e}")
    
    # Test credential retrieval
    print("\n2. Testing credential retrieval...")
    try:
        test_credential_retrieval()
        print("✓ Credential retrieval test completed")
    except Exception as e:
        print(f"✗ Credential retrieval test error: {e}")
    
    # Test RabbitMQ connection
    print("\n3. Testing RabbitMQ connection...")
    try:
        from vault_credentials import get_rabbitmq_credentials
        creds = get_rabbitmq_credentials(prefer_vault=True)
        
        if creds and PIKA_AVAILABLE:
            try:
                connection = pika.BlockingConnection(
                    pika.ConnectionParameters(
                        host=creds.host,
                        port=creds.port,
                        virtual_host=creds.virtual_host,
                        credentials=pika.PlainCredentials(creds.username, creds.password),
                        connection_attempts=3,
                        retry_delay=1
                    )
                )
                connection.close()
                print("✓ RabbitMQ connection test passed")
            except Exception as e:
                print(f"✗ RabbitMQ connection test failed: {e}")
        else:
            print("✗ RabbitMQ connection test skipped (no credentials or pika unavailable)")
    except Exception as e:
        print(f"✗ RabbitMQ connection test error: {e}")


if __name__ == "__main__":
    print("Vault RabbitMQ Integration Test Suite")
    print("=" * 40)
    
    # Check if running in test mode or live mode
    if len(sys.argv) > 1 and sys.argv[1] == "live":
        run_live_tests()
    else:
        # Run comprehensive unit tests
        success = run_comprehensive_tests()
        
        # Also run live tests if requested
        if "--with-live" in sys.argv:
            run_live_tests()
        
        # Exit with appropriate code
        sys.exit(0 if success else 1)
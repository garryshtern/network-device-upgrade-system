#!/usr/bin/env python3
"""
SSH Mock Server for Network Device Testing
Provides realistic SSH connections to mock network devices
"""

import socket
import threading
import time
import json
import logging
from typing import Dict, Any, Optional
from datetime import datetime
import paramiko
from paramiko import ServerInterface, DSSKey, RSAKey, SFTPServerInterface, SFTPServer, SFTPAttributes
from paramiko.common import AUTH_SUCCESSFUL, AUTH_FAILED, OPEN_SUCCEEDED
import os
import sys

# Import our mock device engine
from mock_device_engine import MockDeviceEngine, MockDeviceManager, MockDeviceConfig

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class MockSSHServerInterface(ServerInterface):
    """SSH Server interface for mock devices"""
    
    def __init__(self, device_engine: MockDeviceEngine):
        self.device = device_engine
        self.authenticated = False
        self.username = None
    
    def check_channel_request(self, kind: str, chanid: int) -> int:
        """Check if a channel request is allowed"""
        if kind == 'session':
            return OPEN_SUCCEEDED
        return AUTH_FAILED
    
    def check_auth_password(self, username: str, password: str) -> int:
        """Authenticate with username/password"""
        # Simple authentication - in real testing you'd validate against device config
        expected_users = {
            'admin': ['admin', 'cisco', 'password'],
            'root': ['root', 'opengear', 'password'],
            'test': ['test', 'mock_password']
        }
        
        if username in expected_users and password in expected_users[username]:
            self.authenticated = True
            self.username = username
            logger.info(f"SSH authentication successful for {username} on {self.device.config.device_id}")
            return AUTH_SUCCESSFUL
        
        logger.warning(f"SSH authentication failed for {username} on {self.device.config.device_id}")
        return AUTH_FAILED
    
    def check_auth_publickey(self, username: str, key) -> int:
        """Authenticate with public key"""
        # For testing, we'll accept any key for specific users
        test_users = ['admin', 'root', 'test']
        if username in test_users:
            self.authenticated = True
            self.username = username
            logger.info(f"SSH key authentication successful for {username} on {self.device.config.device_id}")
            return AUTH_SUCCESSFUL
        return AUTH_FAILED
    
    def get_allowed_auths(self, username: str) -> str:
        """Get allowed authentication methods"""
        return 'password,publickey'


class MockSSHSession(threading.Thread):
    """Handle individual SSH session"""
    
    def __init__(self, client_socket: socket.socket, device_engine: MockDeviceEngine):
        super().__init__(daemon=True)
        self.client_socket = client_socket
        self.device = device_engine
        self.transport = None
        self.channel = None
        self.session_active = True
        
    def run(self):
        """Run SSH session"""
        try:
            # Create SSH transport
            self.transport = paramiko.Transport(self.client_socket)
            
            # Load server key
            host_key = self._get_or_create_host_key()
            self.transport.add_server_key(host_key)
            
            # Create server interface
            server_interface = MockSSHServerInterface(self.device)
            
            # Start SSH server
            self.transport.start_server(server=server_interface)
            
            # Wait for authentication
            self.channel = self.transport.accept(timeout=30)
            if self.channel is None:
                logger.error(f"SSH channel not established for {self.device.config.device_id}")
                return
                
            logger.info(f"SSH session established for {self.device.config.device_id}")
            
            # Send device banner/prompt
            self._send_device_banner()
            
            # Main command loop
            self._command_loop()
            
        except Exception as e:
            logger.error(f"SSH session error for {self.device.config.device_id}: {str(e)}")
        finally:
            self._cleanup()
    
    def _get_or_create_host_key(self):
        """Get or create SSH host key"""
        key_path = f"tests/mock-devices/keys/{self.device.config.device_id}_host_key"
        
        # Create keys directory
        os.makedirs("tests/mock-devices/keys", exist_ok=True)
        
        if os.path.exists(key_path):
            try:
                return RSAKey.from_private_key_file(key_path)
            except Exception:
                # If key is corrupted, create new one
                pass
        
        # Generate new key
        logger.info(f"Generating new host key for {self.device.config.device_id}")
        key = RSAKey.generate(2048)
        key.write_private_key_file(key_path)
        return key
    
    def _send_device_banner(self):
        """Send device-specific login banner"""
        platform = self.device.config.platform_type
        device_id = self.device.config.device_id
        
        banners = {
            'cisco_nxos': f"""
Cisco NX-OS Software
TAC support: http://www.cisco.com/tac
Copyright (c) 2002-2024, Cisco Systems, Inc. All rights reserved.

{device_id}# """,
            
            'cisco_iosxe': f"""


{device_id}>""",
            
            'fortios': f"""
Welcome to FortiOS
{device_id} # """,
            
            'opengear': f"""
Opengear Gateway
{device_id}:~ # """,
            
            'metamako_mos': f"""
Metamako MOS
{device_id}:~$ """
        }
        
        banner = banners.get(platform, f"\n{device_id}$ ")
        self.channel.send(banner)
    
    def _command_loop(self):
        """Main command processing loop"""
        command_buffer = ""
        
        while self.session_active:
            try:
                # Check if channel is still open
                if self.channel.closed:
                    break
                
                # Receive data
                data = self.channel.recv(1024)
                if not data:
                    break
                
                # Decode input
                try:
                    input_str = data.decode('utf-8')
                except UnicodeDecodeError:
                    # Handle binary data or encoding issues
                    input_str = data.decode('utf-8', errors='replace')
                
                # Process each character
                for char in input_str:
                    if char == '\r' or char == '\n':
                        if command_buffer.strip():
                            self._process_command(command_buffer.strip())
                        command_buffer = ""
                        self._send_prompt()
                    elif char == '\x03':  # Ctrl+C
                        command_buffer = ""
                        self.channel.send("^C\n")
                        self._send_prompt()
                    elif char == '\x04':  # Ctrl+D (EOF)
                        self.session_active = False
                        break
                    elif char == '\x08' or char == '\x7f':  # Backspace
                        if command_buffer:
                            command_buffer = command_buffer[:-1]
                            self.channel.send('\b \b')
                    elif ord(char) >= 32:  # Printable characters
                        command_buffer += char
                        self.channel.send(char)  # Echo character
                
            except socket.timeout:
                continue
            except Exception as e:
                logger.error(f"Command loop error: {str(e)}")
                break
    
    def _process_command(self, command: str):
        """Process a command and send response"""
        logger.info(f"Processing command on {self.device.config.device_id}: {command}")
        
        # Handle special commands
        if command.lower() in ['exit', 'quit', 'logout']:
            self.channel.send("Goodbye!\n")
            self.session_active = False
            return
        
        if command.lower() in ['help', '?']:
            self._send_help()
            return
        
        # Process command through device engine
        try:
            response = self.device.process_command(command)
            
            # Format and send response
            if response.get('status') == 'success':
                output = response.get('output', '')
                self.channel.send(f"{output}\n")
            else:
                error_msg = response.get('message', 'Command failed')
                self.channel.send(f"Error: {error_msg}\n")
                
        except Exception as e:
            logger.error(f"Command processing error: {str(e)}")
            self.channel.send(f"Error: {str(e)}\n")
    
    def _send_help(self):
        """Send help information"""
        platform = self.device.config.platform_type
        
        help_text = {
            'cisco_nxos': """
Available commands:
  show version                 - Display version information
  show install all status     - Display installation status  
  show system resources       - Display system resource usage
  install all nxos <image>     - Install NX-OS image
  dir bootflash:              - List bootflash contents
  exit                        - Exit session
""",
            'fortios': """
Available commands:
  get system status           - Display system status
  get system ha status        - Display HA status
  execute restore image <img> - Restore firmware image
  get system performance      - Display performance info
  exit                       - Exit session
""",
            'opengear': """
Available commands:
  config -g config.system.model   - Get device model
  config -g config.system.version - Get firmware version
  upgrade <image>                 - Upgrade firmware
  exit                           - Exit session
"""
        }
        
        help_msg = help_text.get(platform, "Type 'exit' to quit\n")
        self.channel.send(help_msg)
    
    def _send_prompt(self):
        """Send command prompt"""
        platform = self.device.config.platform_type
        device_id = self.device.config.device_id
        
        prompts = {
            'cisco_nxos': f"{device_id}# ",
            'cisco_iosxe': f"{device_id}>",
            'fortios': f"{device_id} # ",
            'opengear': f"{device_id}:~ # ",
            'metamako_mos': f"{device_id}:~$ "
        }
        
        prompt = prompts.get(platform, f"{device_id}$ ")
        self.channel.send(prompt)
    
    def _cleanup(self):
        """Clean up SSH session"""
        try:
            if self.channel:
                self.channel.close()
            if self.transport:
                self.transport.close()
            if self.client_socket:
                self.client_socket.close()
        except Exception as e:
            logger.error(f"Cleanup error: {str(e)}")
        
        logger.info(f"SSH session closed for {self.device.config.device_id}")


class MockSSHServer:
    """SSH Server for mock devices"""
    
    def __init__(self, device_manager: MockDeviceManager, base_port: int = 2200):
        self.device_manager = device_manager
        self.base_port = base_port
        self.server_sockets: Dict[str, socket.socket] = {}
        self.server_threads: Dict[str, threading.Thread] = {}
        self.running = False
    
    def start_servers(self):
        """Start SSH servers for all devices"""
        self.running = True
        port_offset = 0
        
        for device_id, device in self.device_manager.devices.items():
            port = self.base_port + port_offset
            self._start_device_server(device_id, device, port)
            port_offset += 1
            
        logger.info(f"Started SSH servers for {len(self.device_manager.devices)} devices")
    
    def _start_device_server(self, device_id: str, device: MockDeviceEngine, port: int):
        """Start SSH server for specific device"""
        try:
            # Create server socket
            server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            server_socket.bind(('127.0.0.1', port))
            server_socket.listen(5)
            
            self.server_sockets[device_id] = server_socket
            
            # Start server thread
            server_thread = threading.Thread(
                target=self._device_server_loop,
                args=(device_id, device, server_socket),
                daemon=True
            )
            server_thread.start()
            self.server_threads[device_id] = server_thread
            
            logger.info(f"SSH server started for {device_id} on port {port}")
            
        except Exception as e:
            logger.error(f"Failed to start SSH server for {device_id}: {str(e)}")
    
    def _device_server_loop(self, device_id: str, device: MockDeviceEngine, server_socket: socket.socket):
        """Server loop for device SSH connections"""
        while self.running:
            try:
                # Accept connection
                client_socket, client_address = server_socket.accept()
                logger.info(f"SSH connection from {client_address} to {device_id}")
                
                # Handle session
                session = MockSSHSession(client_socket, device)
                session.start()
                
            except socket.error as e:
                if self.running:  # Only log if we're supposed to be running
                    logger.error(f"Socket error for {device_id}: {str(e)}")
                break
            except Exception as e:
                logger.error(f"Server loop error for {device_id}: {str(e)}")
    
    def stop_servers(self):
        """Stop all SSH servers"""
        self.running = False
        
        for device_id, server_socket in self.server_sockets.items():
            try:
                server_socket.close()
                logger.info(f"Stopped SSH server for {device_id}")
            except Exception as e:
                logger.error(f"Error stopping server for {device_id}: {str(e)}")
        
        # Wait for threads to finish
        for device_id, thread in self.server_threads.items():
            thread.join(timeout=5)
        
        self.server_sockets.clear()
        self.server_threads.clear()
        
        logger.info("All SSH servers stopped")
    
    def get_device_connection_info(self) -> Dict[str, Dict[str, Any]]:
        """Get connection information for all devices"""
        info = {}
        port_offset = 0
        
        for device_id in self.device_manager.devices.keys():
            port = self.base_port + port_offset
            info[device_id] = {
                'host': '127.0.0.1',
                'port': port,
                'username': 'admin',
                'password': 'admin'
            }
            port_offset += 1
            
        return info


class MockHTTPAPIServer:
    """HTTP API server for devices that use REST APIs (FortiOS, Opengear)"""
    
    def __init__(self, device_manager: MockDeviceManager, base_port: int = 8443):
        self.device_manager = device_manager
        self.base_port = base_port
        self.servers: Dict[str, Any] = {}
        
    def start_servers(self):
        """Start HTTP API servers for relevant devices"""
        try:
            from http.server import HTTPServer, BaseHTTPRequestHandler
            import json
            
            port_offset = 0
            for device_id, device in self.device_manager.devices.items():
                # Only start HTTP servers for devices that use APIs
                if device.config.platform_type in ['fortios', 'opengear']:
                    port = self.base_port + port_offset
                    self._start_http_server(device_id, device, port)
                    port_offset += 1
                    
        except ImportError:
            logger.warning("HTTP server functionality not available")
    
    def _start_http_server(self, device_id: str, device: MockDeviceEngine, port: int):
        """Start HTTP server for device API"""
        # This would implement FortiOS API and Opengear API endpoints
        # For brevity, showing structure only
        logger.info(f"HTTP API server would start for {device_id} on port {port}")
        pass


def create_test_environment():
    """Create comprehensive test environment with mock devices and servers"""
    
    # Create device manager
    manager = MockDeviceManager()
    
    # Create test devices based on mock inventory
    devices_config = [
        {
            'device_id': 'nxos-switch-01',
            'platform_type': 'cisco_nxos', 
            'model': 'N9K-C93180YC-EX',
            'firmware_version': '9.3.10',
            'target_version': '10.1.2',
            'custom_behaviors': {
                'issu_capable': True,
                'epld_upgrade_required': True,
                'current_epld_version': '1.2.3',
                'target_epld_version': '1.3.1'
            }
        },
        {
            'device_id': 'fortigate-fw-01',
            'platform_type': 'fortios',
            'model': 'FortiGate-600E', 
            'firmware_version': '6.4.8',
            'target_version': '7.2.4',
            'custom_behaviors': {
                'ha_enabled': True,
                'ha_role': 'primary',
                'upgrade_path': ['6.4.14', '7.0.12', '7.2.4'],
                'current_step': 0,
                'vdom_enabled': True,
                'vdom_count': 3
            }
        },
        {
            'device_id': 'iosxe-router-01',
            'platform_type': 'cisco_iosxe',
            'model': 'ISR4431',
            'firmware_version': '16.12.07', 
            'target_version': '17.06.04',
            'custom_behaviors': {
                'install_mode': True
            }
        },
        {
            'device_id': 'opengear-im7200',
            'platform_type': 'opengear',
            'model': 'IM7200-2-DAC',
            'firmware_version': '4.8.2',
            'target_version': '4.12.1',
            'custom_behaviors': {
                'api_capable': True,
                'upgrade_method': 'web_api'
            }
        },
        {
            'device_id': 'metamako-mc48',
            'platform_type': 'metamako_mos',
            'model': 'MetaConnect-48',
            'firmware_version': '0.39.1',
            'target_version': '0.39.11', 
            'custom_behaviors': {
                'metawatch_enabled': True,
                'manage_applications': True
            }
        }
    ]
    
    # Create devices
    for config_dict in devices_config:
        config = MockDeviceConfig(**config_dict)
        manager.create_device(config)
    
    return manager


if __name__ == "__main__":
    """Test the SSH mock server"""
    
    print("Starting Mock SSH Server Test Environment")
    print("=" * 50)
    
    # Create test environment
    device_manager = create_test_environment()
    
    # Create and start SSH servers
    ssh_server = MockSSHServer(device_manager, base_port=2200)
    
    try:
        ssh_server.start_servers()
        
        # Display connection information
        connection_info = ssh_server.get_device_connection_info()
        print("\nMock Device SSH Connections:")
        print("-" * 30)
        for device_id, info in connection_info.items():
            print(f"{device_id}:")
            print(f"  SSH: ssh {info['username']}@{info['host']} -p {info['port']}")
            print(f"  Password: {info['password']}")
        
        print("\nTest Commands:")
        print("- SSH to any device and run platform-specific commands")
        print("- Try 'show version' on Cisco devices")  
        print("- Try 'get system status' on FortiOS devices")
        print("- Type 'help' for available commands")
        print("- Type 'exit' to close SSH session")
        print("\nPress Ctrl+C to stop all servers")
        
        # Keep servers running
        while True:
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("\nShutting down servers...")
        ssh_server.stop_servers()
        print("All servers stopped.")
        
    except Exception as e:
        print(f"Error: {str(e)}")
        ssh_server.stop_servers()
        
    print("Mock SSH Server test completed.")
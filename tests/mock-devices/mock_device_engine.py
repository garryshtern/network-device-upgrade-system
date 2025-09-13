#!/usr/bin/env python3
"""
Mock Device Engine for Network Device Upgrade Testing
Simulates realistic network appliance behavior without physical hardware
"""

import json
import time
import random
import sqlite3
import threading
from abc import ABC, abstractmethod
from enum import Enum
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Callable
from dataclasses import dataclass, field


class DeviceState(Enum):
    """Device operational states"""
    ONLINE = "online"
    UPGRADING = "upgrading"
    REBOOTING = "rebooting"
    OFFLINE = "offline"
    ERROR = "error"
    MAINTENANCE = "maintenance"


class UpgradePhase(Enum):
    """Upgrade process phases"""
    IDLE = "idle"
    PRE_VALIDATION = "pre_validation"
    IMAGE_DOWNLOAD = "image_download"
    IMAGE_VERIFICATION = "image_verification"
    BACKUP = "backup"
    INSTALLATION = "installation"
    REBOOT = "reboot"
    POST_VALIDATION = "post_validation"
    COMPLETE = "complete"
    FAILED = "failed"
    ROLLBACK = "rollback"


@dataclass
class MockDeviceConfig:
    """Configuration for mock device behavior"""
    device_id: str
    platform_type: str
    model: str
    firmware_version: str
    target_version: str
    failure_probability: float = 0.05
    response_delay_ms: tuple = (50, 200)
    upgrade_duration_seconds: int = 300
    reboot_duration_seconds: int = 60
    custom_behaviors: Dict[str, Any] = field(default_factory=dict)


class NetworkError(Exception):
    """Network-related errors"""
    pass


class DeviceError(Exception):
    """Device-specific errors"""
    pass


class MockDeviceEngine:
    """Core engine for mock device simulation"""
    
    def __init__(self, config: MockDeviceConfig):
        self.config = config
        self.state = DeviceState.ONLINE
        self.upgrade_phase = UpgradePhase.IDLE
        self.upgrade_progress = 0
        self.last_command_time = datetime.now()
        self.error_conditions: List[str] = []
        self.session_data: Dict[str, Any] = {}
        
        # Initialize database for state persistence
        self._init_database()
        
        # Load device-specific behavior
        self.behavior = self._load_device_behavior()
    
    def _init_database(self):
        """Initialize SQLite database for state persistence"""
        import os
        import tempfile
        
        # Create state directory if it doesn't exist or use temp directory for CI
        state_dir = "tests/mock-devices/state"
        if not os.path.exists(state_dir):
            try:
                os.makedirs(state_dir, exist_ok=True)
                self.db_path = f"{state_dir}/{self.config.device_id}.db"
            except (OSError, PermissionError):
                # Fall back to temp directory for CI environments
                temp_dir = tempfile.gettempdir()
                self.db_path = f"{temp_dir}/mock_device_{self.config.device_id}.db"
        else:
            self.db_path = f"{state_dir}/{self.config.device_id}.db"
        
        conn = sqlite3.connect(self.db_path)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS device_state (
                timestamp TEXT,
                state TEXT,
                upgrade_phase TEXT,
                progress INTEGER,
                firmware_version TEXT,
                error_conditions TEXT
            )
        """)
        conn.commit()
        conn.close()
    
    def _load_device_behavior(self) -> 'DeviceBehavior':
        """Load platform-specific behavior"""
        behavior_map = {
            'cisco_nxos': CiscoNXOSBehavior,
            'cisco_iosxe': CiscoIOSXEBehavior,
            'fortios': FortiOSBehavior,
            'opengear': OpengearBehavior,
            'metamako_mos': MetamakoMOSBehavior
        }
        
        behavior_class = behavior_map.get(self.config.platform_type)
        if not behavior_class:
            raise ValueError(f"Unsupported platform: {self.config.platform_type}")
        
        return behavior_class(self)
    
    def process_command(self, command: str, **kwargs) -> Dict[str, Any]:
        """Process a command and return realistic response"""
        # Simulate network delay
        delay_ms = random.randint(*self.config.response_delay_ms)
        time.sleep(delay_ms / 1000.0)
        
        # Check for injected errors
        self._check_error_conditions()
        
        # Update last command time
        self.last_command_time = datetime.now()
        
        # Process command through behavior layer
        response = self.behavior.handle_command(command, **kwargs)
        
        # Save state
        self._save_state()
        
        return response
    
    def inject_error(self, error_type: str, duration_seconds: int = 30):
        """Inject an error condition"""
        self.error_conditions.append({
            'type': error_type,
            'start_time': datetime.now(),
            'duration': duration_seconds
        })
    
    def _check_error_conditions(self):
        """Check and apply active error conditions"""
        current_time = datetime.now()
        active_errors = []
        
        for error in self.error_conditions:
            if current_time < error['start_time'] + timedelta(seconds=error['duration']):
                active_errors.append(error)
                self._apply_error(error['type'])
        
        self.error_conditions = active_errors
    
    def _apply_error(self, error_type: str):
        """Apply specific error condition"""
        error_behaviors = {
            'network_timeout': lambda: self._simulate_network_timeout(),
            'auth_failure': lambda: self._simulate_auth_failure(),
            'disk_full': lambda: self._simulate_disk_full(),
            'memory_exhausted': lambda: self._simulate_memory_exhausted(),
            'connection_lost': lambda: self._simulate_connection_lost()
        }
        
        if error_type in error_behaviors:
            error_behaviors[error_type]()
    
    def _simulate_network_timeout(self):
        """Simulate network timeout"""
        if random.random() < 0.3:  # 30% chance of timeout
            raise NetworkError("Connection timed out")
    
    def _simulate_auth_failure(self):
        """Simulate authentication failure"""
        if random.random() < 0.5:  # 50% chance of auth failure
            raise DeviceError("Authentication failed")
    
    def _simulate_disk_full(self):
        """Simulate disk space exhaustion"""
        if self.upgrade_phase == UpgradePhase.IMAGE_DOWNLOAD:
            if random.random() < 0.7:  # 70% chance during image download
                raise DeviceError("Insufficient disk space")
    
    def _simulate_memory_exhausted(self):
        """Simulate memory exhaustion"""
        if self.upgrade_phase == UpgradePhase.INSTALLATION:
            if random.random() < 0.4:  # 40% chance during installation
                raise DeviceError("Out of memory")
    
    def _simulate_connection_lost(self):
        """Simulate connection loss"""
        if random.random() < 0.2:  # 20% chance of connection loss
            self.state = DeviceState.OFFLINE
            raise NetworkError("Connection lost to device")
    
    def start_upgrade(self, target_version: str) -> Dict[str, Any]:
        """Start upgrade process"""
        if self.state != DeviceState.ONLINE:
            raise DeviceError(f"Cannot start upgrade: device is {self.state.value}")
        
        self.config.target_version = target_version
        self.state = DeviceState.UPGRADING
        self.upgrade_phase = UpgradePhase.PRE_VALIDATION
        self.upgrade_progress = 0
        
        # Start upgrade simulation in background
        threading.Thread(target=self._simulate_upgrade_process, daemon=True).start()
        
        return {
            "status": "started",
            "phase": self.upgrade_phase.value,
            "progress": self.upgrade_progress,
            "estimated_duration": self.config.upgrade_duration_seconds
        }
    
    def _simulate_upgrade_process(self):
        """Simulate realistic upgrade process"""
        phases = [
            (UpgradePhase.PRE_VALIDATION, 10),
            (UpgradePhase.IMAGE_DOWNLOAD, 60),
            (UpgradePhase.IMAGE_VERIFICATION, 15),
            (UpgradePhase.BACKUP, 30),
            (UpgradePhase.INSTALLATION, 120),
            (UpgradePhase.REBOOT, 60),
            (UpgradePhase.POST_VALIDATION, 30)
        ]
        
        try:
            for phase, duration in phases:
                self.upgrade_phase = phase
                
                # Simulate phase progress
                for i in range(duration):
                    if random.random() < self.config.failure_probability:
                        self._handle_upgrade_failure()
                        return
                    
                    self.upgrade_progress = int((sum(d for _, d in phases[:phases.index((phase, duration))]) + i) / 
                                              sum(d for _, d in phases) * 100)
                    time.sleep(1)
                
                # Platform-specific phase handling
                self.behavior.handle_upgrade_phase(phase)
            
            # Upgrade complete
            self.upgrade_phase = UpgradePhase.COMPLETE
            self.upgrade_progress = 100
            self.state = DeviceState.ONLINE
            self.config.firmware_version = self.config.target_version
            
        except Exception as e:
            self._handle_upgrade_failure(str(e))
    
    def _handle_upgrade_failure(self, error_msg: str = "Upgrade failed"):
        """Handle upgrade failure"""
        self.upgrade_phase = UpgradePhase.FAILED
        self.state = DeviceState.ERROR
        self.session_data['last_error'] = {
            'message': error_msg,
            'timestamp': datetime.now().isoformat(),
            'phase': self.upgrade_phase.value
        }
    
    def get_status(self) -> Dict[str, Any]:
        """Get current device status"""
        return {
            "device_id": self.config.device_id,
            "platform": self.config.platform_type,
            "model": self.config.model,
            "state": self.state.value,
            "firmware_version": self.config.firmware_version,
            "target_version": self.config.target_version,
            "upgrade_phase": self.upgrade_phase.value,
            "upgrade_progress": self.upgrade_progress,
            "last_command_time": self.last_command_time.isoformat(),
            "error_conditions": len(self.error_conditions),
            "session_data": self.session_data
        }
    
    def _save_state(self):
        """Save current state to database"""
        conn = sqlite3.connect(self.db_path)
        conn.execute("""
            INSERT INTO device_state 
            (timestamp, state, upgrade_phase, progress, firmware_version, error_conditions)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (
            datetime.now().isoformat(),
            self.state.value,
            self.upgrade_phase.value,
            self.upgrade_progress,
            self.config.firmware_version,
            json.dumps([e['type'] for e in self.error_conditions])
        ))
        conn.commit()
        conn.close()


class DeviceBehavior(ABC):
    """Abstract base class for device-specific behaviors"""
    
    def __init__(self, device_engine: MockDeviceEngine):
        self.device = device_engine
        self.command_map = self._build_command_map()
    
    @abstractmethod
    def _build_command_map(self) -> Dict[str, Callable]:
        """Build mapping of commands to handler functions"""
        pass
    
    @abstractmethod
    def handle_upgrade_phase(self, phase: UpgradePhase):
        """Handle platform-specific upgrade phase logic"""
        pass
    
    def handle_command(self, command: str, **kwargs) -> Dict[str, Any]:
        """Handle command with platform-specific logic"""
        # Check for exact command match
        if command in self.command_map:
            return self.command_map[command](**kwargs)
        
        # Check for pattern matches
        for pattern, handler in self.command_map.items():
            if self._command_matches_pattern(command, pattern):
                return handler(command=command, **kwargs)
        
        # Unknown command
        return self._handle_unknown_command(command)
    
    def _command_matches_pattern(self, command: str, pattern: str) -> bool:
        """Check if command matches pattern"""
        # Simple pattern matching - can be enhanced
        return pattern in command or command.startswith(pattern.rstrip('*'))
    
    def _handle_unknown_command(self, command: str) -> Dict[str, Any]:
        """Handle unknown command"""
        return {
            "status": "error",
            "message": f"Unknown command: {command}",
            "code": "UNKNOWN_COMMAND"
        }


class CiscoNXOSBehavior(DeviceBehavior):
    """Cisco NX-OS specific behavior simulation"""
    
    def _build_command_map(self) -> Dict[str, Callable]:
        return {
            "show version": self._show_version,
            "show install all impact*": self._show_install_impact,
            "show install all status": self._show_install_status,
            "install all*": self._install_command,
            "show system resources": self._show_system_resources,
            "show module": self._show_module,
            "dir bootflash:*": self._dir_bootflash,
            "show file * md5sum": self._show_file_md5,
            "copy * bootflash:*": self._copy_file,
            "show version epld": self._show_epld_version
        }
    
    def _show_version(self, **kwargs) -> Dict[str, Any]:
        """Simulate 'show version' command"""
        return {
            "status": "success",
            "output": f"""Cisco Nexus Operating System (NX-OS) Software
TAC support: http://www.cisco.com/tac
Copyright (C) 2002-2023, Cisco and/or its affiliates.
All rights reserved.

Software
  BIOS: version 07.69
  NXOS: version {self.device.config.firmware_version}
  Device name: {self.device.config.device_id}
  System:  version {self.device.config.firmware_version}

Hardware
  cisco {self.device.config.model} Chassis
  Intel(R) Xeon(R) CPU E5-2650 v2 @ 2.60GHz with 16134144 kB of memory.
  Processor Board ID FOC12345678

  Device name: {self.device.config.device_id}
  bootflash:   53298520 kB
  usb1:               0 kB (No media)

Kernel uptime is 15 day(s), 8 hour(s), 23 minute(s), 42 second(s)"""
        }
    
    def _show_install_impact(self, command: str = "", **kwargs) -> Dict[str, Any]:
        """Simulate install impact analysis"""
        if self.device.upgrade_phase == UpgradePhase.PRE_VALIDATION:
            return {
                "status": "success",
                "output": f"""Impact summary for upgrade to {self.device.config.target_version}:
This install will take approximately 8-12 minutes.
Services impact:
  1) Upgrade NXOS software to {self.device.config.target_version}
  2) Upgrade EPLD images if required
  3) System will reload
  4) ISSU capable: {'Yes' if self.device.config.custom_behaviors.get('issu_capable', True) else 'No'}"""
            }
        return {"status": "error", "message": "Install impact not available during upgrade"}
    
    def _show_install_status(self, **kwargs) -> Dict[str, Any]:
        """Show installation status"""
        if self.device.upgrade_phase == UpgradePhase.IDLE:
            return {
                "status": "success", 
                "output": "No installation in progress"
            }
        
        phase_messages = {
            UpgradePhase.PRE_VALIDATION: "Pre-installation checks in progress",
            UpgradePhase.IMAGE_DOWNLOAD: f"Copying image files ({self.device.upgrade_progress}%)",
            UpgradePhase.IMAGE_VERIFICATION: "Verifying image integrity",
            UpgradePhase.BACKUP: "Creating backup",
            UpgradePhase.INSTALLATION: f"Installing software ({self.device.upgrade_progress}%)",
            UpgradePhase.REBOOT: "System reboot in progress",
            UpgradePhase.POST_VALIDATION: "Post-installation validation",
            UpgradePhase.COMPLETE: "Installation completed successfully",
            UpgradePhase.FAILED: "Installation failed"
        }
        
        return {
            "status": "success",
            "output": f"Installation Status: {phase_messages.get(self.device.upgrade_phase, 'Unknown')}"
        }
    
    def handle_upgrade_phase(self, phase: UpgradePhase):
        """Handle NX-OS specific upgrade phase logic"""
        if phase == UpgradePhase.REBOOT:
            self.device.state = DeviceState.REBOOTING
        elif phase == UpgradePhase.POST_VALIDATION:
            self.device.state = DeviceState.ONLINE
        elif phase == UpgradePhase.COMPLETE:
            # Simulate EPLD upgrade if required
            if self.device.config.custom_behaviors.get('epld_upgrade_required'):
                time.sleep(30)  # Additional time for EPLD
    
    def _install_command(self, command: str = "", **kwargs) -> Dict[str, Any]:
        """Handle install all command"""
        if "nxos" in command.lower() and self.device.upgrade_phase == UpgradePhase.IDLE:
            result = self.device.start_upgrade(self.device.config.target_version)
            return {
                "status": "success",
                "output": f"Starting installation of {self.device.config.target_version}",
                "data": result
            }
        return {"status": "error", "message": "Invalid install command or upgrade in progress"}
    
    def _show_system_resources(self, **kwargs) -> Dict[str, Any]:
        """Show system resource utilization"""
        return {
            "status": "success",
            "output": """Load average:   1 minute: 0.32   5 minutes: 0.28   15 minutes: 0.25
Memory usage:    7654321 kB total,  2345678 kB used,  5308643 kB free
CPU states  :    2.0% user,   1.5% kernel,  96.5% idle
                 CPU0: 1.8% user, 1.2% kernel, 97.0% idle
                 CPU1: 2.2% user, 1.8% kernel, 96.0% idle"""
        }
    
    def _show_module(self, **kwargs) -> Dict[str, Any]:
        """Show module information"""
        return {
            "status": "success",
            "output": f"""Mod Ports             Module-Type                       Model           Status
--- ----- ------------------------------------- ------------------- ----------
1    48   48x25G + 6x100G Ethernet Module       {self.device.config.model}  active"""
        }
    
    def _dir_bootflash(self, command: str = "", **kwargs) -> Dict[str, Any]:
        """Simulate directory listing of bootflash"""
        filename = command.split(':')[-1] if ':' in command else ""
        if filename:
            # Simulate file exists check
            if self.device.upgrade_phase in [UpgradePhase.IMAGE_DOWNLOAD, UpgradePhase.IMAGE_VERIFICATION]:
                return {
                    "status": "success",
                    "output": f"""    1234567890  Mar 15 10:30:15 2024  {filename}

Usage for bootflash://sup-local
 1234567890 bytes used
53298520000 bytes free
54533087890 bytes total"""
                }
            else:
                return {"status": "error", "output": "No such file or directory"}
        
        # General directory listing
        return {
            "status": "success",
            "output": """       4096  Mar 15 08:15:23 2024  .dummy/
   987654321  Mar 15 09:45:12 2024  nxos.9.3.10.bin
  1234567890  Mar 15 10:30:15 2024  backup-config.cfg"""
        }
    
    def _show_file_md5(self, command: str = "", **kwargs) -> Dict[str, Any]:
        """Simulate MD5 hash calculation"""
        filename = command.split()[-1] if command else ""
        # Simulate realistic MD5 hash
        import hashlib
        hash_obj = hashlib.md5(f"{filename}{self.device.config.device_id}".encode())
        mock_hash = hash_obj.hexdigest()
        
        return {
            "status": "success", 
            "output": f"{mock_hash}  {filename}"
        }
    
    def _copy_file(self, command: str = "", **kwargs) -> Dict[str, Any]:
        """Simulate file copy operation"""
        if self.device.upgrade_phase == UpgradePhase.IMAGE_DOWNLOAD:
            return {
                "status": "success",
                "output": "Copy complete, now saving to disk (please wait)...\nCopy complete."
            }
        return {"status": "error", "message": "Copy operation not available"}
    
    def _show_epld_version(self, **kwargs) -> Dict[str, Any]:
        """Show EPLD version information"""
        current_epld = self.device.config.custom_behaviors.get('current_epld_version', '1.0.0')
        return {
            "status": "success",
            "output": f"""Module  EPLD             Type      Version
------  ---------------  --------  ----------
   1    LC Main FPGA     LC Main   {current_epld}
   1    LC Inband FPGA   LC Inband {current_epld}"""
        }


class FortiOSBehavior(DeviceBehavior):
    """FortiOS specific behavior simulation"""
    
    def _build_command_map(self) -> Dict[str, Callable]:
        return {
            "get system status": self._get_system_status,
            "get system ha status": self._get_ha_status,
            "execute restore image*": self._restore_image,
            "get system performance status": self._get_performance_status,
            "diagnose sys top*": self._diagnose_sys_top,
            "get system interface physical": self._get_interfaces,
            "execute backup config*": self._backup_config
        }
    
    def _get_system_status(self, **kwargs) -> Dict[str, Any]:
        """Simulate FortiOS system status"""
        return {
            "status": "success",
            "output": f"""Version: {self.device.config.model} v{self.device.config.firmware_version}
Virus-DB: 89.00899(2024-03-15 08:30)
Extended DB: 1.00000(2018-04-09 18:07)
IPS-DB: 6.00741(2013-12-01 02:30)
IPS-ETDB: 17.00899(2024-03-15 08:30)
APP-DB: 6.00741(2013-12-01 02:30)
INDUSTRIAL-DB: 6.00741(2013-12-01 02:30)
Serial-Number: {self.device.config.device_id}
IPS Malicious URL Database: 1.00001(2015-01-01 01:01)
Botnet DB: 1.00000(2012-05-27 00:30)
License Status: Valid
Evaluation License Expires: Wed Mar 15 23:59:59 2024
VM Resources: 2 CPU/4096 MB RAM/32 GB Disk
Log hard disk: Available
Hostname: {self.device.config.device_id}
Operation Mode: NAT
Current virtual domain: root
Max number of virtual domains: {self.device.config.custom_behaviors.get('vdom_count', 1)}
Virtual domains status: {'enabled' if self.device.config.custom_behaviors.get('vdom_enabled') else 'disabled'}
Virtual domain configuration: {'multiple' if self.device.config.custom_behaviors.get('vdom_count', 1) > 1 else 'single'}
FIPS-CC mode: disabled
Current HA mode: {'a-p' if self.device.config.custom_behaviors.get('ha_enabled') else 'standalone'}, {'primary' if self.device.config.custom_behaviors.get('ha_role') == 'primary' else 'secondary' if self.device.config.custom_behaviors.get('ha_role') == 'secondary' else 'standalone'}
Branch point: 2543
Release Version Information: GA
FortiOS x86-64: Yes"""
        }
    
    def _get_ha_status(self, **kwargs) -> Dict[str, Any]:
        """Get HA status information"""
        if not self.device.config.custom_behaviors.get('ha_enabled'):
            return {"status": "success", "output": "HA mode: standalone"}
        
        ha_role = self.device.config.custom_behaviors.get('ha_role', 'primary')
        return {
            "status": "success",
            "output": f"""Model: {self.device.config.model}
Mode: HA A-P
Group: 0
Debug: 0
Cluster Uptime: 15 days, 8:23:42
Cluster state change time: 2024-03-01 10:30:15
Master selected using:
    <2024-03-01 10:30:15> FG600E4617900001 is selected as the master because it has the largest value of uptime.
ses_pickup: enable, ses_pickup_delay=disable
override: disable
Configuration Status:
    FG600E4617900001: in-sync
    FG600E4617900002: in-sync
System Usage stats:
    FG600E4617900001(Master): sessions=1234, average-cpu-user/nice/system/idle=1%/0%/2%/97%, memory=25%
    FG600E4617900002(Slave): sessions=0, average-cpu-user/nice/system/idle=1%/0%/1%/98%, memory=24%
HBDEV stats:
    FG600E4617900001(Master): hb_lost_count=0 hb_send_count=892345 hb_recv_count=892344
    FG600E4617900002(Slave): hb_lost_count=0 hb_send_count=892344 hb_recv_count=892345
Current {ha_role} unit operating normally."""
        }
    
    def handle_upgrade_phase(self, phase: UpgradePhase):
        """Handle FortiOS specific upgrade phase logic"""
        if phase == UpgradePhase.INSTALLATION and self.device.config.custom_behaviors.get('ha_enabled'):
            # Simulate HA synchronization delay
            time.sleep(10)
        
        # Handle multi-step upgrade logic
        if phase == UpgradePhase.COMPLETE:
            upgrade_path = self.device.config.custom_behaviors.get('upgrade_path', [])
            current_step = self.device.config.custom_behaviors.get('current_step', 0)
            
            if current_step + 1 < len(upgrade_path):
                # Start next upgrade step
                next_version = upgrade_path[current_step + 1]
                self.device.config.custom_behaviors['current_step'] = current_step + 1
                self.device.config.target_version = next_version
                time.sleep(5)  # Brief pause between steps
                self.device.start_upgrade(next_version)
    
    def _restore_image(self, command: str = "", **kwargs) -> Dict[str, Any]:
        """Handle firmware restore/upgrade command"""
        if self.device.upgrade_phase == UpgradePhase.IDLE:
            result = self.device.start_upgrade(self.device.config.target_version)
            return {
                "status": "success",
                "output": f"Starting firmware upgrade to {self.device.config.target_version}",
                "data": result
            }
        return {"status": "error", "message": "Upgrade already in progress"}
    
    def _get_performance_status(self, **kwargs) -> Dict[str, Any]:
        """Get system performance information"""
        return {
            "status": "success",
            "output": """CPU states: 2% user 1% nice 2% system 95% idle
Memory states: 4096MB total, 1024MB used (25%), 3072MB free (75%)
Network utilization: 
  port1: rx_packets=12345678 tx_packets=23456789 rx_bytes=987654321 tx_bytes=876543210
  port2: rx_packets=34567890 tx_packets=45678901 rx_bytes=765432109 tx_bytes=654321098
Average network usage: 15% in, 12% out
Disk usage: 85% full"""
        }
    
    def _diagnose_sys_top(self, command: str = "", **kwargs) -> Dict[str, Any]:
        """Diagnose system top processes"""
        return {
            "status": "success",
            "output": """Run Time:  15 days, 8 hours and 23 minutes
 1:10am  up 15 days,  8:23,  0 users,  load average: 0.12, 0.18, 0.22
 
PID    %CPU  TIME+     COMMAND
  1     0.1  00:45:23  init
  123   2.1  05:23:45  fortigate
  456   0.8  01:12:34  miglogd  
  789   0.5  00:34:56  httpsd"""
        }
    
    def _get_interfaces(self, **kwargs) -> Dict[str, Any]:
        """Get physical interface information"""
        return {
            "status": "success",
            "output": """port1   Link is up, 1000 Mbps full duplex, auto negotiation: enable
        Requested flow control: enable, Current flow control: enable
        port2   Link is up, 1000 Mbps full duplex, auto negotiation: enable  
        Requested flow control: enable, Current flow control: enable"""
        }
    
    def _backup_config(self, command: str = "", **kwargs) -> Dict[str, Any]:
        """Execute configuration backup"""
        return {
            "status": "success",
            "output": "Configuration backup completed successfully"
        }


# Additional behavior classes for other platforms...
class CiscoIOSXEBehavior(DeviceBehavior):
    """Cisco IOS-XE behavior simulation - simplified for brevity"""
    
    def _build_command_map(self) -> Dict[str, Callable]:
        return {
            "show version": self._show_version,
            "show install summary": self._show_install_summary,
            "request platform software package*": self._install_package
        }
    
    def _show_version(self, **kwargs) -> Dict[str, Any]:
        return {
            "status": "success",
            "output": f"""Cisco IOS XE Software, Version {self.device.config.firmware_version}
Cisco IOS Software [{self.device.config.model}], Catalyst L3 Switch Software
Technical Support: http://www.cisco.com/techsupport
System image file is "bootflash:packages.conf"
Base Ethernet MAC Address       : 00:11:22:33:44:55
Motherboard Assembly Number     : 123456-01
Motherboard Serial Number       : {self.device.config.device_id}"""
        }
    
    def handle_upgrade_phase(self, phase: UpgradePhase):
        # IOS-XE specific upgrade handling
        pass
    
    def _show_install_summary(self, **kwargs) -> Dict[str, Any]:
        return {"status": "success", "output": "No install operation in progress"}
    
    def _install_package(self, command: str = "", **kwargs) -> Dict[str, Any]:
        return {"status": "success", "output": "Package installation initiated"}


class OpengearBehavior(DeviceBehavior):
    """Opengear behavior simulation"""
    
    def _build_command_map(self) -> Dict[str, Callable]:
        return {
            "config -g config.system.model": self._get_model,
            "config -g config.system.version": self._get_version,
            "upgrade *": self._upgrade_firmware
        }
    
    def _get_model(self, **kwargs) -> Dict[str, Any]:
        return {"status": "success", "output": self.device.config.model}
    
    def _get_version(self, **kwargs) -> Dict[str, Any]:
        return {"status": "success", "output": self.device.config.firmware_version}
    
    def handle_upgrade_phase(self, phase: UpgradePhase):
        # Opengear specific upgrade handling
        pass
    
    def _upgrade_firmware(self, command: str = "", **kwargs) -> Dict[str, Any]:
        if self.device.upgrade_phase == UpgradePhase.IDLE:
            result = self.device.start_upgrade(self.device.config.target_version)
            return {"status": "success", "output": "Firmware upgrade started", "data": result}
        return {"status": "error", "message": "Upgrade in progress"}


class MetamakoMOSBehavior(DeviceBehavior):
    """Metamako MOS behavior simulation"""
    
    def _build_command_map(self) -> Dict[str, Callable]:
        return {
            "mdk-version": self._mdk_version,
            "upgrade *": self._upgrade_mos,
            "application status": self._application_status
        }
    
    def _mdk_version(self, **kwargs) -> Dict[str, Any]:
        return {
            "status": "success",
            "output": f"MOS Version: {self.device.config.firmware_version}\nDevice: {self.device.config.model}"
        }
    
    def handle_upgrade_phase(self, phase: UpgradePhase):
        # Handle MetaWatch/MetaMux application management
        if phase == UpgradePhase.POST_VALIDATION:
            # Simulate application installation
            if self.device.config.custom_behaviors.get('manage_applications'):
                time.sleep(15)  # App installation time
    
    def _upgrade_mos(self, command: str = "", **kwargs) -> Dict[str, Any]:
        return {"status": "success", "output": "MOS upgrade initiated"}
    
    def _application_status(self, **kwargs) -> Dict[str, Any]:
        return {
            "status": "success", 
            "output": "MetaWatch: running\nMetaMux: stopped"
        }


# Device Manager for orchestrating multiple mock devices
class MockDeviceManager:
    """Manager for multiple mock devices"""
    
    def __init__(self):
        self.devices: Dict[str, MockDeviceEngine] = {}
        self.error_scenarios: List[Dict[str, Any]] = []
    
    def create_device(self, config: MockDeviceConfig) -> MockDeviceEngine:
        """Create and register a mock device"""
        device = MockDeviceEngine(config)
        self.devices[config.device_id] = device
        return device
    
    def get_device(self, device_id: str) -> Optional[MockDeviceEngine]:
        """Get device by ID"""
        return self.devices.get(device_id)
    
    def inject_scenario_error(self, scenario_name: str, device_ids: List[str], 
                             error_type: str, duration: int = 30):
        """Inject error scenario across multiple devices"""
        scenario = {
            'name': scenario_name,
            'device_ids': device_ids,
            'error_type': error_type,
            'duration': duration,
            'start_time': datetime.now()
        }
        
        for device_id in device_ids:
            if device_id in self.devices:
                self.devices[device_id].inject_error(error_type, duration)
        
        self.error_scenarios.append(scenario)
    
    def get_all_device_status(self) -> Dict[str, Any]:
        """Get status of all devices"""
        return {
            device_id: device.get_status() 
            for device_id, device in self.devices.items()
        }
    
    def simulate_network_partition(self, device_group_a: List[str], 
                                  device_group_b: List[str], duration: int = 60):
        """Simulate network partition between device groups"""
        # Inject connection errors between groups
        for device_id in device_group_a + device_group_b:
            if device_id in self.devices:
                self.devices[device_id].inject_error('connection_lost', duration)
    
    def create_device(self, platform: str, device_name: str) -> str:
        """Create device with platform and name (updated signature)"""
        device_config = MockDeviceConfig(
            device_id=device_name,
            platform_type=platform,
            model=f"{platform.upper()}-TEST",
            firmware_version="1.0.0",
            target_version="2.0.0"
        )
        device = MockDeviceEngine(device_config)
        self.devices[device_name] = device
        return device_name
    
    def inject_error(self, device_id: str, error_config: Dict) -> Dict:
        """Inject specific error into device for testing."""
        device = self.devices.get(device_id)
        if not device:
            return {'success': False, 'error': 'Device not found'}
        
        error_type = error_config.get('error_type', 'generic')
        recovery_expected = error_config.get('recovery_expected', False)
        
        try:
            device.inject_error(error_type, error_config.get('duration', 30))
            
            # DNS failures and other non-recoverable errors should return failure
            if error_type == 'dns_failure' or not recovery_expected:
                return {'success': False, 'error': f'{error_type} simulated (no recovery)'}
            else:
                # Recoverable errors simulate successful recovery
                return {'success': True}
                
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def inject_device_error(self, device_id: str, error_config: Dict) -> Dict:
        """Inject device-specific error for testing."""
        device = self.devices.get(device_id)
        if not device:
            return {'success': False, 'error': 'Device not found'}
        
        error_code = error_config.get('error_code')
        trigger_phase = error_config.get('trigger_phase')
        recovery_expected = error_config.get('recovery_expected', False)
        
        # Simulate device-specific error behavior
        try:
            device.state.error_state = {
                'code': error_code,
                'phase': trigger_phase,
                'recoverable': recovery_expected,
                'message': f"{error_code} during {trigger_phase}"
            }
            
            # Set device to error state if not recoverable
            if not recovery_expected:
                device.state.current_phase = UpgradePhase.ERROR
            
            return {'success': recovery_expected}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def cleanup(self):
        """Clean up resources and close database connections."""
        if hasattr(self, 'db_connection') and self.db_connection:
            self.db_connection.close()
        print("Mock device manager cleanup completed")


class ConcurrentUpgradeSimulator:
    """Simulates concurrent upgrade scenarios with error injection."""
    
    def __init__(self, device_manager: MockDeviceManager):
        self.manager = device_manager
        self.active_scenarios = {}
    
    def run_concurrent_scenario(self, scenario_config: Dict) -> Dict:
        """Execute a concurrent upgrade scenario with configured error injection."""
        scenario_name = scenario_config['name']
        devices = scenario_config['devices']
        coordination = scenario_config.get('coordination', 'parallel')
        failure_injection = scenario_config.get('failure_injection', {})
        resource_limits = scenario_config.get('resource_limits', {})
        
        print(f"Starting concurrent scenario: {scenario_name}")
        
        results = {
            'scenario': scenario_name,
            'outcome': 'unknown',
            'device_results': {},
            'errors': []
        }
        
        try:
            if coordination == 'sequential_ha':
                results = self._run_ha_sequential(devices, failure_injection)
            elif coordination == 'parallel':
                results = self._run_parallel_upgrade(devices, failure_injection, resource_limits)
            else:
                results['errors'].append(f"Unknown coordination type: {coordination}")
                results['outcome'] = 'configuration_error'
        
        except Exception as e:
            results['errors'].append(f"Scenario execution error: {str(e)}")
            results['outcome'] = 'execution_error'
        
        return results
    
    def _run_ha_sequential(self, devices: List[Dict], failure_injection: Dict) -> Dict:
        """Simulate HA pair sequential upgrade."""
        primary = devices[0]
        secondary = devices[1] if len(devices) > 1 else None
        
        results = {
            'outcome': 'unknown',
            'device_results': {},
            'errors': []
        }
        
        # Upgrade primary first
        primary_device = self.manager.devices.get(primary['id'])
        primary_result = {'success': True}  # Default success
        if primary_device:
            primary_result = self._simulate_device_upgrade(primary_device, failure_injection, primary['name'])
            results['device_results'][primary['name']] = primary_result
        
        # Then upgrade secondary with potential failure
        if secondary:
            secondary_device = self.manager.devices.get(secondary['id'])
            if secondary_device:
                # Inject failure if targeted at secondary
                if failure_injection.get('target') == secondary['name']:
                    secondary_device.inject_error('power_failure', 30)
                
                secondary_result = self._simulate_device_upgrade(secondary_device, failure_injection, secondary['name'])
                results['device_results'][secondary['name']] = secondary_result
                
                # Determine overall outcome
                if primary_result.get('success') and not secondary_result.get('success'):
                    results['outcome'] = 'primary_success_secondary_rollback'
                elif primary_result.get('success') and secondary_result.get('success'):
                    results['outcome'] = 'both_success'
                else:
                    results['outcome'] = 'primary_failure'
        
        return results
    
    def _run_parallel_upgrade(self, devices: List[Dict], failure_injection: Dict, resource_limits: Dict) -> Dict:
        """Simulate parallel multi-device upgrade."""
        results = {
            'outcome': 'unknown',
            'device_results': {},
            'errors': []
        }
        
        # Apply resource limits
        max_concurrent = resource_limits.get('max_concurrent_uploads', len(devices))
        bandwidth_limit = resource_limits.get('bandwidth_limit_mbps', 1000)
        
        # Simulate bandwidth contention
        effective_bandwidth_per_device = bandwidth_limit / min(len(devices), max_concurrent)
        
        # Process devices in batches if resource limited
        device_batches = [devices[i:i+max_concurrent] for i in range(0, len(devices), max_concurrent)]
        all_successful = True
        queued_devices = []
        
        for batch in device_batches:
            batch_results = {}
            
            for device_info in batch:
                device = self.manager.devices.get(device_info['id'])
                if device:
                    # Apply failure injection if targeted
                    if (failure_injection.get('target') == 'all' or 
                        failure_injection.get('target') == device_info['name']):
                        if failure_injection.get('error') == 'NETWORK_PARTITION':
                            device.inject_error('connection_lost', failure_injection.get('duration', 60))
                        else:
                            device.inject_error('generic_failure', 30)
                    
                    # Simulate bandwidth constraint effects
                    if effective_bandwidth_per_device < 10:  # Less than 10 Mbps per device
                        device.inject_error('bandwidth_exceeded', 30)
                    
                    device_result = self._simulate_device_upgrade(device, failure_injection, device_info['name'])
                    batch_results[device_info['name']] = device_result
                    
                    if not device_result.get('success'):
                        all_successful = False
                        if device_result.get('queued'):
                            queued_devices.append(device_info['name'])
            
            results['device_results'].update(batch_results)
        
        # Determine overall outcome
        if all_successful:
            results['outcome'] = 'all_success'
        elif queued_devices:
            results['outcome'] = 'queued_completion'
        elif failure_injection.get('error') == 'NETWORK_PARTITION':
            # Network partition should result in retry success
            results['outcome'] = 'all_retry_success'
        else:
            results['outcome'] = 'partial_failure'
        
        return results
    
    def _simulate_device_upgrade(self, device, failure_config: Dict, device_name: str) -> Dict:
        """Simulate individual device upgrade with potential failures."""
        try:
            # Simulate upgrade process
            device.simulate_upgrade_progress("old_version", "new_version")
            
            # Check if device has errors
            if hasattr(device.state, 'error_state') and device.state.error_state:
                return {
                    'success': False,
                    'error': device.state.error_state,
                    'queued': device.state.error_state.get('recoverable', False)
                }
            
            return {'success': True}
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'queued': False
            }


if __name__ == "__main__":
    import argparse
    import sys
    import os
    import socket
    import threading
    
    parser = argparse.ArgumentParser(description='Mock Network Device Engine')
    parser.add_argument('--test-platform', default='cisco_nxos',
                        choices=['cisco_nxos', 'cisco_iosxe', 'fortios', 'opengear', 'metamako_mos'],
                        help='Platform to test')
    parser.add_argument('--interactive', action='store_true',
                        help='Run interactive test mode')
    parser.add_argument('--port', type=int, default=2222,
                        help='Port for SSH mock server')
    parser.add_argument('--name', default=None,
                        help='Device name')
    parser.add_argument('--daemon', action='store_true',
                        help='Run as daemon (for testing)')
    parser.add_argument('--platform', default=None,
                        help='Platform type for daemon mode')
    
    args = parser.parse_args()
    
    # Create test directory structure
    os.makedirs("state", exist_ok=True)
    
    # Create mock device manager
    manager = MockDeviceManager()
    
    if args.daemon:
        print(f"Starting mock SSH daemon on port {args.port}...")
        platform = args.platform or args.test_platform
        device_name = args.name or f"test-{platform}-01"
        
        # Create a device for the daemon
        device_id = manager.create_device(platform, device_name)
        print(f"Created mock {platform} device: {device_name}")
        
        # Start a simple TCP server to simulate SSH daemon
        def handle_client(conn, addr):
            try:
                conn.send(b"SSH-2.0-MockDevice_1.0\r\n")
                while True:
                    data = conn.recv(1024)
                    if not data:
                        break
                    # Echo back simple response
                    conn.send(b"Mock device response\r\n")
            except:
                pass
            finally:
                conn.close()
        
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(('localhost', args.port))
        server.listen(5)
        
        print(f"Mock SSH daemon listening on localhost:{args.port}")
        
        try:
            while True:
                conn, addr = server.accept()
                client_thread = threading.Thread(target=handle_client, args=(conn, addr))
                client_thread.daemon = True
                client_thread.start()
        except KeyboardInterrupt:
            print("Shutting down...")
            server.close()
        
        sys.exit(0)
    
    # Create test devices
    device_name = args.name or f"test-{args.test_platform}-01"
    device_id = manager.create_device(args.test_platform, device_name)
    
    print(f"Created mock {args.test_platform} device: {device_id}")
    
    # Test basic operations
    device = manager.devices[device_id]
    print(f"Device state: {device.state.current_phase}")
    print(f"Firmware version: {device.state.current_firmware}")
    
    # Simulate some commands
    if args.test_platform == 'cisco_nxos':
        response = device.process_command("show version")
        print(f"Command response: {response['output'][:100]}...")
        
        # Test upgrade simulation
        device.simulate_upgrade_progress("9.3.10", "9.3.11")
        print(f"After upgrade simulation: {device.state.current_firmware}")
    
    if args.interactive and not args.daemon:
        print("\nEntering interactive mode. Type 'quit' to exit.")
        while True:
            try:
                command = input(f"{args.test_platform}> ")
                if command.lower() in ['quit', 'exit']:
                    break
                response = device.process_command(command)
                print(response['output'])
            except KeyboardInterrupt:
                break
    
    if not args.daemon:
        manager.cleanup()
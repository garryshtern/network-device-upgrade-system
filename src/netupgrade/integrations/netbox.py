"""NetBox integration for dynamic inventory and device management."""

import logging
from typing import Dict, List, Optional
import pynetbox
from netupgrade.models.device import Device, DevicePlatform, DeviceState


logger = logging.getLogger(__name__)


class NetBoxClient:
    """NetBox API client for device inventory management."""
    
    def __init__(self, url: str, token: str, verify_ssl: bool = True):
        self.url = url
        self.token = token
        self.verify_ssl = verify_ssl
        self.api = None
        self._connect()
    
    def _connect(self) -> None:
        """Initialize NetBox API connection."""
        try:
            self.api = pynetbox.api(self.url, token=self.token)
            if not self.verify_ssl:
                self.api.http_session.verify = False
            logger.info(f"Connected to NetBox at {self.url}")
        except Exception as e:
            logger.error(f"Failed to connect to NetBox: {e}")
            raise
    
    def get_devices(self, site: Optional[str] = None, platform: Optional[str] = None, 
                   tag: Optional[str] = None) -> List[Device]:
        """Retrieve devices from NetBox inventory."""
        if not self.api:
            raise RuntimeError("NetBox API not connected")
        
        devices = []
        filters = {}
        
        if site:
            filters['site'] = site
        if platform:
            filters['platform'] = platform
        if tag:
            filters['tag'] = tag
        
        try:
            nb_devices = self.api.dcim.devices.filter(**filters)
            
            for nb_device in nb_devices:
                # Map NetBox device to our Device model
                device_platform = self._map_platform(nb_device.platform.slug if nb_device.platform else "unknown")
                device_state = self._map_device_state(nb_device.status.value if nb_device.status else "unknown")
                
                # Get primary IP
                primary_ip = None
                if nb_device.primary_ip:
                    primary_ip = str(nb_device.primary_ip).split('/')[0]  # Remove CIDR notation
                elif nb_device.primary_ip4:
                    primary_ip = str(nb_device.primary_ip4).split('/')[0]
                
                if not primary_ip:
                    logger.warning(f"Device {nb_device.name} has no primary IP address")
                    continue
                
                # Extract firmware version from custom fields or comments
                current_firmware = None
                if hasattr(nb_device, 'custom_fields') and nb_device.custom_fields:
                    current_firmware = nb_device.custom_fields.get('firmware_version')
                
                # Get device tags
                tags = [tag.name for tag in nb_device.tags] if nb_device.tags else []
                
                device = Device(
                    id=str(nb_device.id),
                    name=nb_device.name,
                    platform=device_platform,
                    management_ip=primary_ip,
                    site=nb_device.site.name if nb_device.site else "unknown",
                    vendor=nb_device.device_type.manufacturer.name if nb_device.device_type and nb_device.device_type.manufacturer else "unknown",
                    model=nb_device.device_type.model if nb_device.device_type else "unknown",
                    current_firmware=current_firmware,
                    state=device_state,
                    tags=tags
                )
                
                devices.append(device)
                
            logger.info(f"Retrieved {len(devices)} devices from NetBox")
            return devices
            
        except Exception as e:
            logger.error(f"Failed to retrieve devices from NetBox: {e}")
            raise
    
    def update_device_firmware(self, device_id: str, firmware_version: str) -> bool:
        """Update device firmware version in NetBox."""
        if not self.api:
            raise RuntimeError("NetBox API not connected")
        
        try:
            device = self.api.dcim.devices.get(device_id)
            if not device:
                logger.error(f"Device {device_id} not found in NetBox")
                return False
            
            # Update custom field for firmware version
            if not device.custom_fields:
                device.custom_fields = {}
            device.custom_fields['firmware_version'] = firmware_version
            device.save()
            
            logger.info(f"Updated firmware version for device {device.name} to {firmware_version}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to update device firmware in NetBox: {e}")
            return False
    
    def update_device_state(self, device_id: str, state: DeviceState) -> bool:
        """Update device operational state in NetBox."""
        if not self.api:
            raise RuntimeError("NetBox API not connected")
        
        try:
            device = self.api.dcim.devices.get(device_id)
            if not device:
                logger.error(f"Device {device_id} not found in NetBox")
                return False
            
            # Map our state to NetBox status
            nb_status = self._map_state_to_netbox(state)
            device.status = nb_status
            device.save()
            
            logger.info(f"Updated state for device {device.name} to {state}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to update device state in NetBox: {e}")
            return False
    
    def add_device_comment(self, device_id: str, comment: str) -> bool:
        """Add comment to device in NetBox."""
        if not self.api:
            raise RuntimeError("NetBox API not connected")
        
        try:
            device = self.api.dcim.devices.get(device_id)
            if not device:
                logger.error(f"Device {device_id} not found in NetBox")
                return False
            
            existing_comments = device.comments or ""
            updated_comments = f"{existing_comments}\\n{comment}" if existing_comments else comment
            device.comments = updated_comments
            device.save()
            
            logger.info(f"Added comment to device {device.name}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to add comment to device in NetBox: {e}")
            return False
    
    def get_device_by_name(self, name: str) -> Optional[Device]:
        """Get single device by hostname."""
        devices = self.get_devices()
        for device in devices:
            if device.name == name:
                return device
        return None
    
    def get_devices_by_site(self, site_name: str) -> List[Device]:
        """Get all devices for a specific site."""
        return self.get_devices(site=site_name)
    
    def get_devices_by_platform(self, platform: DevicePlatform) -> List[Device]:
        """Get all devices for a specific platform."""
        platform_mapping = {
            DevicePlatform.CISCO_NXOS: ["nxos", "cisco-nxos"],
            DevicePlatform.CISCO_IOSXE: ["iosxe", "cisco-iosxe", "ios-xe"],
            DevicePlatform.METAMAKO_MOS: ["mos", "metamako"],
            DevicePlatform.OPENGEAR: ["opengear"],
            DevicePlatform.FORTIOS: ["fortios", "fortigate"]
        }
        
        platform_slugs = platform_mapping.get(platform, [platform.value])
        
        devices = []
        for slug in platform_slugs:
            devices.extend(self.get_devices(platform=slug))
        
        return devices
    
    def _map_platform(self, netbox_platform: str) -> DevicePlatform:
        """Map NetBox platform slug to our DevicePlatform enum."""
        mapping = {
            "nxos": DevicePlatform.CISCO_NXOS,
            "cisco-nxos": DevicePlatform.CISCO_NXOS,
            "iosxe": DevicePlatform.CISCO_IOSXE,
            "cisco-iosxe": DevicePlatform.CISCO_IOSXE,
            "ios-xe": DevicePlatform.CISCO_IOSXE,
            "mos": DevicePlatform.METAMAKO_MOS,
            "metamako": DevicePlatform.METAMAKO_MOS,
            "opengear": DevicePlatform.OPENGEAR,
            "fortios": DevicePlatform.FORTIOS,
            "fortigate": DevicePlatform.FORTIOS
        }
        
        return mapping.get(netbox_platform.lower(), DevicePlatform.CISCO_IOSXE)  # Default fallback
    
    def _map_device_state(self, netbox_status: str) -> DeviceState:
        """Map NetBox device status to our DeviceState enum."""
        mapping = {
            "active": DeviceState.ONLINE,
            "offline": DeviceState.OFFLINE,
            "planned": DeviceState.OFFLINE,
            "staged": DeviceState.OFFLINE,
            "failed": DeviceState.FAILED,
            "inventory": DeviceState.OFFLINE,
            "decommissioning": DeviceState.OFFLINE
        }
        
        return mapping.get(netbox_status.lower(), DeviceState.UNKNOWN)
    
    def _map_state_to_netbox(self, state: DeviceState) -> str:
        """Map our DeviceState to NetBox status value."""
        mapping = {
            DeviceState.ONLINE: "active",
            DeviceState.OFFLINE: "offline", 
            DeviceState.MAINTENANCE: "offline",
            DeviceState.UPGRADING: "active",
            DeviceState.FAILED: "failed",
            DeviceState.UNKNOWN: "offline"
        }
        
        return mapping.get(state, "offline")
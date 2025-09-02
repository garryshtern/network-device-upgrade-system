"""Device models for network equipment management."""

from enum import Enum
from typing import Dict, List, Optional
from pydantic import BaseModel, Field, IPvAnyAddress


class DevicePlatform(str, Enum):
    """Supported network device platforms."""
    
    CISCO_NXOS = "cisco_nxos"
    CISCO_IOSXE = "cisco_iosxe" 
    METAMAKO_MOS = "metamako_mos"
    OPENGEAR = "opengear"
    FORTIOS = "fortios"


class DeviceState(str, Enum):
    """Device operational states."""
    
    ONLINE = "online"
    OFFLINE = "offline"
    MAINTENANCE = "maintenance"
    UPGRADING = "upgrading"
    FAILED = "failed"
    UNKNOWN = "unknown"


class Device(BaseModel):
    """Network device representation."""
    
    id: str = Field(..., description="Unique device identifier")
    name: str = Field(..., description="Device hostname")
    platform: DevicePlatform = Field(..., description="Device platform type")
    management_ip: IPvAnyAddress = Field(..., description="Management IP address")
    site: str = Field(..., description="Site/location identifier")
    vendor: str = Field(..., description="Device vendor")
    model: str = Field(..., description="Device model")
    current_firmware: Optional[str] = Field(None, description="Current firmware version")
    target_firmware: Optional[str] = Field(None, description="Target firmware version") 
    state: DeviceState = Field(default=DeviceState.UNKNOWN, description="Current device state")
    last_seen: Optional[str] = Field(None, description="Last successful contact timestamp")
    credentials: Dict[str, str] = Field(default_factory=dict, description="Access credentials")
    tags: List[str] = Field(default_factory=list, description="Device tags")
    
    class Config:
        use_enum_values = True


class DeviceInventory(BaseModel):
    """Collection of network devices."""
    
    devices: List[Device] = Field(default_factory=list, description="List of devices")
    total_count: int = Field(default=0, description="Total device count")
    by_platform: Dict[str, int] = Field(default_factory=dict, description="Count by platform")
    by_site: Dict[str, int] = Field(default_factory=dict, description="Count by site")
    by_state: Dict[str, int] = Field(default_factory=dict, description="Count by state")
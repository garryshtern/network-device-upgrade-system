"""Configuration management utilities."""

import os
import yaml
from pathlib import Path
from typing import Dict, Any, Optional
from pydantic import BaseModel


class DatabaseConfig(BaseModel):
    """Database configuration."""
    url: str = "sqlite:///network_upgrade.db"
    echo: bool = False


class NetBoxConfig(BaseModel):
    """NetBox integration configuration."""
    url: str
    token: str
    verify_ssl: bool = True


class InfluxDBConfig(BaseModel):
    """InfluxDB configuration."""
    url: str
    token: str
    org: str
    bucket: str = "network-upgrades"


class AWXConfig(BaseModel):
    """AWX configuration."""
    url: str
    username: str
    password: str
    verify_ssl: bool = True


class SystemConfig(BaseModel):
    """Main system configuration."""
    firmware_directory: str = "/var/lib/network-upgrade/firmware"
    log_level: str = "INFO"
    max_concurrent_jobs: int = 50
    default_job_timeout: int = 3600  # 1 hour
    
    database: DatabaseConfig = DatabaseConfig()
    netbox: Optional[NetBoxConfig] = None
    influxdb: Optional[InfluxDBConfig] = None
    awx: Optional[AWXConfig] = None


class ConfigManager:
    """Configuration file manager."""
    
    DEFAULT_CONFIG_PATHS = [
        "/etc/network-upgrade/config.yaml",
        "~/.config/network-upgrade/config.yaml",
        "./config.yaml"
    ]
    
    def __init__(self, config_path: Optional[str] = None):
        self.config_path = config_path
        self.config = SystemConfig()
        self._load_config()
    
    def _find_config_file(self) -> Optional[Path]:
        """Find configuration file in default locations."""
        if self.config_path:
            path = Path(self.config_path).expanduser()
            if path.exists():
                return path
        
        for config_path in self.DEFAULT_CONFIG_PATHS:
            path = Path(config_path).expanduser()
            if path.exists():
                return path
        
        return None
    
    def _load_config(self) -> None:
        """Load configuration from file."""
        config_file = self._find_config_file()
        
        if not config_file:
            # Use defaults and environment variables
            self._load_from_environment()
            return
        
        try:
            with open(config_file, 'r') as f:
                config_data = yaml.safe_load(f)
            
            if config_data:
                self.config = SystemConfig(**config_data)
            
            # Override with environment variables
            self._load_from_environment()
            
        except Exception as e:
            raise RuntimeError(f"Failed to load configuration from {config_file}: {e}")
    
    def _load_from_environment(self) -> None:
        """Override configuration with environment variables."""
        
        # System settings
        if os.getenv('FIRMWARE_DIRECTORY'):
            self.config.firmware_directory = os.getenv('FIRMWARE_DIRECTORY')
        
        if os.getenv('LOG_LEVEL'):
            self.config.log_level = os.getenv('LOG_LEVEL')
        
        if os.getenv('MAX_CONCURRENT_JOBS'):
            self.config.max_concurrent_jobs = int(os.getenv('MAX_CONCURRENT_JOBS'))
        
        # Database configuration
        if os.getenv('DATABASE_URL'):
            self.config.database.url = os.getenv('DATABASE_URL')
        
        # NetBox configuration
        netbox_url = os.getenv('NETBOX_URL')
        netbox_token = os.getenv('NETBOX_TOKEN')
        if netbox_url and netbox_token:
            self.config.netbox = NetBoxConfig(
                url=netbox_url,
                token=netbox_token,
                verify_ssl=os.getenv('NETBOX_VERIFY_SSL', 'true').lower() == 'true'
            )
        
        # InfluxDB configuration
        influx_url = os.getenv('INFLUXDB_URL')
        influx_token = os.getenv('INFLUXDB_TOKEN')
        influx_org = os.getenv('INFLUXDB_ORG')
        if all([influx_url, influx_token, influx_org]):
            self.config.influxdb = InfluxDBConfig(
                url=influx_url,
                token=influx_token,
                org=influx_org,
                bucket=os.getenv('INFLUXDB_BUCKET', 'network-upgrades')
            )
        
        # AWX configuration
        awx_url = os.getenv('AWX_URL')
        awx_username = os.getenv('AWX_USERNAME')
        awx_password = os.getenv('AWX_PASSWORD')
        if all([awx_url, awx_username, awx_password]):
            self.config.awx = AWXConfig(
                url=awx_url,
                username=awx_username,
                password=awx_password,
                verify_ssl=os.getenv('AWX_VERIFY_SSL', 'true').lower() == 'true'
            )
    
    def get_config(self) -> SystemConfig:
        """Get current configuration."""
        return self.config
    
    def save_config(self, config_path: Optional[str] = None) -> None:
        """Save current configuration to file."""
        save_path = config_path or self.config_path or "./config.yaml"
        save_path = Path(save_path).expanduser()
        
        # Create directory if it doesn't exist
        save_path.parent.mkdir(parents=True, exist_ok=True)
        
        try:
            with open(save_path, 'w') as f:
                yaml.dump(self.config.dict(), f, default_flow_style=False)
        except Exception as e:
            raise RuntimeError(f"Failed to save configuration to {save_path}: {e}")
    
    def create_sample_config(self, output_path: str = "./config.yaml") -> None:
        """Create sample configuration file."""
        sample_config = {
            "firmware_directory": "/var/lib/network-upgrade/firmware",
            "log_level": "INFO",
            "max_concurrent_jobs": 50,
            "default_job_timeout": 3600,
            
            "database": {
                "url": "sqlite:///network_upgrade.db",
                "echo": False
            },
            
            "netbox": {
                "url": "https://netbox.example.com",
                "token": "your-netbox-api-token",
                "verify_ssl": True
            },
            
            "influxdb": {
                "url": "https://influxdb.example.com",
                "token": "your-influxdb-token", 
                "org": "your-organization",
                "bucket": "network-upgrades"
            },
            
            "awx": {
                "url": "https://awx.example.com",
                "username": "admin",
                "password": "your-awx-password",
                "verify_ssl": True
            }
        }
        
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_file, 'w') as f:
            yaml.dump(sample_config, f, default_flow_style=False, sort_keys=False)
        
        print(f"Sample configuration created at: {output_path}")


# Global configuration instance
_config_manager = None


def get_config_manager() -> ConfigManager:
    """Get global configuration manager instance."""
    global _config_manager
    if _config_manager is None:
        _config_manager = ConfigManager()
    return _config_manager


def get_config() -> SystemConfig:
    """Get current system configuration."""
    return get_config_manager().get_config()
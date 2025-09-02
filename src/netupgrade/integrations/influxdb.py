"""InfluxDB v2 integration for metrics collection and export."""

import logging
from datetime import datetime
from typing import Dict, List, Optional, Any
from influxdb_client import InfluxDBClient, Point, WriteApi
from influxdb_client.client.write_api import SYNCHRONOUS
from netupgrade.models.upgrade import UpgradeJob, ValidationResult


logger = logging.getLogger(__name__)


class InfluxDBExporter:
    """InfluxDB v2 client for metrics export."""
    
    def __init__(self, url: str, token: str, org: str, bucket: str = "network-upgrades"):
        self.url = url
        self.token = token
        self.org = org
        self.bucket = bucket
        self.client = None
        self.write_api = None
        self._connect()
    
    def _connect(self) -> None:
        """Initialize InfluxDB client connection."""
        try:
            self.client = InfluxDBClient(url=self.url, token=self.token, org=self.org)
            self.write_api = self.client.write_api(write_options=SYNCHRONOUS)
            
            # Test connection
            ready = self.client.ready()
            if ready.status == "ready":
                logger.info(f"Connected to InfluxDB at {self.url}")
            else:
                raise ConnectionError(f"InfluxDB not ready: {ready.status}")
                
        except Exception as e:
            logger.error(f"Failed to connect to InfluxDB: {e}")
            raise
    
    def export_upgrade_progress(self, job: UpgradeJob) -> bool:
        """Export upgrade progress metrics."""
        if not self.write_api:
            logger.error("InfluxDB client not connected")
            return False
        
        try:
            point = (
                Point("upgrade_progress")
                .tag("device_id", job.device_id)
                .tag("device_name", job.device_name) 
                .tag("device_type", job.platform)
                .tag("batch_id", job.batch_id or "single")
                .tag("vendor", self._extract_vendor(job.platform))
                .tag("platform", job.platform)
                .field("state", job.phase.value)
                .field("progress_percent", job.progress_percent)
                .field("duration_seconds", self._calculate_duration(job))
                .field("error_code", job.error_message or "")
                .time(datetime.utcnow())
            )
            
            self.write_api.write(bucket=self.bucket, org=self.org, record=point)
            logger.debug(f"Exported upgrade progress for job {job.id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to export upgrade progress: {e}")
            return False
    
    def export_state_transition(self, job: UpgradeJob, from_state: str, to_state: str, 
                              transition_duration_ms: float, automated: bool = True) -> bool:
        """Export upgrade state transition metrics."""
        if not self.write_api:
            logger.error("InfluxDB client not connected")
            return False
        
        try:
            point = (
                Point("upgrade_state_transitions")
                .tag("device_id", job.device_id)
                .tag("from_state", from_state)
                .tag("to_state", to_state)
                .tag("batch_id", job.batch_id or "single")
                .tag("operator_id", job.operator_id)
                .field("transition_duration_ms", transition_duration_ms)
                .field("automated", automated)
                .field("success", True)  # Assume success if we're logging the transition
                .field("retry_count", job.retry_count)
                .time(datetime.utcnow())
            )
            
            self.write_api.write(bucket=self.bucket, org=self.org, record=point)
            logger.debug(f"Exported state transition {from_state} -> {to_state} for job {job.id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to export state transition: {e}")
            return False
    
    def export_network_validation(self, device_id: str, validation_results: List[ValidationResult]) -> bool:
        """Export network validation results."""
        if not self.write_api:
            logger.error("InfluxDB client not connected")
            return False
        
        try:
            points = []
            for result in validation_results:
                point = (
                    Point("network_validation")
                    .tag("device_id", device_id)
                    .tag("validation_type", result.validation_type)
                    .tag("protocol", result.protocol or "unknown")
                    .field("baseline_count", result.baseline_count or 0)
                    .field("current_count", result.current_count or 0)
                    .field("validation_success", result.success)
                    .field("convergence_time", result.convergence_time or 0)
                    .time(result.timestamp)
                )
                points.append(point)
            
            if points:
                self.write_api.write(bucket=self.bucket, org=self.org, record=points)
                logger.debug(f"Exported {len(points)} network validation results for device {device_id}")
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to export network validation results: {e}")
            return False
    
    def export_device_compliance(self, device_id: str, vendor: str, platform: str, site: str,
                               current_firmware: str, target_firmware: str, 
                               compliant: bool, last_upgraded: Optional[datetime] = None) -> bool:
        """Export device compliance metrics."""
        if not self.write_api:
            logger.error("InfluxDB client not connected")
            return False
        
        try:
            point = (
                Point("device_compliance")
                .tag("device_id", device_id)
                .tag("vendor", vendor)
                .tag("platform", platform)
                .tag("site", site)
                .field("current_firmware", current_firmware)
                .field("target_firmware", target_firmware)
                .field("compliant", compliant)
                .field("last_upgraded", int(last_upgraded.timestamp()) if last_upgraded else 0)
                .time(datetime.utcnow())
            )
            
            self.write_api.write(bucket=self.bucket, org=self.org, record=point)
            logger.debug(f"Exported compliance metrics for device {device_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to export device compliance: {e}")
            return False
    
    def export_storage_management(self, device_id: str, vendor: str, platform: str,
                                total_space: int, available_space: int, 
                                cleanup_performed: bool, images_removed: int) -> bool:
        """Export storage management metrics."""
        if not self.write_api:
            logger.error("InfluxDB client not connected")
            return False
        
        try:
            point = (
                Point("storage_management")
                .tag("device_id", device_id)
                .tag("vendor", vendor)
                .tag("platform", platform)
                .field("total_space", total_space)
                .field("available_space", available_space)
                .field("cleanup_performed", cleanup_performed)
                .field("images_removed", images_removed)
                .time(datetime.utcnow())
            )
            
            self.write_api.write(bucket=self.bucket, org=self.org, record=point)
            logger.debug(f"Exported storage metrics for device {device_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to export storage metrics: {e}")
            return False
    
    def export_custom_metric(self, measurement: str, tags: Dict[str, str], 
                           fields: Dict[str, Any], timestamp: Optional[datetime] = None) -> bool:
        """Export custom metrics to InfluxDB."""
        if not self.write_api:
            logger.error("InfluxDB client not connected")
            return False
        
        try:
            point = Point(measurement)
            
            # Add tags
            for key, value in tags.items():
                point = point.tag(key, str(value))
            
            # Add fields
            for key, value in fields.items():
                point = point.field(key, value)
            
            # Set timestamp
            if timestamp:
                point = point.time(timestamp)
            else:
                point = point.time(datetime.utcnow())
            
            self.write_api.write(bucket=self.bucket, org=self.org, record=point)
            logger.debug(f"Exported custom metric: {measurement}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to export custom metric: {e}")
            return False
    
    def query_metrics(self, query: str) -> List[Dict[str, Any]]:
        """Execute InfluxDB query and return results."""
        if not self.client:
            logger.error("InfluxDB client not connected")
            return []
        
        try:
            query_api = self.client.query_api()
            tables = query_api.query(query, org=self.org)
            
            results = []
            for table in tables:
                for record in table.records:
                    result = {
                        "time": record.get_time(),
                        "measurement": record.get_measurement(),
                        "field": record.get_field(),
                        "value": record.get_value(),
                        "tags": {}
                    }
                    
                    # Add all tags
                    for key, value in record.values.items():
                        if key not in ["_time", "_measurement", "_field", "_value", "_start", "_stop"]:
                            result["tags"][key] = value
                    
                    results.append(result)
            
            return results
            
        except Exception as e:
            logger.error(f"Failed to query InfluxDB: {e}")
            return []
    
    def close(self) -> None:
        """Close InfluxDB connection."""
        if self.client:
            self.client.close()
            logger.info("InfluxDB connection closed")
    
    def _extract_vendor(self, platform: str) -> str:
        """Extract vendor from platform string."""
        vendor_mapping = {
            "cisco_nxos": "cisco",
            "cisco_iosxe": "cisco", 
            "metamako_mos": "metamako",
            "opengear": "opengear",
            "fortios": "fortinet"
        }
        
        return vendor_mapping.get(platform.lower(), "unknown")
    
    def _calculate_duration(self, job: UpgradeJob) -> float:
        """Calculate job duration in seconds."""
        if job.started_time and job.completed_time:
            return (job.completed_time - job.started_time).total_seconds()
        elif job.started_time:
            return (datetime.utcnow() - job.started_time).total_seconds()
        else:
            return 0.0
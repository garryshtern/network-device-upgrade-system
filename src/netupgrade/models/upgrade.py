"""Upgrade job and result models."""

from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional
from pydantic import BaseModel, Field


class UpgradePhase(str, Enum):
    """Upgrade workflow phases."""
    
    HEALTH_CHECK = "health_check"
    STORAGE_CLEANUP = "storage_cleanup"
    IMAGE_LOADING = "image_loading"
    IMAGE_VERIFICATION = "image_verification"
    IMAGE_INSTALLATION = "image_installation"
    DEVICE_REBOOT = "device_reboot"
    POST_VALIDATION = "post_validation"
    COMPLETED = "completed"
    FAILED = "failed"
    ROLLED_BACK = "rolled_back"


class UpgradeStatus(str, Enum):
    """Upgrade job status."""
    
    PENDING = "pending"
    RUNNING = "running"
    SUCCESS = "success"
    FAILED = "failed"
    CANCELLED = "cancelled"
    ROLLING_BACK = "rolling_back"
    ROLLED_BACK = "rolled_back"


class ValidationResult(BaseModel):
    """Network validation result."""
    
    validation_type: str = Field(..., description="Type of validation performed")
    protocol: Optional[str] = Field(None, description="Network protocol validated")
    baseline_count: Optional[int] = Field(None, description="Baseline state count")
    current_count: Optional[int] = Field(None, description="Current state count")
    success: bool = Field(..., description="Validation success status")
    convergence_time: Optional[float] = Field(None, description="Convergence time in seconds")
    details: Dict[str, str] = Field(default_factory=dict, description="Additional details")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Validation timestamp")


class UpgradeJob(BaseModel):
    """Upgrade job definition."""
    
    id: str = Field(..., description="Unique job identifier")
    device_id: str = Field(..., description="Target device ID")
    device_name: str = Field(..., description="Target device name")
    platform: str = Field(..., description="Device platform")
    current_firmware: Optional[str] = Field(None, description="Current firmware version")
    target_firmware: str = Field(..., description="Target firmware version")
    phase: UpgradePhase = Field(default=UpgradePhase.HEALTH_CHECK, description="Current phase")
    status: UpgradeStatus = Field(default=UpgradeStatus.PENDING, description="Job status")
    progress_percent: int = Field(default=0, description="Completion percentage")
    batch_id: Optional[str] = Field(None, description="Batch operation ID")
    operator_id: str = Field(..., description="Operator user ID")
    scheduled_time: Optional[datetime] = Field(None, description="Scheduled execution time")
    started_time: Optional[datetime] = Field(None, description="Actual start time")
    completed_time: Optional[datetime] = Field(None, description="Completion time")
    error_message: Optional[str] = Field(None, description="Error details if failed")
    retry_count: int = Field(default=0, description="Number of retries attempted")
    rollback_available: bool = Field(default=False, description="Rollback option available")
    
    class Config:
        use_enum_values = True


class UpgradeResult(BaseModel):
    """Complete upgrade operation result."""
    
    job_id: str = Field(..., description="Associated job ID")
    device_id: str = Field(..., description="Target device ID")
    success: bool = Field(..., description="Overall success status")
    duration_seconds: float = Field(..., description="Total upgrade duration")
    phases_completed: List[UpgradePhase] = Field(default_factory=list, description="Completed phases")
    validation_results: List[ValidationResult] = Field(default_factory=list, description="Validation outcomes")
    storage_cleaned: bool = Field(default=False, description="Storage cleanup performed")
    images_removed: int = Field(default=0, description="Number of old images removed")
    hash_verified: bool = Field(default=False, description="Firmware hash verification status")
    rollback_performed: bool = Field(default=False, description="Rollback execution status")
    final_firmware: Optional[str] = Field(None, description="Final firmware version")
    metrics_exported: bool = Field(default=False, description="Metrics export status")
    inventory_updated: bool = Field(default=False, description="Inventory update status")
    
    class Config:
        use_enum_values = True


class BatchUpgrade(BaseModel):
    """Batch upgrade operation."""
    
    id: str = Field(..., description="Batch identifier")
    name: str = Field(..., description="Batch operation name")
    device_ids: List[str] = Field(..., description="Target device IDs")
    target_firmware: str = Field(..., description="Target firmware version")
    concurrency: int = Field(default=5, description="Maximum concurrent operations")
    operator_id: str = Field(..., description="Operator user ID")
    created_time: datetime = Field(default_factory=datetime.utcnow, description="Creation timestamp")
    started_time: Optional[datetime] = Field(None, description="Batch start time")
    completed_time: Optional[datetime] = Field(None, description="Batch completion time")
    jobs: List[UpgradeJob] = Field(default_factory=list, description="Individual upgrade jobs")
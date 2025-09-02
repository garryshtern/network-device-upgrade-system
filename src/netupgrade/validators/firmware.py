"""Firmware validation and integrity checking."""

import hashlib
import os
from pathlib import Path
from typing import Dict, Optional, Tuple
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from pydantic import BaseModel


class FirmwareFile(BaseModel):
    """Firmware file representation."""
    
    path: Path
    filename: str
    size_bytes: int
    sha512_hash: Optional[str] = None
    signature: Optional[str] = None
    vendor: str
    platform: str
    version: str


class FirmwareValidator:
    """Cryptographic firmware validation."""
    
    def __init__(self, firmware_dir: str = "/var/lib/network-upgrade/firmware"):
        self.firmware_dir = Path(firmware_dir)
        self.supported_extensions = {".bin", ".tar", ".pkg", ".img", ".swi"}
        
    def calculate_sha512(self, file_path: Path) -> str:
        """Calculate SHA512 hash of firmware file."""
        hasher = hashlib.sha512()
        
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(8192), b""):
                hasher.update(chunk)
                
        return hasher.hexdigest()
    
    def load_expected_hash(self, firmware_path: Path) -> Optional[str]:
        """Load expected SHA512 hash from .sha512 file."""
        hash_file = firmware_path.with_suffix(firmware_path.suffix + '.sha512')
        
        if not hash_file.exists():
            return None
            
        try:
            with open(hash_file, 'r') as f:
                content = f.read().strip()
                # Handle different hash file formats
                if ' ' in content:
                    return content.split()[0]  # Take just the hash part
                return content
        except (IOError, OSError):
            return None
    
    def verify_hash(self, firmware_path: Path) -> Tuple[bool, str, Optional[str]]:
        """Verify firmware file hash against expected value."""
        if not firmware_path.exists():
            return False, "File not found", None
            
        calculated_hash = self.calculate_sha512(firmware_path)
        expected_hash = self.load_expected_hash(firmware_path)
        
        if expected_hash is None:
            return False, "No expected hash file found", calculated_hash
            
        if calculated_hash.lower() == expected_hash.lower():
            return True, "Hash verification successful", calculated_hash
        else:
            return False, f"Hash mismatch: expected {expected_hash}, got {calculated_hash}", calculated_hash
    
    def verify_signature(self, firmware_path: Path, public_key_path: Optional[Path] = None) -> Tuple[bool, str]:
        """Verify cryptographic signature of firmware file."""
        if public_key_path is None:
            return False, "No public key provided for signature verification"
            
        sig_file = firmware_path.with_suffix(firmware_path.suffix + '.sig')
        
        if not sig_file.exists():
            return False, "No signature file found"
            
        try:
            # Load public key
            with open(public_key_path, 'rb') as f:
                public_key = serialization.load_pem_public_key(f.read())
            
            # Load signature
            with open(sig_file, 'rb') as f:
                signature = f.read()
            
            # Load firmware data
            with open(firmware_path, 'rb') as f:
                firmware_data = f.read()
            
            # Verify signature
            public_key.verify(
                signature,
                firmware_data,
                padding.PSS(
                    mgf=padding.MGF1(hashes.SHA256()),
                    salt_length=padding.PSS.MAX_LENGTH
                ),
                hashes.SHA256()
            )
            
            return True, "Signature verification successful"
            
        except Exception as e:
            return False, f"Signature verification failed: {str(e)}"
    
    def validate_firmware(self, firmware_path: Path, public_key_path: Optional[Path] = None) -> Dict[str, any]:
        """Perform complete firmware validation."""
        result = {
            "file_path": str(firmware_path),
            "file_exists": firmware_path.exists(),
            "file_size": 0,
            "hash_verification": {"success": False, "message": "", "calculated_hash": None},
            "signature_verification": {"success": False, "message": ""},
            "overall_valid": False
        }
        
        if not firmware_path.exists():
            result["hash_verification"]["message"] = "File does not exist"
            return result
            
        # Get file size
        result["file_size"] = firmware_path.stat().st_size
        
        # Verify hash
        hash_success, hash_message, calculated_hash = self.verify_hash(firmware_path)
        result["hash_verification"] = {
            "success": hash_success,
            "message": hash_message,
            "calculated_hash": calculated_hash
        }
        
        # Verify signature if public key provided
        if public_key_path:
            sig_success, sig_message = self.verify_signature(firmware_path, public_key_path)
            result["signature_verification"] = {
                "success": sig_success,
                "message": sig_message
            }
        else:
            result["signature_verification"]["message"] = "No public key provided"
        
        # Overall validation
        result["overall_valid"] = hash_success and (
            not public_key_path or result["signature_verification"]["success"]
        )
        
        return result
    
    def discover_firmware_files(self, vendor: Optional[str] = None, platform: Optional[str] = None) -> Dict[str, FirmwareFile]:
        """Discover available firmware files."""
        firmware_files = {}
        
        if not self.firmware_dir.exists():
            return firmware_files
            
        for file_path in self.firmware_dir.rglob("*"):
            if file_path.is_file() and file_path.suffix.lower() in self.supported_extensions:
                # Extract vendor/platform from directory structure or filename
                parts = file_path.parts
                file_vendor = parts[-3] if len(parts) >= 3 else "unknown"
                file_platform = parts[-2] if len(parts) >= 2 else "unknown"
                
                # Filter by criteria if provided
                if vendor and file_vendor.lower() != vendor.lower():
                    continue
                if platform and file_platform.lower() != platform.lower():
                    continue
                
                # Extract version from filename (basic heuristic)
                version = "unknown"
                filename = file_path.stem
                version_parts = [part for part in filename.split('-') if any(c.isdigit() for c in part)]
                if version_parts:
                    version = version_parts[-1]
                
                firmware_file = FirmwareFile(
                    path=file_path,
                    filename=file_path.name,
                    size_bytes=file_path.stat().st_size,
                    vendor=file_vendor,
                    platform=file_platform,
                    version=version
                )
                
                # Load hash if available
                expected_hash = self.load_expected_hash(file_path)
                if expected_hash:
                    firmware_file.sha512_hash = expected_hash
                    
                firmware_files[str(file_path)] = firmware_file
                
        return firmware_files
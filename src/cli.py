"""Main CLI entry point for network upgrade system."""

import click
import logging
from pathlib import Path
from typing import List, Optional
from netupgrade.models.device import Device, DevicePlatform
from netupgrade.integrations.netbox import NetBoxClient
from netupgrade.integrations.influxdb import InfluxDBExporter
from netupgrade.validators.firmware import FirmwareValidator
from rich.console import Console
from rich.table import Table
from rich import print as rprint

console = Console()
logger = logging.getLogger(__name__)


@click.group()
@click.option('--debug', is_flag=True, help='Enable debug logging')
@click.pass_context
def cli(ctx, debug):
    """Network Device Upgrade Management System CLI."""
    ctx.ensure_object(dict)
    
    # Configure logging
    log_level = logging.DEBUG if debug else logging.INFO
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    ctx.obj['debug'] = debug


@cli.group()
def device():
    """Device management commands."""
    pass


@cli.group() 
def firmware():
    """Firmware management commands."""
    pass


@cli.group()
def validate():
    """Validation commands."""
    pass


@device.command('list')
@click.option('--site', help='Filter by site')
@click.option('--platform', type=click.Choice([p.value for p in DevicePlatform]), help='Filter by platform')
@click.option('--netbox-url', envvar='NETBOX_URL', required=True, help='NetBox URL')
@click.option('--netbox-token', envvar='NETBOX_TOKEN', required=True, help='NetBox API token')
def list_devices(site: Optional[str], platform: Optional[str], netbox_url: str, netbox_token: str):
    """List devices from NetBox inventory."""
    try:
        netbox = NetBoxClient(netbox_url, netbox_token)
        
        # Get devices with filters
        devices = netbox.get_devices(site=site, platform=platform)
        
        if not devices:
            rprint("[yellow]No devices found matching criteria[/yellow]")
            return
        
        # Create table
        table = Table(title=f"Network Devices ({len(devices)} found)")
        table.add_column("Name", style="cyan")
        table.add_column("Platform", style="magenta")
        table.add_column("IP Address", style="green")
        table.add_column("Site", style="blue")
        table.add_column("Vendor", style="yellow")
        table.add_column("Model")
        table.add_column("Firmware", style="red")
        table.add_column("State", style="bold")
        
        for device in devices:
            state_color = "green" if device.state.value == "online" else "red"
            firmware = device.current_firmware or "Unknown"
            
            table.add_row(
                device.name,
                device.platform.value,
                str(device.management_ip),
                device.site,
                device.vendor,
                device.model,
                firmware,
                f"[{state_color}]{device.state.value}[/{state_color}]"
            )
        
        console.print(table)
        
    except Exception as e:
        rprint(f"[red]Error: {e}[/red]")
        raise click.Abort()


@device.command('show')
@click.argument('device_name')
@click.option('--netbox-url', envvar='NETBOX_URL', required=True, help='NetBox URL')
@click.option('--netbox-token', envvar='NETBOX_TOKEN', required=True, help='NetBox API token')
def show_device(device_name: str, netbox_url: str, netbox_token: str):
    """Show detailed device information."""
    try:
        netbox = NetBoxClient(netbox_url, netbox_token)
        device = netbox.get_device_by_name(device_name)
        
        if not device:
            rprint(f"[red]Device '{device_name}' not found[/red]")
            raise click.Abort()
        
        # Display device details
        rprint(f"\\n[bold cyan]Device Details: {device.name}[/bold cyan]")
        rprint(f"ID: {device.id}")
        rprint(f"Platform: [magenta]{device.platform.value}[/magenta]")
        rprint(f"Management IP: [green]{device.management_ip}[/green]")
        rprint(f"Site: [blue]{device.site}[/blue]")
        rprint(f"Vendor: [yellow]{device.vendor}[/yellow]")
        rprint(f"Model: {device.model}")
        rprint(f"Current Firmware: [red]{device.current_firmware or 'Unknown'}[/red]")
        rprint(f"Target Firmware: [red]{device.target_firmware or 'None set'}[/red]")
        
        state_color = "green" if device.state.value == "online" else "red"
        rprint(f"State: [{state_color}]{device.state.value}[/{state_color}]")
        
        if device.tags:
            rprint(f"Tags: {', '.join(device.tags)}")
        
    except Exception as e:
        rprint(f"[red]Error: {e}[/red]")
        raise click.Abort()


@firmware.command('list')
@click.option('--vendor', help='Filter by vendor')
@click.option('--platform', help='Filter by platform')
@click.option('--firmware-dir', default='/var/lib/network-upgrade/firmware', help='Firmware directory')
def list_firmware(vendor: Optional[str], platform: Optional[str], firmware_dir: str):
    """List available firmware files."""
    try:
        validator = FirmwareValidator(firmware_dir)
        firmware_files = validator.discover_firmware_files(vendor=vendor, platform=platform)
        
        if not firmware_files:
            rprint("[yellow]No firmware files found[/yellow]")
            return
        
        table = Table(title=f"Available Firmware ({len(firmware_files)} files)")
        table.add_column("Filename", style="cyan")
        table.add_column("Vendor", style="magenta") 
        table.add_column("Platform", style="green")
        table.add_column("Version", style="yellow")
        table.add_column("Size", style="blue")
        table.add_column("Hash Available", style="red")
        
        for path, firmware in firmware_files.items():
            size_mb = round(firmware.size_bytes / (1024 * 1024), 1)
            hash_available = "✓" if firmware.sha512_hash else "✗"
            hash_color = "green" if firmware.sha512_hash else "red"
            
            table.add_row(
                firmware.filename,
                firmware.vendor,
                firmware.platform,
                firmware.version,
                f"{size_mb} MB",
                f"[{hash_color}]{hash_available}[/{hash_color}]"
            )
        
        console.print(table)
        
    except Exception as e:
        rprint(f"[red]Error: {e}[/red]")
        raise click.Abort()


@firmware.command('verify')
@click.argument('firmware_path')
@click.option('--public-key', help='Public key file for signature verification')
def verify_firmware(firmware_path: str, public_key: Optional[str]):
    """Verify firmware file integrity."""
    try:
        validator = FirmwareValidator()
        firmware_file = Path(firmware_path)
        
        if not firmware_file.exists():
            rprint(f"[red]Firmware file not found: {firmware_path}[/red]")
            raise click.Abort()
        
        public_key_path = Path(public_key) if public_key else None
        result = validator.validate_firmware(firmware_file, public_key_path)
        
        rprint(f"\\n[bold cyan]Firmware Validation Results[/bold cyan]")
        rprint(f"File: {result['file_path']}")
        rprint(f"Size: {result['file_size']:,} bytes")
        
        # Hash verification
        hash_result = result['hash_verification']
        hash_color = "green" if hash_result['success'] else "red"
        rprint(f"Hash Verification: [{hash_color}]{hash_result['message']}[/{hash_color}]")
        if hash_result['calculated_hash']:
            rprint(f"Calculated Hash: {hash_result['calculated_hash']}")
        
        # Signature verification
        sig_result = result['signature_verification']
        if public_key:
            sig_color = "green" if sig_result['success'] else "red"
            rprint(f"Signature Verification: [{sig_color}]{sig_result['message']}[/{sig_color}]")
        
        # Overall result
        overall_color = "green" if result['overall_valid'] else "red"
        status = "VALID" if result['overall_valid'] else "INVALID"
        rprint(f"\\n[bold {overall_color}]Overall Status: {status}[/bold {overall_color}]")
        
    except Exception as e:
        rprint(f"[red]Error: {e}[/red]")
        raise click.Abort()


@validate.command('network')
@click.argument('device_name')
@click.option('--netbox-url', envvar='NETBOX_URL', required=True, help='NetBox URL')
@click.option('--netbox-token', envvar='NETBOX_TOKEN', required=True, help='NetBox API token')
def validate_network_state(device_name: str, netbox_url: str, netbox_token: str):
    """Validate network state for a device."""
    try:
        netbox = NetBoxClient(netbox_url, netbox_token)
        device = netbox.get_device_by_name(device_name)
        
        if not device:
            rprint(f"[red]Device '{device_name}' not found[/red]")
            raise click.Abort()
        
        rprint(f"\\n[bold cyan]Network Validation for {device.name}[/bold cyan]")
        rprint("[yellow]Network validation functionality requires device connection implementation[/yellow]")
        rprint("This command will be fully implemented with Ansible integration")
        
    except Exception as e:
        rprint(f"[red]Error: {e}[/red]")
        raise click.Abort()


@cli.command('status')
@click.option('--influxdb-url', envvar='INFLUXDB_URL', help='InfluxDB URL')
@click.option('--influxdb-token', envvar='INFLUXDB_TOKEN', help='InfluxDB token')
@click.option('--influxdb-org', envvar='INFLUXDB_ORG', help='InfluxDB organization')
def system_status(influxdb_url: Optional[str], influxdb_token: Optional[str], influxdb_org: Optional[str]):
    """Show system status and health."""
    rprint("[bold cyan]Network Upgrade System Status[/bold cyan]")
    
    # Check system components
    components = []
    
    # Check if firmware directory exists
    firmware_dir = Path("/var/lib/network-upgrade/firmware")
    firmware_status = "✓" if firmware_dir.exists() else "✗"
    firmware_color = "green" if firmware_dir.exists() else "red"
    components.append(("Firmware Directory", f"[{firmware_color}]{firmware_status}[/{firmware_color}]"))
    
    # Check InfluxDB connection if credentials provided
    if all([influxdb_url, influxdb_token, influxdb_org]):
        try:
            influx = InfluxDBExporter(influxdb_url, influxdb_token, influxdb_org)
            influx_status = "✓"
            influx_color = "green"
            influx.close()
        except Exception:
            influx_status = "✗"
            influx_color = "red"
        components.append(("InfluxDB Connection", f"[{influx_color}]{influx_status}[/{influx_color}]"))
    else:
        components.append(("InfluxDB Connection", "[yellow]Not configured[/yellow]"))
    
    # Display status table
    table = Table(title="System Components")
    table.add_column("Component", style="cyan")
    table.add_column("Status", style="bold")
    
    for component, status in components:
        table.add_row(component, status)
    
    console.print(table)


def main():
    """Main CLI entry point."""
    cli()
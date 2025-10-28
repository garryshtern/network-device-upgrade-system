#!/usr/bin/env python3
"""
Custom Ansible filters for platform detection and matching.

This module provides filters to simplify platform-specific conditional logic
in playbooks and roles.
"""


def is_platform(network_os, platform_name):
    """
    Check if network_os matches the specified platform name.

    Handles both fully-qualified collection names (FQCN) and short names,
    making platform conditionals more readable and maintainable.

    Args:
        network_os (str): The ansible_network_os value (e.g., 'cisco.nxos.nxos')
        platform_name (str): Short platform name to match (e.g., 'nxos')

    Returns:
        bool: True if network_os matches platform_name, False otherwise

    Examples:
        >>> is_platform('cisco.nxos.nxos', 'nxos')
        True
        >>> is_platform('nxos', 'nxos')
        True
        >>> is_platform('cisco.ios.ios', 'nxos')
        False
        >>> is_platform(None, 'nxos')
        False
        >>> is_platform('', 'nxos')
        False

    Usage in Ansible playbooks:
        # Instead of:
        when:
          - ansible_network_os is defined
          - ansible_network_os == 'cisco.nxos.nxos'

        # Use:
        when: ansible_network_os | is_platform('nxos')
    """
    if not network_os:
        return False

    # Platform mapping: short name -> list of valid FQCN and aliases
    platform_map = {
        'nxos': ['cisco.nxos.nxos', 'nxos'],
        'ios': ['cisco.ios.ios', 'ios', 'iosxe'],
        'fortios': ['fortinet.fortios.fortios', 'fortios'],
         [],
        'opengear': ['opengear', 'opengear_og'],
    }

    # Get valid names for the requested platform
    valid_names = platform_map.get(platform_name.lower(), [])

    # Check if network_os matches any valid name (case-insensitive)
    return network_os.lower() in [name.lower() for name in valid_names]


class FilterModule:
    """Ansible filter plugin class."""

    def filters(self):
        """Return available filters."""
        return {
            'is_platform': is_platform,
        }

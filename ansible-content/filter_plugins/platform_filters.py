#!/usr/bin/env python3
"""
Custom Ansible filters for platform detection and manipulation
"""


def is_platform(network_os, platform_name):
    """
    Check if ansible_network_os matches the given platform name.
    Handles both FQCN (cisco.nxos.nxos) and short names (nxos).

    Args:
        network_os (str): The value of ansible_network_os
        platform_name (str): The platform to check for (e.g., 'nxos', 'ios', 'fortios')

    Returns:
        bool: True if the platform matches, False otherwise

    Examples:
        >>> is_platform('cisco.nxos.nxos', 'nxos')
        True
        >>> is_platform('cisco.ios.ios', 'nxos')
        False
        >>> is_platform('fortinet.fortios.fortios', 'fortios')
        True
    """
    if not network_os or not platform_name:
        return False

    # Platform mapping: FQCN to short name
    platform_map = {
        'cisco.nxos.nxos': 'nxos',
        'cisco.ios.ios': 'ios',
        'cisco.iosxe.iosxe': 'iosxe',
        'fortinet.fortios.fortios': 'fortios',
        'arista.eos.eos': 'eos',
        'metamako_mos': 'metamako_mos',
        'metamako.mos': 'metamako_mos',
        'opengear': 'opengear',
    }

    # Normalize both values to lowercase for comparison
    network_os_lower = str(network_os).lower()
    platform_name_lower = str(platform_name).lower()

    # Direct match (handles both FQCN and short name)
    if network_os_lower == platform_name_lower:
        return True

    # Check if FQCN maps to the short name
    if network_os_lower in platform_map:
        if platform_map[network_os_lower] == platform_name_lower:
            return True

    # Check if platform_name is in the network_os string
    if platform_name_lower in network_os_lower:
        return True

    return False


class FilterModule(object):
    """
    Ansible filter plugin class
    """
    def filters(self):
        return {
            'is_platform': is_platform,
        }

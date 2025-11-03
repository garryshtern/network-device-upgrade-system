#!/usr/bin/env python3
"""
Custom Ansible filters for platform detection, data normalization, and formatting.

This module provides filters to simplify platform-specific conditional logic,
recursive data operations, and proper JSON formatting in playbooks and roles.
"""

import json


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
        'opengear': ['opengear', 'opengear_og'],
    }

    # Get valid names for the requested platform
    valid_names = platform_map.get(platform_name.lower(), [])

    # Check if network_os matches any valid name (case-insensitive)
    return network_os.lower() in [name.lower() for name in valid_names]


def remove_excluded_fields_recursive(data, excluded_fields):
    """
    Recursively remove excluded fields from data at all nesting levels.

    Handles dictionaries, lists, and nested structures. Removes specified
    fields from any dictionary at any depth in the data structure.

    Args:
        data: The data structure to filter (dict, list, or primitive)
        excluded_fields: List of field names to remove at any level

    Returns:
        The filtered data structure with excluded fields removed at all levels

    Examples:
        >>> data = {'name': 'test', 'age': 30, 'nested': {'time': '2025-01-01', 'value': 42}}
        >>> remove_excluded_fields_recursive(data, ['age', 'time'])
        {'name': 'test', 'nested': {'value': 42}}

        >>> data = [{'id': 1, 'time': '2025-01-01'}, {'id': 2, 'time': '2025-01-02'}]
        >>> remove_excluded_fields_recursive(data, ['time'])
        [{'id': 1}, {'id': 2}]
    """
    if not isinstance(excluded_fields, (list, tuple)):
        excluded_fields = [excluded_fields]

    def _remove_recursive(obj):
        """Inner recursive function."""
        if isinstance(obj, dict):
            # Remove excluded keys and recursively process values
            return {k: _remove_recursive(v) for k, v in obj.items() if k not in excluded_fields}
        elif isinstance(obj, list):
            # Recursively process each list item
            return [_remove_recursive(item) for item in obj]
        else:
            # Return primitives as-is
            return obj

    return _remove_recursive(data)


def difference_recursive(data1, data2):
    """
    Recursively find differences between two data structures at all levels.

    Compares nested dictionaries and lists recursively. Returns items/values
    that exist in data1 but not in data2, handling nested structures.

    Args:
        data1: The first data structure
        data2: The second data structure to compare against

    Returns:
        Items/values from data1 that are not in data2, maintaining structure

    Examples:
        >>> data1 = [{'id': 1, 'value': 'a'}, {'id': 2, 'value': 'b'}]
        >>> data2 = [{'id': 1, 'value': 'a'}]
        >>> difference_recursive(data1, data2)
        [{'id': 2, 'value': 'b'}]

        >>> data1 = {'a': 1, 'b': 2, 'nested': {'c': 3, 'd': 4}}
        >>> data2 = {'a': 1, 'nested': {'c': 3}}
        >>> difference_recursive(data1, data2)
        {'b': 2, 'nested': {'d': 4}}
    """
    if isinstance(data1, dict) and isinstance(data2, dict):
        # For dicts, find keys that exist in data1 but not in data2,
        # or have different nested values
        result = {}
        for key, value1 in data1.items():
            if key not in data2:
                # Key doesn't exist in data2, include it
                result[key] = value1
            else:
                value2 = data2[key]
                if isinstance(value1, dict) and isinstance(value2, dict):
                    # Recursively compare nested dicts
                    nested_diff = difference_recursive(value1, value2)
                    if nested_diff:
                        result[key] = nested_diff
                elif isinstance(value1, list) and isinstance(value2, list):
                    # Recursively compare lists
                    nested_diff = difference_recursive(value1, value2)
                    if nested_diff:
                        result[key] = nested_diff
                elif value1 != value2:
                    # Values differ, include the one from data1
                    result[key] = value1
        return result

    elif isinstance(data1, list) and isinstance(data2, list):
        # For lists, use set difference logic for hashable items,
        # or compare dict items recursively
        if data1 and isinstance(data1[0], dict) and data2 and isinstance(data2[0], dict):
            # List of dicts: find dicts in data1 that aren't in data2
            result = []
            for item1 in data1:
                found = False
                for item2 in data2:
                    if item1 == item2:
                        found = True
                        break
                if not found:
                    result.append(item1)
            return result
        else:
            # List of primitives: use standard set difference
            try:
                set1 = set(tuple(x) if isinstance(x, list) else x for x in data1)
                set2 = set(tuple(x) if isinstance(x, list) else x for x in data2)
                diff = set1 - set2
                return [list(x) if isinstance(x, tuple) else x for x in diff]
            except TypeError:
                # Fallback for unhashable types
                return [item for item in data1 if item not in data2]

    else:
        # For non-dict/list types, return data1 if different from data2
        return data1 if data1 != data2 else []


def to_proper_json(data, indent=2):
    """
    Convert data to properly formatted JSON with proper newline handling.

    Unlike to_nice_json which renders newlines as literal '\n' characters,
    this filter properly formats JSON with actual newlines for readable output.

    Args:
        data: The data structure to format as JSON
        indent: Number of spaces for indentation (default: 2)

    Returns:
        Properly formatted JSON string with real newlines

    Examples:
        >>> data = {'name': 'test', 'items': [1, 2, 3]}
        >>> to_proper_json(data)
        '{\n  "name": "test",\n  "items": [\n    1,\n    2,\n    3\n  ]\n}'
    """
    return json.dumps(data, indent=indent, sort_keys=True)


class FilterModule:
    """Ansible filter plugin class."""

    def filters(self):
        """Return available filters."""
        return {
            'is_platform': is_platform,
            'remove_excluded_fields_recursive': remove_excluded_fields_recursive,
            'difference_recursive': difference_recursive,
            'to_proper_json': to_proper_json,
        }

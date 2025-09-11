#!/usr/bin/env python3
"""
YAML/JSON Validation Script
Validates all YAML and JSON files in the project for syntax and structure
"""

import sys
import yaml
import json
import argparse
from pathlib import Path


class ValidationError(Exception):
    """Custom validation error"""
    pass


class FileValidator:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.files_checked = 0

    def validate_yaml_file(self, file_path):
        """Validate a single YAML file"""
        try:
            with open(file_path, 'r') as file:
                yaml.safe_load(file)
            self.files_checked += 1
            print(f"✓ {file_path}")
        except yaml.YAMLError as e:
            error_msg = f"YAML Error in {file_path}: {e}"
            self.errors.append(error_msg)
            print(f"✗ {file_path} - {e}")
        except Exception as e:
            error_msg = f"Error reading {file_path}: {e}"
            self.errors.append(error_msg)
            print(f"✗ {file_path} - {e}")

    def validate_json_file(self, file_path):
        """Validate a single JSON file"""
        try:
            with open(file_path, 'r') as file:
                json.load(file)
            self.files_checked += 1
            print(f"✓ {file_path}")
        except json.JSONDecodeError as e:
            error_msg = f"JSON Error in {file_path}: {e}"
            self.errors.append(error_msg)
            print(f"✗ {file_path} - {e}")
        except Exception as e:
            error_msg = f"Error reading {file_path}: {e}"
            self.errors.append(error_msg)
            print(f"✗ {file_path} - {e}")

    def validate_ansible_structure(self, file_path):
        """Validate Ansible-specific YAML structure"""
        try:
            with open(file_path, 'r') as file:
                content = yaml.safe_load(file)

            # Check if it's a valid Ansible playbook structure
            if isinstance(content, list):
                for play in content:
                    if not isinstance(play, dict):
                        self.warnings.append(f"Invalid play structure in {file_path}")
                        continue
                    if 'hosts' not in play and 'import_playbook' not in play:
                        self.warnings.append(f"Missing 'hosts' in play in {file_path}")

        except Exception as e:
            # Already caught by validate_yaml_file
            pass

    def scan_directory(self, directory, extensions=None):
        """Scan directory for files to validate"""
        if extensions is None:
            extensions = ['.yml', '.yaml', '.json']

        directory = Path(directory)
        for ext in extensions:
            for file_path in directory.rglob(f"*{ext}"):
                if ext in ['.yml', '.yaml']:
                    self.validate_yaml_file(file_path)
                    if 'ansible-content' in str(file_path) or 'playbook' in str(file_path):
                        self.validate_ansible_structure(file_path)
                elif ext == '.json':
                    self.validate_json_file(file_path)

    def report_results(self):
        """Print validation results"""
        print("\n" + "="*50)
        print("VALIDATION RESULTS")
        print("="*50)
        print(f"Files checked: {self.files_checked}")
        print(f"Errors: {len(self.errors)}")
        print(f"Warnings: {len(self.warnings)}")

        if self.errors:
            print("\nERRORS:")
            for error in self.errors:
                print(f"  - {error}")

        if self.warnings:
            print("\nWARNINGS:")
            for warning in self.warnings:
                print(f"  - {warning}")

        if not self.errors and not self.warnings:
            print("\n✓ All files passed validation!")
            return 0
        elif self.errors:
            print(f"\n✗ Validation failed with {len(self.errors)} errors")
            return 1
        else:
            print(f"\n⚠ Validation completed with {len(self.warnings)} warnings")
            return 0


def main():
    parser = argparse.ArgumentParser(description='Validate YAML and JSON files')
    parser.add_argument('directory', nargs='?', default='.',
                        help='Directory to scan (default: current directory)')
    parser.add_argument('--extensions', nargs='+', default=['.yml', '.yaml', '.json'],
                        help='File extensions to validate')
    parser.add_argument('--ansible-only', action='store_true',
                        help='Only validate Ansible-related files')

    args = parser.parse_args()

    validator = FileValidator()

    print("Starting YAML/JSON validation...")
    print(f"Scanning directory: {args.directory}")
    print(f"Extensions: {args.extensions}")

    if args.ansible_only:
        # Only scan ansible-content directory
        ansible_dir = Path(args.directory) / 'ansible-content'
        if ansible_dir.exists():
            validator.scan_directory(ansible_dir, ['.yml', '.yaml'])
        else:
            print(f"Ansible directory not found: {ansible_dir}")
            return 1
    else:
        validator.scan_directory(args.directory, args.extensions)

    return validator.report_results()


if __name__ == '__main__':
    sys.exit(main())

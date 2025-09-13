#!/usr/bin/env python3
"""
Comprehensive YAML syntax fixer for Ansible roles.
Handles complex structural issues and broken YAML patterns.
"""

import os
import re
import glob
import tempfile
import subprocess

def validate_yaml(filepath):
    """Check if YAML file is valid"""
    try:
        import yaml
        with open(filepath, 'r') as f:
            yaml.safe_load(f)
        return True, None
    except Exception as e:
        return False, str(e)

def fix_yaml_comprehensive(content):
    """Apply comprehensive YAML fixes"""
    # Fix 1: Broken YAML folding with quotes and newlines
    content = re.sub(r'^(\s+)>\s*\n"([^"]*(?:\n[^"]*)*)"', 
                    lambda m: f'{m.group(1)}>-\n{m.group(1)}  {m.group(2).strip()}', 
                    content, flags=re.MULTILINE)
    
    # Fix 2: Jinja2 variables starting on new line without indentation
    content = re.sub(r'^(\s+)(\{\{[^}]+\}\})', 
                    lambda m: f'{m.group(1)}  {m.group(2)}',
                    content, flags=re.MULTILINE)
    
    # Fix 3: Remove trailing quotes and fix indentation issues
    content = re.sub(r'^(\s+)>\s*"([^"]+)"$', r'\1>- \2', content, flags=re.MULTILINE)
    
    # Fix 4: Multi-line expressions with broken continuation
    content = re.sub(r'^(\s+)([^:\n]+)\s*\|\s*\n(\s+)([^:\n]+)',
                    r'\1\2 | \4', content, flags=re.MULTILINE)
    
    # Fix 5: Fix broken Jinja expressions across lines
    content = re.sub(r'^(\s*)(\{\{[^}]*)\n(\s*)([^}]*\}\})',
                    r'\1\2 \4', content, flags=re.MULTILINE)
    
    return content

def attempt_structural_fix(filepath):
    """Attempt to fix structural YAML issues"""
    try:
        with open(filepath, 'r') as f:
            lines = f.readlines()
        
        fixed_lines = []
        in_multiline_string = False
        current_indent = 0
        
        for i, line in enumerate(lines):
            # Skip empty lines
            if line.strip() == '':
                fixed_lines.append(line)
                continue
                
            # Detect and fix broken YAML folding
            if re.match(r'^\s*>\s*$', line):
                # Found a > on its own line, next line should be indented content
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    if next_line.startswith('"') and not next_line.strip().startswith('  '):
                        # Fix the indentation
                        indent = len(line) - len(line.lstrip())
                        content = next_line.strip().strip('"')
                        fixed_lines.append(f'{" " * indent}>-\n')
                        fixed_lines.append(f'{" " * (indent + 2)}{content}\n')
                        lines[i + 1] = ''  # Skip the next line
                        continue
            
            # Fix Jinja2 variables that start at beginning of line
            if re.match(r'^[{][{]', line.strip()) and i > 0:
                prev_line = fixed_lines[-1] if fixed_lines else ''
                if prev_line.strip().endswith('>') or prev_line.strip().endswith('|-'):
                    # This should be indented
                    indent_match = re.match(r'^(\s*)', prev_line)
                    if indent_match:
                        base_indent = len(indent_match.group(1))
                        line = ' ' * (base_indent + 2) + line.strip() + '\n'
            
            fixed_lines.append(line)
        
        with open(filepath, 'w') as f:
            f.writelines(fixed_lines)
        
        return True
    except Exception as e:
        print(f"Structural fix failed for {filepath}: {e}")
        return False

def process_yaml_file(filepath):
    """Process a single YAML file with comprehensive fixes"""
    # First check if it's already valid
    is_valid, error = validate_yaml(filepath)
    if is_valid:
        return False  # No changes needed
    
    print(f"Fixing {filepath}: {error}")
    
    # Make a backup
    backup_path = filepath + '.backup'
    with open(filepath, 'r') as src, open(backup_path, 'w') as dst:
        dst.write(src.read())
    
    try:
        # Apply content-based fixes
        with open(filepath, 'r') as f:
            content = f.read()
        
        fixed_content = fix_yaml_comprehensive(content)
        
        with open(filepath, 'w') as f:
            f.write(fixed_content)
        
        # Check if it's now valid
        is_valid, _ = validate_yaml(filepath)
        if is_valid:
            os.remove(backup_path)
            return True
        
        # If still invalid, try structural fixes
        attempt_structural_fix(filepath)
        
        is_valid, _ = validate_yaml(filepath)
        if is_valid:
            os.remove(backup_path)
            return True
        else:
            # Restore backup if fixes didn't work
            os.rename(backup_path, filepath)
            return False
            
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        if os.path.exists(backup_path):
            os.rename(backup_path, filepath)
        return False

def main():
    """Main function"""
    # Get all role task YAML files
    patterns = [
        "ansible-content/roles/*/tasks/*.yml",
        "ansible-content/roles/*/handlers/*.yml"
    ]
    
    all_files = []
    for pattern in patterns:
        all_files.extend(glob.glob(pattern))
    
    fixed_count = 0
    total_count = len(all_files)
    
    print(f"Processing {total_count} YAML files...")
    
    for filepath in all_files:
        if process_yaml_file(filepath):
            print(f"✓ Fixed: {filepath}")
            fixed_count += 1
    
    print(f"\nResults: {fixed_count}/{total_count} files were successfully fixed")
    
    # Run a quick validation check
    print("\nValidation check:")
    invalid_count = 0
    for filepath in all_files:
        is_valid, error = validate_yaml(filepath)
        if not is_valid:
            print(f"Still invalid: {filepath}")
            invalid_count += 1
    
    print(f"Remaining invalid files: {invalid_count}")

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
Script to automatically fix common YAML syntax errors in Ansible role files.
Specifically targets broken YAML folding operators.
"""

import os
import re
import glob

def fix_yaml_folding(content):
    """Fix broken YAML folding patterns"""
    # Pattern 1: > followed by quoted string on next line
    # Fix: > -> >- and remove quotes, fix indentation
    pattern1 = re.compile(r'^(\s+)>\s*\n(\s*)"([^"]*(?:\n(?!\s*[a-zA-Z_-]+:)[^"]*)*)"\s*$', re.MULTILINE)
    
    def replace_pattern1(match):
        indent = match.group(1)
        content = match.group(3)
        # Clean up content and fix indentation
        lines = content.split('\n')
        fixed_lines = []
        for line in lines:
            # Remove extra indentation and clean up
            clean_line = line.strip()
            if clean_line:
                fixed_lines.append(f'{indent}  {clean_line}')
        
        if len(fixed_lines) == 1:
            return f'{indent}>-\n{fixed_lines[0]}'
        else:
            return f'{indent}>-\n' + '\n'.join(fixed_lines)
    
    content = pattern1.sub(replace_pattern1, content)
    
    # Pattern 2: Simple case of > "text" on same line
    pattern2 = re.compile(r'^(\s+)>\s*"([^"]*)"', re.MULTILINE)
    content = pattern2.sub(r'\1>- \2', content)
    
    # Pattern 3: > followed by text with Jinja2 variables on next line  
    pattern3 = re.compile(r'^(\s+)>\s*\n"(\{\{[^}]*\}\}[^"]*)"', re.MULTILINE)
    content = pattern3.sub(r'\1>-\n\1  \2', content)
    
    return content

def process_file(filepath):
    """Process a single YAML file"""
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        original_content = content
        fixed_content = fix_yaml_folding(content)
        
        if fixed_content != original_content:
            with open(filepath, 'w') as f:
                f.write(fixed_content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Main function to process all role YAML files"""
    pattern = "ansible-content/roles/*/tasks/*.yml"
    files = glob.glob(pattern)
    
    fixed_count = 0
    total_count = len(files)
    
    print(f"Processing {total_count} role task files...")
    
    for filepath in files:
        if process_file(filepath):
            print(f"Fixed: {filepath}")
            fixed_count += 1
    
    print(f"\nCompleted: {fixed_count}/{total_count} files were modified")

if __name__ == "__main__":
    main()
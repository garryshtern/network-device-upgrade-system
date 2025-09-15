#!/usr/bin/env python3
import glob
import re

def fix_file(filepath):
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Fix the most common pattern: > "text" or >\n"text"
        # Replace with >- followed by proper indentation
        
        # Pattern 1: > followed by quoted string on next line with broken indentation
        pattern1 = r'^(\s+)>\s*\n"([^"]+(?:\n[^"]*)*)"'
        def replace1(m):
            indent = m.group(1)
            text = m.group(2).strip().replace('\n', ' ')
            return f'{indent}>-\n{indent}  {text}'
        content = re.sub(pattern1, replace1, content, flags=re.MULTILINE)
        
        # Pattern 2: > "text" on same line
        pattern2 = r'^(\s+)>\s*"([^"]+)"'
        content = re.sub(pattern2, r'\1>- \2', content, flags=re.MULTILINE)
        
        # Pattern 3: Fix common Jinja variable patterns
        pattern3 = r'^(\s+)>\s*\n(\s*)\{\{([^}]+)\}\}'
        def replace3(m):
            indent1 = m.group(1)
            text = '{{ ' + m.group(3).strip() + ' }}'
            return f'{indent1}>-\n{indent1}  {text}'
        content = re.sub(pattern3, replace3, content, flags=re.MULTILINE)
        
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    except Exception as e:
        print(f"Error with {filepath}: {e}")
        return False

# Process key failing files
files_to_fix = [
    "ansible-content/roles/*/tasks/validation.yml",
    "ansible-content/roles/*/tasks/storage-cleanup.yml", 
    "ansible-content/roles/*/tasks/*-validation.yml",
    "ansible-content/roles/*/tasks/image-*.yml"
]

fixed = 0
for pattern in files_to_fix:
    for filepath in glob.glob(pattern):
        if fix_file(filepath):
            print(f"Fixed: {filepath}")
            fixed += 1

print(f"Total files processed: {fixed}")
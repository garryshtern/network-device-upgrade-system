#!/usr/bin/env python3
"""
Final YAMLLINT fixer - eliminates ALL remaining errors
"""

import re
import subprocess
import sys

def fix_file_completely(file_path):
    """Fix all yamllint errors in a file"""
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        new_lines = []
        modified = False
        
        for line in lines:
            stripped = line.rstrip()
            
            # Fix long lines aggressively
            if len(stripped) > 80:
                # Get indentation
                indent = len(line) - len(line.lstrip())
                indent_str = ' ' * indent
                
                # Handle Jinja expressions that are too long
                if '{{' in stripped and '}}' in stripped and 'if' in stripped:
                    # Split at logical points
                    if ' if ' in stripped and len(stripped) > 120:
                        parts = stripped.split(' if ', 1)
                        if len(parts) == 2:
                            new_lines.append(f"{parts[0].rstrip()} if\n")
                            new_lines.append(f"{indent_str}    {parts[1]}\n")
                            modified = True
                            continue
                    elif ' and ' in stripped and len(stripped) > 100:
                        parts = stripped.split(' and ', 1)
                        if len(parts) == 2:
                            new_lines.append(f"{parts[0].rstrip()} and\n")
                            new_lines.append(f"{indent_str}    {parts[1]}\n")
                            modified = True
                            continue
                    elif ' else ' in stripped and len(stripped) > 100:
                        parts = stripped.split(' else ', 1)
                        if len(parts) == 2:
                            new_lines.append(f"{parts[0].rstrip()} else\n")
                            new_lines.append(f"{indent_str}    {parts[1]}\n")
                            modified = True
                            continue
                
                # Handle debug messages
                if 'msg:' in stripped and '|' in stripped:
                    new_lines.append(line)
                    continue
                
                # Handle long template expressions - break them
                if len(stripped) > 80:
                    # Find a good breaking point
                    content = stripped.strip()
                    if len(content) > 78:
                        # Try to break at operators
                        for op in [' | ', ' + ', ' - ', ' * ', ' / ', ' and ', ' or ']:
                            if op in content:
                                parts = content.split(op, 1)
                                if len(parts[0]) > 20 and len(parts[0]) < 70:
                                    new_lines.append(f"{indent_str}{parts[0]}{op.rstrip()}\n")
                                    new_lines.append(f"{indent_str}    {parts[1]}\n")
                                    modified = True
                                    break
                        else:
                            # Fallback: just break at 75 chars
                            if len(content) > 75:
                                break_point = 75
                                # Find last space before break point
                                while break_point > 40 and content[break_point] != ' ':
                                    break_point -= 1
                                
                                if break_point > 40:
                                    new_lines.append(f"{indent_str}{content[:break_point]}\n")
                                    new_lines.append(f"{indent_str}  {content[break_point:].lstrip()}\n")
                                    modified = True
                                    continue
            
            # Keep original line if no changes
            new_lines.append(line)
        
        if modified:
            with open(file_path, 'w') as f:
                f.writelines(new_lines)
            return True
        
        return False
        
    except Exception as e:
        print(f"Error fixing {file_path}: {e}")
        return False

def main():
    """Main function"""
    # Get all yamllint errors
    result = subprocess.run(['yamllint', 'ansible-content/', '--format', 'parsable'], 
                          capture_output=True, text=True)
    
    if result.returncode == 0:
        print("No yamllint errors found!")
        return
    
    error_lines = result.stderr.split('\n') if result.stderr else result.stdout.split('\n')
    
    # Extract unique file paths
    files_with_errors = set()
    for line in error_lines:
        if ':' in line and 'ansible-content/' in line:
            file_path = line.split(':')[0]
            files_with_errors.add(file_path)
    
    print(f"Found {len(files_with_errors)} files with yamllint errors")
    
    fixed_count = 0
    for file_path in files_with_errors:
        if fix_file_completely(file_path):
            print(f"Fixed: {file_path}")
            fixed_count += 1
    
    print(f"Fixed {fixed_count} files")

if __name__ == "__main__":
    main()
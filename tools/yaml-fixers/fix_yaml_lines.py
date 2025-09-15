#!/usr/bin/env python3
"""
Script to automatically fix YAML line length violations
Converts lines > 80 characters to use YAML folding operators
"""

import os
import re
import subprocess
import sys

def fix_yaml_line_length(file_path):
    """Fix YAML line length violations in a file"""
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        modified = False
        new_lines = []
        
        for i, line in enumerate(lines):
            # Strip trailing whitespace but preserve leading indentation
            stripped = line.rstrip()
            
            # If line is too long (>80 chars), try to fold it
            if len(stripped) > 80:
                # Get indentation
                indent = len(line) - len(line.lstrip())
                indent_str = ' ' * indent
                
                # Handle different YAML patterns
                content = stripped.strip()
                
                # Pattern 1: YAML value assignments (key: value)
                if ': ' in content and not content.startswith('-'):
                    key_part, value_part = content.split(': ', 1)
                    if len(value_part) > 40:  # Only fold if value is long enough
                        new_lines.append(f"{indent_str}{key_part}: >\n")
                        new_lines.append(f"{indent_str}  {value_part}\n")
                        modified = True
                        continue
                
                # Pattern 2: List items that are too long
                elif content.startswith('- ') and len(content) > 80:
                    list_content = content[2:]  # Remove '- '
                    new_lines.append(f"{indent_str}- >\n")
                    new_lines.append(f"{indent_str}  {list_content}\n")
                    modified = True
                    continue
                
                # Pattern 3: Debug messages and templates
                elif 'msg:' in content or 'fail_msg:' in content:
                    key_part, value_part = content.split(': ', 1)
                    new_lines.append(f"{indent_str}{key_part}: >\n")
                    new_lines.append(f"{indent_str}  {value_part}\n")
                    modified = True
                    continue
                
                # Pattern 4: Ansible conditions and expressions
                elif content.strip().startswith('that:') or 'when:' in content:
                    # Keep as-is for now, these need manual review
                    new_lines.append(line)
                    continue
                
                # Pattern 5: Comments - split long comments
                elif content.strip().startswith('#'):
                    if len(content) > 80:
                        # Split long comments
                        comment_text = content.strip()[1:].strip()
                        words = comment_text.split()
                        lines_to_add = []
                        current_line = f"{indent_str}#"
                        
                        for word in words:
                            if len(current_line + ' ' + word) <= 78:
                                current_line += ' ' + word
                            else:
                                lines_to_add.append(current_line + '\n')
                                current_line = f"{indent_str}# {word}"
                        
                        if current_line.strip() != f"{indent_str}#".strip():
                            lines_to_add.append(current_line + '\n')
                        
                        new_lines.extend(lines_to_add)
                        modified = True
                        continue
                
                # Pattern 6: YAML list items with complex expressions
                elif '- ' in content and '{{' in content and '}}' in content:
                    parts = content.split('{{', 1)
                    if len(parts) == 2:
                        prefix = parts[0].strip()
                        remaining = '{{' + parts[1]
                        new_lines.append(f"{indent_str}{prefix}\n")
                        new_lines.append(f"{indent_str}  {remaining}\n")
                        modified = True
                        continue
                
                # Pattern 7: Long ansible module calls
                elif any(module in content for module in ['ansible.builtin.', 'cisco.', 'fortinet.', 'register:']):
                    # Keep as-is for module calls, they may need manual review
                    new_lines.append(line)
                    continue
            
            # Keep original line if no changes needed
            new_lines.append(line)
        
        if modified:
            with open(file_path, 'w') as f:
                f.writelines(new_lines)
            return True
        
        return False
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    """Main function to process all YAML files"""
    if len(sys.argv) != 2:
        print("Usage: python3 fix_yaml_lines.py <directory>")
        sys.exit(1)
    
    directory = sys.argv[1]
    
    # Find all YAML files
    yaml_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(('.yml', '.yaml')):
                yaml_files.append(os.path.join(root, file))
    
    print(f"Found {len(yaml_files)} YAML files to process")
    
    fixed_count = 0
    for yaml_file in yaml_files:
        if fix_yaml_line_length(yaml_file):
            print(f"Fixed: {yaml_file}")
            fixed_count += 1
    
    print(f"\nProcessing complete. Fixed {fixed_count} files.")

if __name__ == "__main__":
    main()
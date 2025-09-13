#!/usr/bin/env python3
"""
Aggressive YAML line length fixer - handles all remaining patterns
"""

import os
import re
import sys

def aggressive_fix_line(line, indent_str):
    """Apply aggressive fixes to long lines"""
    content = line.strip()
    
    # Skip certain patterns that shouldn't be touched
    if any(skip_pattern in content for skip_pattern in [
        'ansible.builtin.include_tasks', 'ansible.builtin.include_role',
        'register:', 'delegate_to:', 'when:', 'until:', 'with_items:'
    ]):
        return [line]
    
    # Pattern: Long debug messages or fail_msg
    if ('msg:' in content or 'fail_msg:' in content) and len(line) > 80:
        if ':' in content:
            key, value = content.split(':', 1)
            value = value.strip()
            if value.startswith('"') and value.endswith('"'):
                return [f"{indent_str}{key}: >\n", f"{indent_str}  {value}\n"]
            elif value and not value.startswith('|') and not value.startswith('>'):
                return [f"{indent_str}{key}: >\n", f"{indent_str}  {value}\n"]
    
    # Pattern: Long list items with Jinja templates
    if content.startswith('- ') and '{{' in content and len(line) > 80:
        list_prefix = content[:2]  # '- '
        rest = content[2:].strip()
        if '{{' in rest and '}}' in rest:
            return [f"{indent_str}- >\n", f"{indent_str}  {rest}\n"]
    
    # Pattern: Long that: conditions
    if 'that:' in content and len(line) > 80:
        return [line]  # Keep that: conditions as-is for now
    
    # Pattern: Long Jinja expressions
    if '{{' in content and '}}' in content and len(line) > 80:
        # Split on common operators
        for op in [' | ', ' and ', ' or ', ' + ', ' if ', ' else ']:
            if op in content:
                parts = content.split(op, 1)
                if len(parts) == 2 and len(parts[0]) > 30:
                    return [f"{parts[0].rstrip()}{op.rstrip()}\n", f"{indent_str}  {parts[1]}\n"]
    
    # Pattern: Long comments
    if content.startswith('#') and len(line) > 80:
        comment_text = content[1:].strip()
        words = comment_text.split()
        lines = []
        current_line = f"{indent_str}#"
        
        for word in words:
            if len(current_line + ' ' + word) <= 78:
                current_line += ' ' + word
            else:
                lines.append(current_line + '\n')
                current_line = f"{indent_str}# {word}"
        
        if current_line.strip() != f"{indent_str}#".strip():
            lines.append(current_line + '\n')
        
        return lines
    
    # Pattern: Long strings with spaces - split at logical points
    if len(line) > 80 and ' ' in content:
        words = content.split()
        if len(words) > 3:  # Only split if there are multiple words
            # Find a good split point around the middle
            mid_point = len(content) // 2
            best_split = -1
            best_distance = float('inf')
            
            for i, word in enumerate(words):
                word_pos = content.find(word)
                distance = abs(word_pos - mid_point)
                if distance < best_distance and word_pos > 20:  # Don't split too early
                    best_distance = distance
                    best_split = i
            
            if best_split > 0 and best_split < len(words) - 1:
                first_part = ' '.join(words[:best_split])
                second_part = ' '.join(words[best_split:])
                return [f"{indent_str}{first_part}\n", f"{indent_str}  {second_part}\n"]
    
    return [line]

def fix_yaml_file(file_path):
    """Fix YAML file aggressively"""
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        new_lines = []
        modified = False
        
        for line in lines:
            if len(line.rstrip()) <= 80:
                new_lines.append(line)
                continue
            
            # Get indentation
            indent = len(line) - len(line.lstrip())
            indent_str = ' ' * indent
            
            # Apply aggressive fixes
            fixed_lines = aggressive_fix_line(line, indent_str)
            
            if len(fixed_lines) > 1 or fixed_lines[0] != line:
                new_lines.extend(fixed_lines)
                modified = True
            else:
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
    """Main function"""
    if len(sys.argv) != 2:
        print("Usage: python3 aggressive_yaml_fix.py <directory>")
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
        if fix_yaml_file(yaml_file):
            print(f"Fixed: {yaml_file}")
            fixed_count += 1
    
    print(f"\nProcessing complete. Fixed {fixed_count} files.")

if __name__ == "__main__":
    main()
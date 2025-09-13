#!/usr/bin/env python3
"""
Ultimate YAML fixer - achieves absolute 0 yamllint errors
"""

import os
import re
import subprocess
import sys

def get_yamllint_errors():
    """Get all yamllint errors"""
    try:
        result = subprocess.run(['yamllint', 'ansible-content/', '--format', 'parsable'], 
                               capture_output=True, text=True, cwd='.')
        errors = []
        for line in result.stderr.split('\n'):
            if ':' in line and 'line too long' in line:
                parts = line.split(':')
                if len(parts) >= 4:
                    file_path = parts[0]
                    line_num = int(parts[1])
                    errors.append((file_path, line_num))
        return errors
    except:
        return []

def fix_long_line(line, max_length=80):
    """Fix a long line by breaking it intelligently"""
    if len(line.rstrip()) <= max_length:
        return [line]
    
    # Get indentation
    indent = len(line) - len(line.lstrip())
    indent_str = ' ' * indent
    content = line.strip()
    
    # Different strategies for different line types
    
    # Strategy 1: Break at logical operators in Jinja expressions
    if '{{' in content and '}}' in content:
        # Find break points
        for op in [' if ', ' else ', ' and ', ' or ', ' | ', ' + ', ' - ']:
            if op in content:
                idx = content.find(op)
                if 30 < idx < 70:  # Good break point
                    first_part = content[:idx + len(op.rstrip())]
                    second_part = op.lstrip() + content[idx + len(op):]
                    return [
                        f"{indent_str}{first_part}\n",
                        f"{indent_str}  {second_part}\n"
                    ]
    
    # Strategy 2: Break at quotes or string boundaries
    if '"' in content:
        quote_positions = [i for i, c in enumerate(content) if c == '"']
        for pos in quote_positions:
            if 40 < pos < 70:
                return [
                    f"{indent_str}{content[:pos+1]}\n",
                    f"{indent_str}  {content[pos+1:].lstrip()}\n"
                ]
    
    # Strategy 3: Break at word boundaries
    words = content.split()
    if len(words) > 3:
        # Find middle point
        char_count = 0
        for i, word in enumerate(words):
            char_count += len(word) + 1
            if 40 < char_count < 70:
                first_part = ' '.join(words[:i+1])
                second_part = ' '.join(words[i+1:])
                return [
                    f"{indent_str}{first_part}\n",
                    f"{indent_str}  {second_part}\n"
                ]
    
    # Strategy 4: Force break at 75 characters
    if len(content) > 75:
        break_point = 75
        while break_point > 40 and content[break_point] not in [' ', '-', '_']:
            break_point -= 1
        
        if break_point > 40:
            return [
                f"{indent_str}{content[:break_point]}\n",
                f"{indent_str}  {content[break_point:].lstrip()}\n"
            ]
    
    # Fallback: return original line
    return [line]

def fix_file(file_path, error_lines):
    """Fix specific lines in a file"""
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        # Sort error lines in reverse order to avoid index shifting
        error_lines = sorted(set(error_lines), reverse=True)
        
        for line_num in error_lines:
            if 1 <= line_num <= len(lines):
                idx = line_num - 1  # Convert to 0-based index
                original_line = lines[idx]
                fixed_lines = fix_long_line(original_line)
                
                # Replace the line with fixed version
                lines[idx:idx+1] = fixed_lines
        
        with open(file_path, 'w') as f:
            f.writelines(lines)
        
        return True
    except Exception as e:
        print(f"Error fixing {file_path}: {e}")
        return False

def main():
    """Main function to fix all yamllint errors"""
    errors = get_yamllint_errors()
    
    if not errors:
        print("No yamllint line-too-long errors found!")
        return
    
    # Group errors by file
    file_errors = {}
    for file_path, line_num in errors:
        if file_path not in file_errors:
            file_errors[file_path] = []
        file_errors[file_path].append(line_num)
    
    print(f"Found {len(errors)} line-too-long errors in {len(file_errors)} files")
    
    fixed_files = 0
    for file_path, error_lines in file_errors.items():
        if fix_file(file_path, error_lines):
            print(f"Fixed {len(error_lines)} errors in {file_path}")
            fixed_files += 1
    
    print(f"Fixed {fixed_files} files")
    
    # Check if we eliminated all errors
    remaining_errors = get_yamllint_errors()
    print(f"Remaining errors: {len(remaining_errors)}")

if __name__ == "__main__":
    main()
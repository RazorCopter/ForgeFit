import re
import os

with open('backend/main.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

def extract_routes(prefixes):
    extracted = []
    new_lines = []
    in_route = False
    current_route = []
    
    for line in lines:
        if line.startswith('@app.'):
            # Check if this route matches our prefixes
            match = False
            for p in prefixes:
                if f'"{p}' in line or f"'{p}" in line:
                    match = True
                    break
            
            if match:
                in_route = True
                current_route = [line]
            else:
                if in_route:
                    # Previous route ended, but wait, this is a new route, so the previous route was fully captured.
                    extracted.extend(current_route)
                    current_route = []
                in_route = False
                new_lines.append(line)
        elif in_route:
            current_route.append(line)
            # A route function ends when a new top-level definition starts, or empty lines between functions.
            # But the safest is checking for start of next top-level statement which is not def/async def and no indentation.
            # Actually, parsing like this is risky.
            pass
        else:
            new_lines.append(line)

# This is too fragile.

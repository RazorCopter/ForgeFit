import re

file_path = 'backend/main.py'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix double comma
content = content.replace(',,\n                video_url=', ',\n                video_url=')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed double comma in main.py!")

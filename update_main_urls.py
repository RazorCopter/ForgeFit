import re

file_path = 'backend/main.py'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

urls = {
    "Chest Press Machine": "https://www.youtube.com/watch?v=dYF2d_I24uE",
    "Croci ai Cavi dal basso": "https://www.youtube.com/watch?v=jzKDCuJVLjo",
    "Croci ai Cavi dall'alto": "https://www.youtube.com/watch?v=-kZ5A7aPiCw",
    "Panca Piana Bilanciere": "https://www.youtube.com/watch?v=nclAIgM4NJE",
    "Spinte Panca Inclinata Manubri": "https://www.youtube.com/watch?v=Hujpl-ujRtg",
    "Rematore Manubrio singolo": "https://www.youtube.com/watch?v=1e-Ks7gpp44",
    "Alzate Laterali Manubri": "https://www.youtube.com/watch?v=PhFOzmpjUak",
    "Arnold Press Manubri": "https://www.youtube.com/watch?v=hyLSswC97MA",
    "Face Pull ai cavi altezza occhi": "https://www.youtube.com/watch?v=0Po47vvj9g4",
    "Military Press Bilanciere": "https://www.youtube.com/watch?v=e2Waz_LKmNQ",
    "Curl Manubri alternato": "https://www.youtube.com/watch?v=RhVdFHcHKDE",
    "Estensioni dietro nuca al cavo": "https://www.youtube.com/shorts/U5Fi0VQpzmc",
    "French Press Bilanciere EZ": "https://www.youtube.com/watch?v=FANzZyWdmbs",
    "Pushdown Tricipiti ai cavi con corda": "https://www.youtube.com/watch?v=vdwP7HxDAo4",
    "Crunch al cavo inginocchiato": "https://www.youtube.com/watch?v=um0ZlKz30KQv"
}

for name, url in urls.items():
    # Find the models.ExerciseCatalog block for this name
    pattern = rf'(models\.ExerciseCatalog\(\s*nome="{name}",.*?)(\n\s*\),)'
    
    def replacer(match):
        block = match.group(1)
        if "video_url" not in block:
            # We want to insert the video_url before the closing parenthesis.
            # But the block is actually matched without the closing parenthesis.
            # We can just append it.
            return block + f',\n                video_url="{url}"' + match.group(2)
        return match.group(0)

    content = re.sub(pattern, replacer, content, flags=re.DOTALL)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated main.py!")

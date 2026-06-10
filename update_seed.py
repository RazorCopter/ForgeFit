import re

file_path = 'backend/main.py'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Instead of returning early, we can update existing entries
replacement = """    try:
        count = db.query(models.ExerciseCatalog).count()

        esercizi = ["""

content = content.replace("""    try:
        if db.query(models.ExerciseCatalog).count() > 0:
            logger.info("Catalogo esercizi già popolato — seeding saltato.")
            return

        logger.info("Tabella ExerciseCatalog vuota — avvio seeding catalogo...")

        esercizi = [""", replacement)

# Now find the end of the array and the add_all
replacement2 = """        ]

        if count == 0:
            logger.info("Tabella ExerciseCatalog vuota — avvio seeding catalogo...")
            db.add_all(esercizi)
            db.commit()
            logger.info(f"Seeding completato: {len(esercizi)} esercizi inseriti nel catalogo.")
        else:
            # Aggiornamento dei record esistenti (per video_url e altri default)
            for ex in esercizi:
                db_ex = db.query(models.ExerciseCatalog).filter(models.ExerciseCatalog.nome == ex.nome).first()
                if db_ex:
                    if ex.video_url and not db_ex.video_url:
                        db_ex.video_url = ex.video_url
                else:
                    db.add(ex)
            db.commit()
            logger.info("Catalogo esercizi aggiornato con successo.")
"""

content = content.replace("""        ]

        db.add_all(esercizi)
        db.commit()
        logger.info(f"Seeding completato: {len(esercizi)} esercizi inseriti nel catalogo.")""", replacement2)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated seed_catalog logic!")

# Usa un'immagine Python ufficiale e leggera
FROM python:3.11-slim

# Imposta la directory di lavoro nel container
WORKDIR /app

# Copia prima il file dei requisiti (sfrutta la cache di Docker)
COPY requirements.txt .

# Installa le dipendenze
RUN pip install --no-cache-dir -r requirements.txt

# Copia il resto del codice dell'applicazione (inclusa la cartella static)
COPY . .

# Esponi la porta su cui gira FastAPI
EXPOSE 8000

# Comando di avvio del server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
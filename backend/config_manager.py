# config_manager.py
# Gestione della configurazione dell'Amministratore (Personal Trainer)
# salvata su file JSON invece che sul database dei clienti.

import json
import os
import tempfile
from typing import Optional, Dict

CONFIG_PATH = "data/admin_config.json"

def get_admin_config() -> Optional[Dict]:
    """
    Carica la configurazione dell'admin dal file JSON.
    Restituisce un dizionario con 'pt_name', 'username', 'hashed_password'
    o None se il file non esiste.
    """
    if not os.path.exists(CONFIG_PATH):
        return None
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None

def save_admin_config(pt_name: str, username: str, hashed_password: str) -> bool:
    """
    Salva le credenziali dell'admin nel file JSON in modo atomico:
    scrive su un file temporaneo nella stessa directory e poi esegue
    os.replace() — operazione atomica su tutti i sistemi POSIX e su Windows.
    Questo previene la corruzione del file in caso di crash durante la scrittura.
    """
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    config = {
        "pt_name": pt_name,
        "username": username,
        "hashed_password": hashed_password
    }
    try:
        dir_path = os.path.dirname(os.path.abspath(CONFIG_PATH))
        fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".tmp")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                json.dump(config, f, indent=4)
            os.replace(tmp_path, CONFIG_PATH)
        except Exception:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
            raise
        return True
    except Exception:
        return False

def is_admin_configured() -> bool:
    """Restituisce True se il file di configurazione dell'admin esiste."""
    return os.path.exists(CONFIG_PATH)

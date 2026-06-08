# config_manager.py
# Gestione della configurazione dell'Amministratore (Personal Trainer)
# salvata su file JSON invece che sul database dei clienti.

import json
import os
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
    Salva le credenziali dell'admin nel file JSON.
    Crea la cartella 'data' se non esiste.
    """
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    config = {
        "pt_name": pt_name,
        "username": username,
        "hashed_password": hashed_password
    }
    try:
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=4)
        return True
    except Exception:
        return False

def is_admin_configured() -> bool:
    """Restituisce True se il file di configurazione dell'admin esiste."""
    return os.path.exists(CONFIG_PATH)

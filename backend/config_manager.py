# config_manager.py
# Gestione della configurazione dell'Amministratore (Personal Trainer)
# salvata su file JSON invece che sul database dei clienti.

import json
import os
import time
import tempfile
from pathlib import Path
from typing import Optional, Dict

CONFIG_PATH = Path(__file__).parent / "data" / "admin_config.json"

_cached_config: Optional[Dict] = None
_cache_mtime: float = 0.0
_CACHE_TTL_SECONDS: float = 5.0

def get_admin_config() -> Optional[Dict]:
    """
    Carica la configurazione dell'admin dal file JSON con cache TTL di 5s.
    Evita file I/O ad ogni request autenticata.
    """
    global _cached_config, _cache_mtime
    now = time.monotonic()
    if _cached_config is not None and (now - _cache_mtime) < _CACHE_TTL_SECONDS:
        return _cached_config
    if not CONFIG_PATH.exists():
        return None
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            _cached_config = json.load(f)
        _cache_mtime = now
        return _cached_config
    except Exception:
        return None

def invalidate_config_cache() -> None:
    global _cached_config
    _cached_config = None

def save_admin_config(pt_name: str, username: str, hashed_password: str) -> bool:
    """
    Salva le credenziali dell'admin nel file JSON in modo atomico:
    scrive su un file temporaneo nella stessa directory e poi esegue
    os.replace() — operazione atomica su tutti i sistemi POSIX e su Windows.
    Questo previene la corruzione del file in caso di crash durante la scrittura.
    """
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    config = {
        "pt_name": pt_name,
        "username": username,
        "hashed_password": hashed_password
    }
    try:
        fd, tmp_path = tempfile.mkstemp(dir=str(CONFIG_PATH.parent), suffix=".tmp")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                json.dump(config, f, indent=4)
            os.replace(tmp_path, CONFIG_PATH)
            invalidate_config_cache()
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
    return CONFIG_PATH.exists()

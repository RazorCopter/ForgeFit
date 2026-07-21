# Versioning e processo di release

ForgeFit usa **Semantic Versioning** nel formato `MAJOR.MINOR.PATCH`.

- `MAJOR`: modifica incompatibile di API, dati locali o schema senza migrazione trasparente.
- `MINOR`: nuova capability compatibile, per esempio un nuovo flusso di allenamento.
- `PATCH`: correzione compatibile senza nuova capability pubblica.

## Sorgenti di versione

Ogni release deve aggiornare insieme:

1. `frontend/pubspec.yaml`: versione prodotto più build number, es. `2.3.0+75`;
2. `frontend/lib/core/app_version.dart`: versione mostrata dall'app;
3. `backend/version.py`: versione API restituita da `/api/system/version`;
4. `frontend/web/index.html`: titolo della web app;
5. `frontend/web/flutter_service_worker.js`: namespace della cache;
6. `CHANGELOG.md`: contenuto effettivamente consegnato.

Il build number Flutter cresce sempre, anche per build scartate destinate agli store. Non viene riutilizzato.

## Branch e commit

- Nuovo sviluppo: `feat/<versione>-<descrizione>`.
- Correzione urgente: `fix/<versione>-<descrizione>`.
- Commit secondo Conventional Commits: `feat:`, `fix:`, `test:`, `docs:`, `chore:`.
- Le modifiche utente locali e i secret non devono essere inclusi nei commit di release.

## Gate prima del push

- `python -m pytest -q` nel backend;
- `flutter analyze` senza errori;
- `flutter test` senza failure;
- `python -m compileall -q backend execution`;
- `docker compose config --quiet`;
- `git diff --check`;
- scansione dei file staged per credenziali;
- checklist di `plan.md` aggiornata senza dichiarare completate attività ancora aperte.

## Pubblicazione

1. creare e pubblicare il branch di release;
2. aprire/revisionare la pull request verso `main`;
3. eseguire nuovamente i gate in CI;
4. unire con storia leggibile;
5. creare tag annotato `vMAJOR.MINOR.PATCH` sul commit effettivamente distribuito;
6. generare build Android/iOS usando il build number di `pubspec.yaml`;
7. conservare note di rollback e migrazione dati.

## Release corrente

- Versione prodotto: `2.4.0`
- Build Flutter: `76`
- Branch previsto: `feat/2.4.0-premium-ui`
- Compatibilità dati: nessuna migrazione Hive o SQLite richiesta
- Tag distribuzione: `v2.4.0`
- Stato: release premium UI validata e pronta al deploy; bonifica della cronologia Git ancora aperta

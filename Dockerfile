# ==========================================
# STAGE 1: L'Officina (Build)
# ==========================================
# Usiamo un'immagine ufficiale che ha già Flutter installato
FROM ghcr.io/cirruslabs/flutter:stable AS builder

# Creiamo la cartella di lavoro nel container
WORKDIR /app

# Copiamo tutto il codice sorgente (tranne quello nel .dockerignore)
COPY . .

# Compiliamo l'app in versione release
RUN flutter clean
RUN flutter pub get
RUN flutter build web --release

# ==========================================
# STAGE 2: La Vetrina (Produzione)
# ==========================================
# Usiamo Nginx, un server web ultra-leggero e velocissimo
FROM nginx:alpine

# Rimuoviamo la pagina di default di Nginx
RUN rm -rf /usr/share/nginx/html/*

# COPPIA MAGICA: Prendiamo SOLO la cartella /build/web finita 
# dallo STAGE 1 e la mettiamo nella cartella pubblica di Nginx.
# Tutto il resto (codice sorgente, Flutter) viene distrutto e scartato!
COPY --from=builder /app/build/web /usr/share/nginx/html

# (Opzionale ma vitale per le PWA) Copiamo un file di conf personalizzato
# per gestire i refresh delle pagine su app single-page come Flutter
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Esponiamo la porta 80 del container
EXPOSE 80

# Avviamo Nginx
CMD ["nginx", "-g", "daemon off;"]
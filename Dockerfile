# Usa un'immagine Nginx leggerissima
FROM nginx:stable-alpine

# Copia i file già compilati dalla tua cartella locale alla cartella di Nginx
COPY build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
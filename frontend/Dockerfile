FROM node:18-alpine

# Instala dependencias necesarias para compilar y ejecutar npm global installs
RUN apk add --no-cache bash curl make gcc g++ python3 libc6-compat

# Ahora instala http-server globalmente con permisos adecuados
RUN npm install -g http-server --unsafe-perm=true --allow-root

WORKDIR /app

COPY frontend/build/web/ .

COPY cert.pem /cert.pem
COPY key.pem /key.pem

EXPOSE 8080

CMD ["http-server", "-p", "8080", "-S", "-C", "/cert.pem", "-K", "/key.pem", "-a", "0.0.0.0"]

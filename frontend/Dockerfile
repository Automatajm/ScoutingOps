# Dockerfile simple para Flutter Web
FROM node:18-alpine

# Instalar dependencias
RUN apk add --no-cache wget curl && \
    npm install -g http-server@14.1.1

# Crear usuario
RUN addgroup -g 1001 -S flutter && \
    adduser -S flutteruser -u 1001

# Configurar app
WORKDIR /app
COPY build/web/ /app/web/

# Copiar certificados desde frontend/
COPY *.pem /app/certs/
RUN ls -la /app/certs/

# Permisos
RUN chown -R flutteruser:flutter /app
USER flutteruser

EXPOSE 8080

# Comando simple
CMD ["sh", "-c", "if [ -f /app/certs/cert.pem ]; then http-server /app/web -p 8080 -S -C /app/certs/cert.pem -K /app/certs/key.pem -a 0.0.0.0 --cors; else http-server /app/web -p 8080 -a 0.0.0.0 --cors; fi"]
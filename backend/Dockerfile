# Backend Dockerfile - Node.js con SSL
FROM node:18-alpine

# Instalar dependencias del sistema
RUN apk add --no-cache \
    wget \
    curl \
    openssl \
    && rm -rf /var/cache/apk/*

# Crear directorio de trabajo
WORKDIR /app

# Crear usuario no-root para seguridad
RUN addgroup -g 1001 -S nodejs && \
    adduser -S pestcontrol -u 1001

# Copiar archivos de dependencias
COPY package*.json ./

# Instalar dependencias de producción
RUN npm ci --only=production && \
    npm cache clean --force

# Copiar certificados SSL PRIMERO
COPY certs/ /app/certs/

# Copiar resto del código fuente
COPY . .

# Verificar que los certificados estén presentes
RUN ls -la /app/certs/ && \
    test -f /app/certs/cert.pem && \
    test -f /app/certs/key.pem && \
    echo "✅ Certificados SSL encontrados" || \
    (echo "❌ Error: Certificados SSL no encontrados" && exit 1)

# Crear directorios necesarios
RUN mkdir -p /app/certs /app/logs && \
    chown -R pestcontrol:nodejs /app

# Exponer puerto HTTPS
EXPOSE 8000

# Cambiar al usuario no-root
USER pestcontrol

# Comando de inicio
CMD ["npm", "start"]
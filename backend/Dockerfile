FROM node:18-alpine

RUN apk add --no-cache python3 make g++ openssl postgresql-client

WORKDIR /app

COPY backend/ .

RUN rm -rf node_modules && \
    npm install && \
    npm rebuild bcrypt --build-from-source && \
    npm install express-rate-limit

COPY cert.pem /cert.pem
COPY key.pem /key.pem

RUN mkdir -p logs uploads

EXPOSE 8000

CMD ["npm", "run", "start:prod"]

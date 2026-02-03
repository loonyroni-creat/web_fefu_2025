FROM nginx:alpine

# удаляем дефолт
RUN rm /etc/nginx/conf.d/default.conf

# копируем наш конфиг
COPY default.conf /etc/nginx/conf.d/

# создаём папки для статики
RUN mkdir -p /app/static /app/media

# healthcheck
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -q --spider http://localhost/ || exit 1

EXPOSE 80

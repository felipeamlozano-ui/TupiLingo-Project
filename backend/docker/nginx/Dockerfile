# =============================================================
# Dockerfile — TupiLingo Nginx (Produção)
# =============================================================

FROM nginx:1.27-alpine

# Remove configuração padrão
RUN rm /etc/nginx/conf.d/default.conf

# Copia configurações customizadas
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf

# Cria diretório para logs e arquivos estáticos
RUN mkdir -p /var/log/nginx /app/staticfiles /app/media \
    && chown -R nginx:nginx /var/log/nginx

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://localhost/api/health/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

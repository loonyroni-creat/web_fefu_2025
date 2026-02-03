########################
# ===== BUILDER ===== #
########################
FROM python:3.12 AS builder

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# системные зависимости для сборки psycopg2 и прочего
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --upgrade pip
RUN pip install --user -r requirements.txt

COPY . .

# собираем статику на этапе билда
RUN python manage.py collectstatic --noinput


############################
# ===== PRODUCTION ===== #
############################
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app

# только runtime зависимости
RUN apt-get update && apt-get install -y \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# создаём непривилегированного пользователя (безопасность + баллы)
RUN useradd -m appuser

# копируем только нужное
COPY --from=builder /root/.local /root/.local
COPY --from=builder /app /app

RUN chown -R appuser:appuser /app

USER appuser

# entrypoint будет ждать БД
ENTRYPOINT ["./entrypoint.sh"]

CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]

# E2E Testing Base Image
# Базовый образ для E2E-тестирования веб-приложений с реальными браузерами
#
# Включает:
# - Python 3.12
# - Playwright с установленными браузерами (Chromium, Firefox, WebKit)
# - Все системные зависимости для запуска браузеров в Docker
#
# Использование:
#   FROM ghcr.io/morli/e2e-base:v1.51.0
#
# Версия Playwright: 1.51.0
# Базовый образ: mcr.microsoft.com/playwright/python (Ubuntu Noble)

FROM mcr.microsoft.com/playwright/python:v1.51.0-noble

# Метаданные образа
LABEL maintainer="morli"
LABEL description="Base image for E2E testing with Playwright browsers (Chromium, Firefox, WebKit)"
LABEL playwright.version="1.51.0"
LABEL python.version="3.12"

# Установить общие инструменты для удобной работы
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Создать рабочую директорию по умолчанию
WORKDIR /app

# Проверка установки Playwright (health check)
RUN python -c "from playwright.sync_api import sync_playwright; print('Playwright OK')"

# Информация о браузерах (для отладки)
RUN playwright --version && \
    echo "Installed browsers:" && \
    ls -lah /ms-playwright/

# По умолчанию запускаем shell (можно переопределить в проектах)
CMD ["/bin/bash"]

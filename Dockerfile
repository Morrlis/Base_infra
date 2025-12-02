# E2E Testing Base Image
# Базовый образ с Playwright и браузерами (Chromium, Firefox, WebKit)
# Версия: 1.51.0

FROM mcr.microsoft.com/playwright/python:v1.51.0-noble

# Метаданные
LABEL maintainer="morli"
LABEL description="Base image for E2E testing with Playwright browsers"
LABEL playwright.version="1.51.0"

# Рабочая директория
WORKDIR /app

# Команда по умолчанию
CMD ["/bin/bash"]

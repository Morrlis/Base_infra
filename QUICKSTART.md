# Quick Start Guide

## Первый запуск (5 минут)

### 1. Создать репозиторий на GitHub

```bash
cd ~/Coding/Base_infra

# Инициализировать git
git init
git add .
git commit -m "Initial commit: E2E base image infrastructure"

# Создать репозиторий на GitHub (через web UI или gh CLI)
gh repo create Base_infra --public --source=. --remote=origin

# Загрузить код
git push -u origin main
```

### 2. Настроить права доступа

1. Перейди в репозиторий на GitHub
2. **Settings** → **Actions** → **General**
3. В разделе "Workflow permissions" выбери **"Read and write permissions"**
4. Сохрани

### 3. Собрать и опубликовать первую версию

```bash
# Создать тег версии
git tag v1.51.0
git push origin v1.51.0

# Подожди ~10 минут — GitHub Actions соберёт образ
# Проверь статус: https://github.com/morli/Base_infra/actions
```

### 4. Проверить, что образ доступен

```bash
# Скачать образ
docker pull ghcr.io/morli/e2e-base:v1.51.0

# Проверить версии
docker run --rm ghcr.io/morli/e2e-base:v1.51.0 playwright --version
# Output: Version 1.51.0
```

---

## Использование в проекте Harbor

### Вариант 1: Изменить Dockerfile (рекомендуется для будущего)

```dockerfile
# Harbor/infra/Dockerfile
FROM ghcr.io/morli/e2e-base:v1.51.0

WORKDIR /app

# Установить зависимости проекта
COPY requirements.txt .
RUN pip install --index-url https://mirrors.aliyun.com/pypi/simple \
    --no-cache-dir -r requirements.txt

# Скопировать код
COPY . .

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Вариант 2: Тестовый запуск (для проверки)

```bash
# Запустить тесты в контейнере с базовым образом
docker run --rm -v $(pwd):/app -w /app \
  ghcr.io/morli/e2e-base:v1.51.0 \
  bash -c "pip install -q -r requirements.txt && pytest tests/e2e -v"
```

---

## Обновление базового образа

```bash
# 1. Обновить версию в Dockerfile
sed -i 's/v1.51.0/v1.52.0/g' Dockerfile

# 2. Закоммитить
git add Dockerfile
git commit -m "chore: upgrade to Playwright 1.52.0"

# 3. Создать тег
git tag v1.52.0
git push origin main --tags

# 4. Подождать автосборку (~10 мин)
```

---

## Полезные команды

```bash
# Проверить размер образа
docker images ghcr.io/morli/e2e-base

# Посмотреть историю слоёв
docker history ghcr.io/morli/e2e-base:v1.51.0

# Запустить интерактивную оболочку
docker run --rm -it ghcr.io/morli/e2e-base:v1.51.0 bash

# Проверить установленные браузеры
docker run --rm ghcr.io/morli/e2e-base:v1.51.0 \
  bash -c "ls -lah /ms-playwright/"

# Удалить старые версии (экономия места)
docker rmi ghcr.io/morli/e2e-base:v1.50.0
```

---

## Если что-то пошло не так

### Проблема: CI/CD не запускается

**Решение:** Проверь права доступа (Settings → Actions → General → Read and write)

### Проблема: Image pull fails (unauthorized)

**Решение:**
```bash
# Авторизуйся в GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u morli --password-stdin
```

### Проблема: Образ слишком большой

**Ответ:** Это нормально для E2E тестирования (~1.5 GB). Браузеры занимают место, но это переиспользуется между проектами.

---

## Что дальше?

1. ✅ Базовый образ собран и опубликован
2. 📝 Обнови Dockerfile в проекте Harbor (когда будет нужно)
3. 🔄 Пересобери Harbor: `docker compose build`
4. ✅ E2E тесты теперь используют правильные Playwright-браузеры

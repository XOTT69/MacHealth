# 📋 Як залити на GitHub

## 1. Створити репозиторій
- https://github.com/new
- Назва: `MacHealth`
- Public, без README/gitignore/license

## 2. Завантажити файли
Перетягни ВСІ файли з цієї папки на GitHub.

## 3. Після завантаження — переіменувати:
- `github` → `.github` (через Edit файл на GitHub)
- `gitignore.txt` → `.gitignore`

## 4. Налаштувати Actions:
- Settings → Actions → General → Workflow permissions → "Read and write permissions" → Save

## 5. Створити Release:
- Releases → Create new release
- Tag: `v2.0.0`
- Publish!

GitHub Actions автоматично збере ZIP та додасть до Release.

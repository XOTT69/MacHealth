# 📋 Інструкція як залити на GitHub

## Крок 1: Створити репозиторій на GitHub
1. Зайди на https://github.com/new
2. Назва: `MacHealth`
3. Опис: `Безкоштовна діагностика MacBook та iPhone`
4. Вибери **Public**
5. **НЕ** ставь галочки на README, .gitignore, license
6. Натисни **Create repository**

## Крок 2: Завантажити файли
Коли завантажуєш файли на GitHub, потрібно:

### ⚠️ ВАЖЛИВО: Переіменування перед завантаженням
Перед завантаженням на GitHub потрібно переіменувати:
- Папку `github` → `.github` (додати крапку на початку)
- Файл `gitignore.txt` → `.gitignore` (прибрати .txt та додати крапку)

**Це можна зробити прямо на GitHub** після завантаження через кнопку "Edit" на файлах.

### Або простіший спосіб — через Terminal:
```bash
cd ~/Desktop/MacHealth
mv github .github
mv gitignore.txt .gitignore
git add -A
git commit -m "Restore hidden files"
git remote add origin https://github.com/ТВІЙ_ЮЗЕРНЕЙМ/MacHealth.git
git branch -M main
git push -u origin main
```

## Крок 3: Створити Release
1. На GitHub перейди в репозиторій
2. Справа натисни **Releases** → **Create a new release**
3. Tag: `v1.0.0`
4. Title: `MacHealth v1.0.0`
5. Натисни **Publish release**
6. GitHub Actions автоматично збере ZIP і додасть до Release!

## Крок 4: Перевірка
- Перейди у вкладку **Actions** — побачиш процес збірки
- Після завершення у **Releases** з'явиться `MacHealth.zip`
- Цей ZIP можна скачати і відразу використовувати!

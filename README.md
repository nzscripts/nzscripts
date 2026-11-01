# 🎮 Minecraft Forge 1.12.2 — Nazzy Story Modes Server Installer

Автоматический установщик и менеджер выделенного сервера **Minecraft Forge 1.12.2** для прохождения сюжетных карт и режимов от **Nazzy** (Infected, Blizzard, Phasmophobia, Slasher, Laboratory, Crossbattle, Scavenger) для совместной игры через **Radmin VPN**.

---

## ⚡ Быстрая установка в 1 команду

Откройте **PowerShell** в любой папке, где хотите создать сервер, и вставьте команду:

```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/nzscripts/nzscripts/refs/heads/main/script.ps1 | iex"
```

> [!TIP]
> Команда автоматически проверит наличие **Java 8 (64-bit)** (по алгоритмам Prism Launcher), развернёт ядро Forge 1.12.2, предложит меню выбора режима (1–7), отфильтрует несовместимые клиентские моды, установит сюжетную карту, синхронизирует `server.properties` и сгенерирует готовый `start.bat`.

---

## 📦 Поддерживаемые сюжетные режимы

| № | Режим | Автор карты / модов | Особенности | Контент-пак |
| :-: | :--- | :--- | :--- | :-: |
| **1** | **INFECTED v1.1** | Nazzy & Team | Сюжетное выживание с заражением и мутациями | — |
| **2** | **OPERATION BLIZZARD** | Nazzy & Team | Арктическая военная база, холод и мутанты | `ModularWarfare` |
| **3** | **PHASMOPHOBIA HALLOWEEN** | Nazzy & Team | Хоррор-расследование с призраками и уликами | — |
| **4** | **SLASHER (Redwood)** | Nazzy & Team | Курортный лагерь Редвуд, маньяк и выжившие | — |
| **5** | **LABORATORY NZ** | Nazzy & Team | Секретный подземный исследовательский комплекс | `ModularWarfare` |
| **6** | **CROSSBATTLE** | Nazzy & Team | Оружейные перестрелки и командные бои | `ModularWarfare` |
| **7** | **SCAVENGER** | Nazzy & Team | Сбор лута, монстры и поиск выхода из зоны | `ModularWarfare` |
| **0** | **Чистый сервер** | — | Чистый Forge 1.12.2 без предустановленных модов | — |

---

## 🛠️ Что делает установщик под капотом

1. **Детект Java 8 (64-bit):**
   - Использует алгоритмы сканирования реестра Windows и путей лаунчеров (Prism Launcher `JavaChecker`/`JavaUtils`).
   - Находит как системную Java, так и версии, идущие в комплекте с Prism / Modrinth / CurseForge / Oracle.
2. **Развёртывание Forge 1.12.2 (билд 2860):**
   - Автоматически кэширует чистое ядро и библиотеки в `%USERPROFILE%\.mc_forge_base_1.12.2`.
   - Решает проблему битых ссылок Forge Maven (автоподгрузка `asm-debug-all-5.2.jar` и `launchwrapper-1.12.jar`).
3. **Фильтрация клиентских модов:**
   - Автоматически исключает `OptiFine`, `BetterFoliage` и `tlskincape`, которые приводят к сбою `NoClassDefFoundError: GuiScreen` на выделенном сервере.
4. **Контент-паки оружия (`ModularWarfare`):**
   - Автоматически выносит папку с оружием и прототипами в корень сервера.
5. **Авто-конфигурация мира и `server.properties`:**
   - Рекурсивно находит `level.dat`, переносит мир и прописывает актуальное имя в `level-name`.
   - Выставляет `online-mode=false` (для игры с пираток/TLauncher/Prism), `enable-command-block=true`, `allow-flight=true`, `spawn-protection=0`, `gamemode=2`.
6. **Автоподтверждение FML:**
   - В `start.bat` прописан флаг `-Dfml.queryResult=confirm`, чтобы сервер не зависал на ожидании ручной команды `/fml confirm`.
7. **Ресурспаки:**
   - Извлекает клиентские ресурспаки в папку `resourcepacks/`, чтобы хост мог скинуть их друзьям.

---

## 🌐 Как играть с друзьями через Radmin VPN

### 1. Хост (тот, у кого запущен сервер):
1. Скачайте и установите [Radmin VPN](https://www.radmin-vpn.com/).
2. Создайте сеть (например, `Nazzy-Story-Server` с паролем).
3. Запустите установку через скрипт и выберите желаемый режим.
4. Запустите сервер двойным кликом по [`start.bat`](start.bat).
5. Скопируйте свой IP в Radmin VPN (например, `26.154.88.12`).

### 2. Друзья (клиенты):
1. Подключаются к вашей сети в Radmin VPN.
2. Устанавливают клиент Forge 1.12.2 с модами режима (и ресурспаком из папки `resourcepacks`).
3. В игре выбирают **Сетевая игра** ➔ **По адресу** ➔ вводят ваш IP из Radmin VPN: `26.154.88.12:25565`.
4. Голосовой чат **ModularVoiceChat** (порт `7656 UDP`) подключается автоматически через Radmin VPN без проброса портов!

---

## 🚀 Параметры запуска для автоматизации

Скрипт поддерживает запуск с параметрами напрямую:

```powershell
# Установка режима Blizzard с 6 ГБ ОЗУ
powershell -ExecutionPolicy Bypass -File setup.ps1 -Mode Blizzard -MaxRamGB 6 -MinRamGB 2

# Неинтерактивная установка через сеть
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/nzscripts/nzscripts/refs/heads/main/script.ps1))) -Mode Slasher -MaxRamGB 4
```

---

## 📄 Лицензия
MIT License. Создано для сообщества фанатов сюжетных карт Minecraft и режимов Nazzy.

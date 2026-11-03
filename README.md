# Minecraft Forge 1.12.2 Server Installer (Nazzy Modes)

Автоматический установщик выделенного сервера Minecraft Forge 1.12.2 с сюжетными режимами Nazzy для игры через Radmin VPN или локальную сеть.

## Быстрый запуск

Нажмите `Win + R` и выполните:

```powershell
powershell -NoExit -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/nzscripts/nzscripts/refs/heads/main/script.ps1 | iex"
```

При запуске через `Win + R` сервер по умолчанию разворачивается в папку `Desktop\NazzyServer`.

## Список режимов

| № | Режим | Описание | Слоты | Особенности |
| :-: | :--- | :--- | :-: | :--- |
| 1 | **INFECTED v1.1** | Выживание с мутациями | 10 | Голосовой чат (7 активных игроков + спектаторы) |
| 2 | **OPERATION BLIZZARD** | Арктика и военная база | 8 | Мод на оружие (ModularWarfare) |
| 3 | **PHASMOPHOBIA HALLOWEEN** | Хоррор-расследование | 5 | Голосовой чат |
| 4 | **SLASHER (Redwood)** | Маньяк в лагере | 5 | Голосовой чат |
| 5 | **LABORATORY NZ** | Секретная лаборатория D7 | 8 | Мод на оружие (ModularWarfare) |
| 6 | **CROSSBATTLE** | PvP арена и перестрелки | 10 | Мод на оружие, покупка снаряжения |
| 7 | **SCAVENGER** | Охота на монстра | 8 | Мод на оружие (ModularWarfare) |
| 0 | **Чистый сервер** | Базовый Forge 1.12.2 | 10 | Без модов |

## Как играть по сети (Radmin VPN)

### Для хоста (сервер):
1. Установите [Radmin VPN](https://www.radmin-vpn.com/) и создайте сеть.
2. Запустите установщик через команду выше и выберите режим.
3. Запустите сервер через `start.bat`.
4. Передайте друзьям свой IP из Radmin VPN.

### Для игроков (клиент):
1. Подключитесь к сети хоста в Radmin VPN.
2. Запустите клиент Forge 1.12.2 с модами выбранного режима (ресурспак при наличии лежит в папке `resourcepacks`).
3. Подключитесь по адресу: `IP_ХОСТА:25565`.
4. Голосовой чат (порт 7656 UDP) работает через Radmin VPN автоматически.

## Параметры запуска

```powershell
# Автоматическая установка Blizzard с 6 ГБ ОЗУ
powershell -ExecutionPolicy Bypass -File setup.ps1 -Mode Blizzard -MaxRamGB 6 -MinRamGB 2 -Force

# Установка через интернет без диалогов
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/nzscripts/nzscripts/refs/heads/main/script.ps1))) -Mode Laboratory -MaxRamGB 4 -Force
```

## Требования

- Windows 10 / 11
- Java 8 64-bit (скрипт проверяет наличие автоматически)
- Минимум 4 ГБ свободной оперативной памяти

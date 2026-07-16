# Steam Coming Soon — чеклист

## До регистрации

1. [ ] partner.steamgames.com → Steamworks → $100
2. [ ] Создать App → записать AppID в `project.godot` → `steam/initialization/app_id`
3. [ ] W-8BEN / налоги, банк
4. [ ] Проверить название в поиске Steam: «ВЫНЕСИ МУСОР» / «Take Out The Trash»

## Ассеты (уже в `marketing/`)

| Файл | Размер | Статус |
|------|--------|--------|
| capsule_616x353.png | 616×353 | заглушка → заменить геймплеем |
| capsule_460x215.png | 460×215 | заглушка |
| capsule_231x87.png | 231×87 | заглушка |
| library_600x900.png | 600×900 | заглушка |
| header_920x430.png | 920×430 | заглушка |
| vertical_748x896.png | 748×896 | заглушка |
| shots/01–10 | 1920×1080 | заглушки → снять из игры |
| clip/takeoutthetrash_hook.mp4 | 45–60с | снять |

Перегенерация заглушек: `python3 tools/build_store_assets.py`

## Страница

- Название: **ВЫНЕСИ МУСОР! — Take Out The Trash!**
- Цена: **$2.99** (скидка 10% на старте опционально)
- Теги: Simulation, Physics, Comedy, Casual, Short, Funny, Singleplayer
- Короткое: «Mom yelled. The bag tears. Neighbors stare.»
- Буллеты: 12 уровней позора · физика пакета · собаки, бабушки, холодильник
- ИИ-декларация: процедурные/сгенерированные текстуры и SFX — отметить в Steamworks
- Coming Soon минимум **14 дней** до релиза

## Тексты

См. `marketing/STEAM-PAGE-RU.md` и `marketing/STEAM-PAGE-EN.md`.

## IARC / AI

См. `launch/IARC-AND-AI.md`.

## Cloud save (#90)

В Steamworks Autocloud: синхронизировать `meta.json` из user-папки Godot
(`user://meta.json` → обычно `~/.local/share/godot/app_userdata/...` / `%APPDATA%/Godot/...`).
Флаг готовности: создать `user://steam_cloud_ok.txt` после проверки.

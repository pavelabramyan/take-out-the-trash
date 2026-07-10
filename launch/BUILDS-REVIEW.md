# Билды, ревью Valve, IARC

## Локально

```bash
./tools/quality_gate.sh quick
# с шаблонами экспорта Godot:
./tools/quality_gate.sh full
```

Экспорт: пресеты `Windows` / `macOS` в `export_presets.cfg` → `build/win/`, `build/mac/`.

## SteamPipe

1. Скачать Steamworks SDK
2. Настроить `app_build.vdf` (depot Windows)
3. `steamcmd` + `run_app_build`
4. Ветка `beta` с паролем → скачать через Steam → 30 мин смоук
5. Повторить 3 раза

## Ревью

1. Системные требования (low: любой ПК с OpenGL 3.3 / Vulkan)
2. ИИ-контент: да (процедурные ассеты)
3. IARC опрос (~15 мин) → сохранить PDF в `launch/`
4. Отправить на review Valve (3–5 рабочих дней)

## AppID

Пока `0`. После выдачи — прописать и добавить `steam_appid.txt` только для локальной отладки (в .gitignore).

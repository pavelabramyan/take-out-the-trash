# BAG-BIBLE — геройский пакет

## Скоуп Wave 1

Только `Cargo.BAG` / `Cargo.THIN`. Остальные грузы — старые примитивы.

## Пресеты цвета

При `setup()` выбирается один из 3 грязно-зелёных оттенков (`_color_preset`).

## HP → tear_stage

| HP % | Stage |
|------|--------|
| >75 | WHOLE |
| 45–75 | WORN |
| 20–45 | HOLES (+ крошка) |
| 0–20 | CRITICAL |
| 0 | BURST |

Порча: albedo/alpha на шве. **Без emission.**

## Feel

- Pivot у ручек, COM ниже (`center_of_mass.y = -0.14`)
- Spring: `POS_K=16`, `ROT_K=7.5`
- Grab ease 120 ms
- Shape-cast урон в руках; compress визуал

## Звук

`rustle` (loop громкость∝speed), `bag_grab`, `bag_drop`, `wall_rub`, `burst`+`impact` (pitch по начинке).

## Стоп-критерий

За 10 секунд игрок говорит «пакет», не «зелёный куб».

## Тест

`Godot --headless --path . --script res://tools/test_bag_feel.gd`

# 🧸 KidLoop — платформа для обмена детскими вещами

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Yandex Cloud](https://img.shields.io/badge/Yandex%20Cloud-Serverless-5282FF?logo=yandexcloud)](https://cloud.yandex.ru)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **KidLoop** — это мобильное приложение для безопасного обмена детскими вещами.  
> Меняйтесь игрушками, одеждой, книгами и другими товарами с другими родителями.  
> Зарабатывайте очки **SV** и повышайте свой уровень!

<p align="center">
  <img src="screenshots/banner.png" alt="KidLoop Banner" width="800"/>
</p>

---

## 📱 Возможности

| Функция | Описание |
|---------|----------|
| 🔄 **Обмен вещами** | Предлагайте свои вещи в обмен на чужие. Система считает разницу в SV |
| 📦 **Наборы (Bundle)** | Объединяйте несколько вещей в один лот и обменивайтесь наборами |
| 💰 **SV-валюта** | Внутренняя валюта для оценки стоимости вещей |
| ⭐ **Уровни и рейтинг** | Повышайте уровень за активность: шаги, обмены, вещи |
| 🗺️ **Карта** | Смотрите объявления на карте |
| 💬 **Чаты** | Общайтесь с другими пользователями прямо в приложении |
| ♟️ **Шахматы** | Играйте в шахматы с другими пользователями |
| 🧠 **Мини-игры** | Игра «Запомни число» и другие |
| 👟 **Шагомер** | Считайте шаги и получайте бонусы |
| 🔔 **Push-уведомления** | Мгновенные уведомления о предложениях, сообщениях, новых вещах |
| 🌙 **Тёмная тема** | Поддержка светлой и тёмной темы |
| 📊 **Статистика** | Детальная аналитика сделок, отмен, рейтинг надёжности |

---



---

## 🗄️ База данных (YDB)

| Таблица | Назначение |
|---------|-----------|
| `items` | Одиночные объявления |
| `offers` | Предложения обмена (1-на-1 и bundle) |
| `bundles` | Наборы вещей |
| `bundle_items` | Связи набор ↔ предметы |
| `users` | Пользователи и баланс SV |
| `subscriptions` | Подписки на категории |
| `chats` | Чаты между пользователями |
| `chat_messages` | Сообщения в чатах |
| `friendships` | Друзья |
| `chess_games` | Шахматные партии |
| `chess_moves` | Ходы в партиях |

---

## ☁️ Cloud Functions

| Функция | ID | Назначение |
|---------|-----|-----------|
| `add-item` | `d4ei9an1aushareidmjc` | CRUD объявлений |
| `swap-api` | `d4e77rr4t3hlvjo7n77b` | Создание/управление обменами |
| `kidloop-bundle-api` | `d4eu30euelvc8hh759t4` | CRUD наборов |
| `kidloop-notifications` | `d4e1t4stgil2lvkjq5o0` | Push-уведомления (OneSignal) |
| `kidloop-subscriptions` | `d4e1edlmtc18q31jfdlh` | Подписки на категории |
| `user-api` | `d4e8qq9aaimqibei5ga7` | Пользователи и друзья |
| `chat-api-v2` | `d4e40k9g2avoblb1of29` | Чаты |
| `sv-api` | `d4e4du0dtej5k7md0cc5` | Баланс SV |
| `upload-image` | `d4e3c2me21eou683ic6d` | Загрузка изображений |
| `get-stats` | `d4ejmhrgofllrks14a7s` | Статистика платформы |
| `banner-api` | `d4e9bd6bmvqmife91gf4` | Баннеры |
| `register-user` | `d4eltcbga5mf8h8g5eam` | Регистрация |
| `login-user` | `d4eu9sikbtqatturth3c` | Авторизация |
| `forum-api` | `d4en6mi363fq4o5js5ee` | Форум |
| `chess-api` | `d4edmoonsukf22mq48uo` | Шахматы |
| `map-api` | `d4e2uh2tj0febumk6e7e` | Карта |

---

## 🚀 Быстрый старт

### Требования

- **Flutter** 3.x (Dart 3.x)
- **Android Studio** или **VS Code**
- **Yandex Cloud** аккаунт
- **OneSignal** аккаунт (для push-уведомлений)

### Установка

```bash
# Клонируйте репозиторий
git clone https://github.com/your-username/kidloop.git
cd kidloop

# Установите зависимости
flutter pub get

# Запустите на устройстве
flutter run

🎯 Статусная модель предметов
text
available ──► in_bundle ──► reserved ──► swapped
   │              │              │
   └──────────────┴──────────────┴──► cancelled → available
available — доступен для обмена

in_bundle — находится в наборе

reserved — участвует в активной сделке

swapped — обменян

cancelled — сделка отменена, возврат в available

🔄 Процесс обмена (4-шаговый)
text
1. Пользователь A предлагает обмен ──► Пользователь B принимает
2. A выбирает способ передачи ──► B выбирает способ передачи
3. A подтверждает отправку ──► B подтверждает получение
4. B подтверждает отправку ──► A подтверждает получение
   └── Сделка завершена! SV переведены, вещи помечены swapped
📦 Наборы (Bundle)
Создание: выберите 2-5 своих вещей → объедините в набор

Коллаж: автоматическая сетка 3×3 из фото предметов

Обмен: набор ↔ вещь, набор ↔ набор

Блокировка: предметы в наборе помечаются in_bundle

🧪 Технологии
Технология	Назначение
Flutter	Мобильное приложение
Provider	State management
YDB	База данных (Yandex)
Cloud Functions	Бэкенд (Node.js 22)
OneSignal	Push-уведомления
Yandex Object Storage	Хранение изображений
CachedNetworkImage	Кэширование фото
SharedPreferences	Локальное хранилище
📂 Структура проекта
lib/
├── core/                    # Модели и провайдеры
│   ├── item_model.dart
│   ├── bundle_model.dart
│   ├── trade_offer.dart
│   ├── items_provider.dart
│   ├── bundle_provider.dart
│   ├── trades_provider.dart
│   ├── profile_provider.dart
│   ├── subscriptions_provider.dart
│   ├── sv_calculator.dart
│   └── level_calculator.dart
├── features/
│   ├── home/                # Главный экран (лента)
│   ├── dashboard/           # Дашборд
│   ├── bundles/             # Наборы (создание, детали)
│   ├── feed/                # Обмены
│   ├── item_details/        # Детали вещи
│   ├── add_item/            # Добавление вещи
│   ├── messenger/           # Чаты
│   ├── map/                 # Карта
│   ├── profile/             # Профиль
│   ├── games/               # Игры (шахматы, память)
│   ├── pedometer/           # Шагомер
│   └── subscriptions/       # Подписки на категории
├── navigation/              # Навигация
├── screens/auth/            # Авторизация
├── services/                # Сервисы (уведомления)
└── widgets/                 # Общие виджеты


📸 Скриншоты
Лента	Карта	Профиль
https://screenshots/feed.png	https://screenshots/map.png	https://screenshots/profile.png
Обмены	Чаты	Игры
https://screenshots/trades.png	https://screenshots/chat.png	https://screenshots/games.png

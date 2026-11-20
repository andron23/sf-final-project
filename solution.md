
Задание 1

WITH cohorts AS (
    SELECT 
        id AS user_id,
        DATE_TRUNC('month', date_joined)::date AS cohort_month
    FROM users
),
entries AS (
    SELECT 
        ue.user_id,
        c.cohort_month,
        (ue.entry_at::date - u.date_joined::date) AS days_diff
    FROM userentry ue
    JOIN users u ON ue.user_id = u.id
    JOIN cohorts c ON u.id = c.user_id
)
SELECT 
    cohort_month,
    COUNT(DISTINCT user_id) AS total_users,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 0 THEN user_id END) * 100.0 / COUNT(DISTINCT user_id), 2) AS day0,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 1 THEN user_id END) * 100.0 / COUNT(DISTINCT user_id), 2) AS day1,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 3 THEN user_id END) * 100.0 / COUNT(DISTINCT user_id), 2) AS day3,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 7 THEN user_id END) * 100.0 / COUNT(DISTINCT user_id), 2) AS day7,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 14 THEN user_id END) * 100.0 / COUNT(DISTINCT user_id), 2) AS day14,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 30 THEN user_id END) * 100.0 / COUNT(DISTINCT user_id), 2) AS day30,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 60 THEN user_id END) * 100.0 / COUNT(DISTINCT user_id), 2) AS day60,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 90 THEN user_id END) * 100.0 / COUNT(DISTINCT user_id), 2) AS day90
FROM entries
GROUP BY cohort_month
ORDER BY cohort_month;

Выводы: Анализ rolling retention показывает критически низкое удержание пользователей на платформе. В крупных когортах (например, январь и февраль 2022 года) мы видим, что уже на следующий день (day1) активность падает до 32–44%. К 30-му дню на платформе остается лишь около 10–15% пользователей, а к 90-му дню retention стремится к нулю (1–4%).

Это означает, что пользователи заходят на платформу, решают несколько задач и уходят. Они не воспринимают IT Resume как инструмент для постоянного саморазвития. Рекомендация: долгосрочная годовая подписка будет неэффективна, так как большинство пользователей не задерживаются на платформе на такой срок. Оптимальным решением будет сделать акцент на краткосрочных подписках (на 1 месяц). Также бизнесу стоит задуматься над улучшением удержания (например, внедрением системы напоминаний или геймификации), иначе даже месячная подписка может окупаться не полностью.


Задание 2

WITH user_balances AS (
    SELECT 
        t.user_id,
        SUM(CASE WHEN t.type_id IN (1, 23, 24, 25, 26, 27, 28, 30) THEN t.value ELSE 0 END) AS total_spent,
        SUM(CASE WHEN t.type_id NOT IN (1, 23, 24, 25, 26, 27, 28, 30) THEN t.value ELSE 0 END) AS total_earned,
        SUM(CASE WHEN t.type_id NOT IN (1, 23, 24, 25, 26, 27, 28, 30) THEN t.value ELSE -t.value END) AS balance
    FROM "transaction" t
    GROUP BY t.user_id
)
SELECT 
    ROUND(AVG(total_spent), 2) AS avg_spent,
    ROUND(AVG(total_earned), 2) AS avg_earned,
    ROUND(AVG(balance), 2) AS avg_balance,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balance)::numeric, 2) AS median_balance
FROM user_balances;

Выводы: 
Анализ транзакций выявил интересную диспропорцию: пользователи в среднем получают 306.52 коина, но тратят лишь 31.29 коина. При этом средний баланс составляет 275.22, а медианный — всего 62.00.

Такая огромная разница между средним и медианным балансом свидетельствует о сильном перекосе: небольшая группа «китов» накопила огромное количество внутренней валюты, которая «мертвым грузом» лежит на их счетах и не тратится. Большинство же пользователей (медиана) имеют на руках всего 62 коина.

Этот факт подтверждает неэффективность текущей модели с CodeCoins: людям просто некуда тратить заработанное, и они теряют интерес к платформе. Для новой модели монетизации это означает, что стоимость подписки должна быть сопоставима с реальными тратами пользователей (около 30 коинов). Если установить цену выше, пользователи предпочтут просто копить монеты, а не покупать подписку.

Задание 3

WITH active_users AS (
    SELECT DISTINCT user_id FROM coderun
    UNION
    SELECT DISTINCT user_id FROM teststart
),
activity_stats AS (
    SELECT 
        -- 1. Сколько в среднем пользователь решает задач
        (SELECT COUNT(*) FROM coderun) * 1.0 / NULLIF((SELECT COUNT(DISTINCT user_id) FROM coderun), 0) AS avg_tasks_solved,
        -- 2. Сколько в среднем пользователь проходит тестов
        (SELECT COUNT(*) FROM teststart) * 1.0 / NULLIF((SELECT COUNT(DISTINCT user_id) FROM teststart), 0) AS avg_tests_passed,
        -- 3. Сколько в среднем попыток для решения 1 задачи
        (SELECT COUNT(*) FROM codesubmit) * 1.0 / NULLIF((SELECT COUNT(*) FROM coderun), 0) AS avg_attempts_per_task,
        -- 4. Сколько в среднем попыток для прохождения 1 теста
        (SELECT COUNT(*) FROM teststart) * 1.0 / NULLIF((SELECT COUNT(DISTINCT test_id) FROM teststart), 0) AS avg_attempts_per_test,
        -- 5. Доля от общего числа пользователей, которые активны
        (SELECT COUNT(*) FROM active_users) * 100.0 / NULLIF((SELECT COUNT(*) FROM users), 0) AS active_users_percent
),
purchases AS (
    SELECT 
        -- 6. Сколько человек открывало задачи за коины
        COUNT(DISTINCT CASE WHEN t.type_id = 1 THEN t.user_id END) AS users_opened_tasks,
        -- 7. Сколько человек открывало тесты за коины
        COUNT(DISTINCT CASE WHEN t.type_id = 23 THEN t.user_id END) AS users_opened_tests,
        -- 8. Сколько человек открывало подсказки за коины
        COUNT(DISTINCT CASE WHEN t.type_id IN (24, 25) THEN t.user_id END) AS users_opened_hints,
        -- 9. Сколько человек открывало решения за коины
        COUNT(DISTINCT CASE WHEN t.type_id = 26 THEN t.user_id END) AS users_opened_solutions,
        -- 10. Сколько всего покупок было совершено
        COUNT(CASE WHEN t.type_id IN (1, 23, 24, 25, 26) THEN 1 END) AS total_purchases,
        -- 11. Сколько человек сделало хотя бы одну покупку
        COUNT(DISTINCT CASE WHEN t.type_id IN (1, 23, 24, 25, 26) THEN t.user_id END) AS users_made_purchase,
        -- 12. Сколько человек имеют хотя бы одну транзакцию (даже начисление)
        COUNT(DISTINCT t.user_id) AS users_with_transactions
    FROM "transaction" t
)
SELECT * FROM activity_stats, purchases;

Выводы: Анализ активности показал, что 62.36% пользователей от общего числа решают задачи или проходят тесты. Это значит, что база активных пользователей достаточно велика. В среднем один активный пользователь решает 64 задачи и проходит 2 теста.

Однако статистика покупок за коины выглядит совсем иначе:

Тесты за коины открывали 522 человека (это самая популярная покупка).

Подсказки — 169 человек.

Задачи — всего 1 человек.

Решения — 0 человек.

При этом всего 605 человек совершили хотя бы одну покупку, а транзакции (включая начисления) есть у 2402 человек.

Главный вывод для бизнеса: Пользователи активно решают задачи, но почти не тратят на это коины. Они предпочитают открывать тесты и подсказки, но не задачи или готовые решения. Это говорит о том, что в платную подписку стоит включить именно неограниченный доступ к тестам и подсказкам, так как это самый востребованный функционал. Задачи и решения можно оставить бесплатными (или с ограничениями), чтобы не отпугнуть пользователей, так как люди их почти не покупают за коины.


Дополнительное задание

Мне кажется, нужно посчитать ... Для этого я предлагаю ..., потому что:
1. Конверсия в плательщиков: Покажет долю пользователей, готовых платить реальные деньги, а не только тратить бонусные коины. Это критически важно для прогноза выручки от подписки.
2. «Спящий» баланс: Выявит объем внутренней валюты, которая лежит без дела. Если сумма огромная — модель с коинами неэффективна, люди просто копят.
3. Средняя стоимость решения задачи: Покажет, сколько коинов в среднем тратится на одну задачу. Это поможет сформировать ценность подписки (например, «подписка = 10 задач»).

Код для расчета:
1. Конверсия в плательщиков
SELECT 
    COUNT(DISTINCT CASE WHEN t.type_id = 2 THEN t.user_id END) * 100.0 / COUNT(DISTINCT t.user_id) AS paying_users_percent
FROM "transaction" t;

2. Спящий баланс (не заходили 30 дней)
WITH last_entry AS (
    SELECT user_id, MAX(entry_at) AS last_visit
    FROM userentry
    GROUP BY user_id
),
balances AS (
    SELECT t.user_id, 
           SUM(CASE WHEN t.type_id NOT IN (1, 23, 24, 25, 26, 27, 28, 30) THEN t.value ELSE -t.value END) AS balance
    FROM "transaction" t
    GROUP BY t.user_id
)
SELECT SUM(b.balance) AS sleeping_coins
FROM balances b
JOIN last_entry le ON b.user_id = le.user_id
WHERE le.last_visit < NOW() - INTERVAL '30 days';

3. Средняя стоимость решения задачи
SELECT 
    ROUND(AVG(t.value), 2) AS avg_cost_per_task
FROM "transaction" t
WHERE t.type_id = 1;

Выводы:
Конверсия в плательщиков составила менее 1% (0.96%). Это критически низкий показатель, который доказывает, что текущая модель с CodeCoins не мотивирует людей тратить реальные деньги.

«Спящий» баланс равен 643 204 коинам. Огромная сумма «замороженной» валюты на счетах неактивных пользователей подтверждает, что люди копят коины, но не могут или не хотят их тратить.

Средняя стоимость задачи — 100 коинов. Это дает нам ориентир для формирования подписки: если подписка будет стоить условно 300 рублей, она должна открывать доступ как минимум к 3–5 задачам, чтобы быть выгоднее разовой покупки.

Эти метрики в совокупности показывают, что переход на подписку — верное решение, так как текущая система «мертвых» коинов не приносит прибыли.

Итоговые выводы по смене модели монетизации

Анализ данных показал, что текущая модель с CodeCoins неэффективна: пользователи копят валюту (643 тыс. коинов лежат «мертвым грузом»), но почти не тратят её на задачи (средняя стоимость задачи — 100 коинов, при этом конверсия в реальные деньги менее 1%). 

Исходя из этого, я считаю, что IT Resume нужно сделать ставку на краткосрочную подписку (на 1 месяц), так как retention быстро падает (к 30-му дню остается лишь 10–15% пользователей). Долгосрочные годовые подписки будут невыгодны.

Что включить в подписку: Учитывая, что люди охотнее всего тратят коины на тесты (522 чел.) и подсказки (169 чел.), именно эти функции стоит сделать «якорными» для платного тарифа. Базовый функционал (решение обычных задач) можно оставить бесплатным, но ограничить количество попыток, чтобы стимулировать переход на платную версию. 

Кроме того, чтобы «разморозить» накопленные коины и повысить конверсию, рекомендую добавить короткий пробный период (3–7 дней) и возможность разовой покупки доступа к конкретному кейсу. Это позволит монетизировать тех, кто не готов платить за целый месяц, но хочет получить быстрый результат.

Дополнительное задание 2

Для выгрузки данных используем SQL-запрос:

SELECT 
    created_at::date AS activity_date,
    EXTRACT(DOW FROM created_at) AS day_of_week, -- 0 = воскресенье, 1 = понедельник и т.д.
    EXTRACT(HOUR FROM created_at) AS hour_of_day,
    COUNT(*) AS activity_count
FROM (
    SELECT created_at FROM coderun
    UNION ALL
    SELECT created_at FROM codesubmit
    UNION ALL
    SELECT created_at FROM teststart
) AS all_activity
GROUP BY activity_date, day_of_week, hour_of_day
ORDER BY activity_date, hour_of_day;


Для загрузки данных, построения графика используем такой код:

python
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# Настройка стиля графиков
sns.set_theme(style="whitegrid")

# Загружаем данные (замените название файла на ваше, если оно отличается)
df = pd.read_csv('2021-03-276.017.01.txt', sep='\t', names=['date', 'day_of_week', 'hour_of_day', 'activity_count'])

# Переводим дни недели в понятные названия
days_map = {0: 'Вс', 1: 'Пн', 2: 'Вт', 3: 'Ср', 4: 'Чт', 5: 'Пт', 6: 'Сб'}
df['day_name'] = df['day_of_week'].map(days_map)

# График 1: Активность по дням недели
plt.figure(figsize=(10, 5))
day_activity = df.groupby('day_name')['activity_count'].sum().reindex(['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'])
ax1 = day_activity.plot(kind='bar', color='skyblue', edgecolor='black')
plt.title('Суммарная активность пользователей по дням недели', fontsize=14)
plt.xlabel('День недели', fontsize=12)
plt.ylabel('Количество действий', fontsize=12)
plt.xticks(rotation=0)
for p in ax1.patches:
    ax1.annotate(str(int(p.get_height())), (p.get_x() + p.get_width() / 2., p.get_height()), ha='center', va='bottom')
plt.tight_layout()
plt.savefig('activity_by_day.png')
plt.show()

# График 2: Активность по часам суток
plt.figure(figsize=(12, 5))
hour_activity = df.groupby('hour_of_day')['activity_count'].sum()
plt.plot(hour_activity.index, hour_activity.values, marker='o', color='orange', linewidth=2)
plt.title('Суммарная активность пользователей по часам суток', fontsize=14)
plt.xlabel('Час дня (0-23)', fontsize=12)
plt.ylabel('Количество действий', fontsize=12)
plt.xticks(range(0, 24))
plt.grid(True, alpha=0.5)
plt.tight_layout()
plt.savefig('activity_by_hour.png')
plt.show()

print("Графики успешно построены и сохранены в папку с проектом!")

Выводы: 
На основе анализа данных об активности пользователей можно сделать следующие рекомендации по времени релизов:

1. По дням недели: Пик активности приходится на середину недели (вторник, среда, четверг). В выходные (суббота и воскресенье) активность значительно снижается (с ~13 000 до ~9 000 действий). 
Рекомендация: проводить релизы лучше всего в воскресенье вечером или в понедельник ранним утром. В это время пользователей меньше всего, и если возникнут ошибки, они затронут минимальное количество людей.
2. По времени суток: Основная масса действий приходится на рабочие часы. 
Рекомендация: идеальное время для выкатки нового функционала — ночью (с 02:00 до 04:00), когда нагрузка на серверы минимальна.

(Графики activity_by_day.png и activity_by_hour.png приложены к решению)

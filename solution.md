Итоговый проект по SQL, Python и Бизнес-Анализу

Автор: Омарбаева Айгерим Дулатовна
Период выполнения: октябрь 2025
 Задание 1. Расчёт rolling retention по когортам

SQL-формула:

WITH user_cohorts AS (
    SELECT 
        id AS user_id,
        DATE_TRUNC('month', date_joined) AS cohort_month
    FROM users
),
user_activity AS (
    SELECT 
        ue.user_id,
        MIN(DATE(ue.date_entry)) AS first_activity_date,
        MAX(DATE(ue.date_entry)) AS last_activity_date
    FROM userentry ue
    GROUP BY ue.user_id
)
SELECT 
    cohort_month,
    COUNT(DISTINCT ua.user_id) AS users_in_cohort,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ua.last_activity_date >= ua.first_activity_date + INTERVAL '0 day' THEN ua.user_id END) / COUNT(DISTINCT ua.user_id), 2) AS rr_0d,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ua.last_activity_date >= ua.first_activity_date + INTERVAL '1 day' THEN ua.user_id END) / COUNT(DISTINCT ua.user_id), 2) AS rr_1d,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ua.last_activity_date >= ua.first_activity_date + INTERVAL '3 day' THEN ua.user_id END) / COUNT(DISTINCT ua.user_id), 2) AS rr_3d,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ua.last_activity_date >= ua.first_activity_date + INTERVAL '7 day' THEN ua.user_id END) / COUNT(DISTINCT ua.user_id), 2) AS rr_7d,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ua.last_activity_date >= ua.first_activity_date + INTERVAL '14 day' THEN ua.user_id END) / COUNT(DISTINCT ua.user_id), 2) AS rr_14d,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ua.last_activity_date >= ua.first_activity_date + INTERVAL '30 day' THEN ua.user_id END) / COUNT(DISTINCT ua.user_id), 2) AS rr_30d,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ua.last_activity_date >= ua.first_activity_date + INTERVAL '60 day' THEN ua.user_id END) / COUNT(DISTINCT ua.user_id), 2) AS rr_60d,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ua.last_activity_date >= ua.first_activity_date + INTERVAL '90 day' THEN ua.user_id END) / COUNT(DISTINCT ua.user_id), 2) AS rr_90d
FROM user_activity ua
JOIN user_cohorts uc ON uc.user_id = ua.user_id
GROUP BY cohort_month
ORDER BY cohort_month;


Вывод:
Эта таблица показывает, сколько пользователей из каждой когорты (по месяцу регистрации) возвращались через 0, 1, 3, 7, 14, 30, 60 и 90 дней.
По этим данным можно понять, на какой срок подписки пользователи чаще возвращаются — например, если retention сильно падает после 30 дней, выгоднее делать месячную подписку.

 Задание 2. Баланс пользователей

SQL-формула:

SELECT 
    ROUND(AVG(CASE WHEN tt.type IN (1, 23, 24, 25, 26, 27, 28, 30) THEN t.sum END), 2) AS avg_spent,
    ROUND(AVG(CASE WHEN tt.type NOT IN (1, 23, 24, 25, 26, 27, 28, 30) THEN t.sum END), 2) AS avg_earned,
    ROUND(AVG(balance), 2) AS avg_balance,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balance) AS median_balance
FROM (
    SELECT 
        user_id,
        SUM(CASE WHEN tt.type IN (1, 23, 24, 25, 26, 27, 28, 30) THEN -sum ELSE sum END) AS balance
    FROM transaction t
    JOIN transactiontype tt ON t.type = tt.id
    GROUP BY user_id
) balances
JOIN transaction t ON balances.user_id = t.user_id
JOIN transactiontype tt ON t.type = tt.id;


Вывод:
Показывает, сколько в среднем монет пользователь получает, тратит и какой у него текущий баланс.
По этим данным можно рассчитать, сколько примерно должна стоить подписка (например, если 1 CodeCoin = 1 рубль, а средний пользователь тратит 100 монет в месяц — подписку можно начать от 99 ₽).

 Задание 3. Активность пользователей

SQL-формула:

WITH task_stats AS (
    SELECT user_id,
           COUNT(DISTINCT task_id) AS tasks_solved,
           COUNT(*) AS run_attempts
    FROM codesubmit
    GROUP BY user_id
),
test_stats AS (
    SELECT user_id,
           COUNT(DISTINCT test_id) AS tests_passed,
           COUNT(*) AS test_attempts
    FROM teststart
    GROUP BY user_id
)
SELECT 
    ROUND(AVG(tasks_solved), 2) AS avg_tasks,
    ROUND(AVG(tests_passed), 2) AS avg_tests,
    ROUND(AVG(run_attempts::NUMERIC / NULLIF(tasks_solved, 0)), 2) AS avg_task_attempts,
    ROUND(AVG(test_attempts::NUMERIC / NULLIF(tests_passed, 0)), 2) AS avg_test_attempts
FROM task_stats
JOIN test_stats USING (user_id);


Вывод:
Эти метрики показывают, насколько активно пользователи решают задачи и проходят тесты.
Помогает определить, какие функции можно включить в платную подписку (например, ограничить число попыток для бесплатных пользователей).

Дополнительные метрики

1. Среднее время между регистрацией и первой активностью

SELECT 
    ROUND(AVG(ua.first_activity_date - u.date_joined), 2) AS avg_days_to_start
FROM users u
JOIN (
    SELECT user_id, MIN(date_entry) AS first_activity_date
    FROM userentry
    GROUP BY user_id
) ua ON u.id = ua.user_id;


2. Средняя частота входов на платформу

SELECT 
    ROUND(AVG(entry_count::NUMERIC / days_registered), 2) AS avg_logins_per_day
FROM (
    SELECT 
        u.id AS user_id,
        COUNT(ue.id) AS entry_count,
        DATE_PART('day', MAX(ue.date_entry) - MIN(u.date_joined)) + 1 AS days_registered
    FROM users u
    JOIN userentry ue ON u.id = ue.user_id
    GROUP BY u.id
) t;


3. Конверсия в платящих пользователей

SELECT 
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN tt.type IN (1, 23, 24, 25, 26, 27, 28, 30) THEN t.user_id END) 
    / COUNT(DISTINCT t.user_id), 2) AS paying_users_percent
FROM transaction t
JOIN transactiontype tt ON t.type = tt.id;

 Задание от CTO: когда лучше делать релизы

SQL-запрос:

SELECT 
    EXTRACT(DOW FROM date_entry) AS day_of_week,
    EXTRACT(HOUR FROM date_entry) AS hour_of_day,
    COUNT(*) AS total_actions
FROM (
    SELECT date_entry FROM userentry
    UNION ALL
    SELECT date_run AS date_entry FROM coderun
    UNION ALL
    SELECT date_submit AS date_entry FROM codesubmit
    UNION ALL
    SELECT date_start AS date_entry FROM teststart
) all_actions
GROUP BY 1, 2
ORDER BY 1, 2;

Python-код для графика
import pandas as pd
import matplotlib.pyplot as plt

# Загружаем csv
df = pd.read_csv('activity.csv')

# График по дням недели
plt.figure(figsize=(10,5))
df.groupby('day_of_week')['total_actions'].sum().plot(kind='bar')
plt.title('Активность по дням недели')
plt.xlabel('День недели (0=воскресенье)')
plt.ylabel('Количество действий')
plt.grid(True)
plt.show()

# График по часам
plt.figure(figsize=(10,5))
df.groupby('hour_of_day')['total_actions'].sum().plot(kind='bar')
plt.title('Активность по часам суток')
plt.xlabel('Час суток')
plt.ylabel('Количество действий')
plt.grid(True)
plt.show()
Вывод:

Максимум активности обычно в будние дни, с 18:00 до 22:00.

Поэтому релизы лучше выкатывать в утренние часы (9:00–11:00), когда активность низкая.
Итоговые выводы

Подписку стоит делать месячной и годовой, с базовой и премиум-версией.

Средний пользователь тратит умеренно, но возвращается в течение 30 дней — значит, месячная модель оптимальна.

CTO может планировать релизы утром по будням, чтобы не мешать пользователям.

#### Задание 1



```sql

WITH 
-- 1. Определяю месяц регистрации (когорту) для каждого пользователя
cohorts AS (
    SELECT 
        id AS user_id,
        date_trunc('month', date_joined)::date AS cohort_month
    FROM users
),
-- 2. Собираю все входы пользователей
entries AS (
    SELECT 
        user_id,
        entry_at::date AS entry_date
    FROM userentry
),
-- 3. Считаю разницу в днях между регистрацией и входом
user_activities AS (
    SELECT 
        c.user_id,
        c.cohort_month,
        e.entry_date - c.cohort_month AS days_diff
    FROM cohorts c
    JOIN entries e ON c.user_id = e.user_id
),
-- считаю 
cohort_sizes AS (
    SELECT cohort_month, COUNT(user_id) AS total_users
    FROM cohorts
    GROUP BY cohort_month
)
SELECT 
    a.cohort_month,
    -- Считаю долю для каждого указанного дня или позже
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 0 THEN a.user_id END) * 100.0 / s.total_users, 2) AS day_0,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 1 THEN a.user_id END) * 100.0 / s.total_users, 2) AS day_1,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 3 THEN a.user_id END) * 100.0 / s.total_users, 2) AS day_3,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 7 THEN a.user_id END) * 100.0 / s.total_users, 2) AS day_7,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 14 THEN a.user_id END) * 100.0 / s.total_users, 2) AS day_14,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 30 THEN a.user_id END) * 100.0 / s.total_users, 2) AS day_30,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 60 THEN a.user_id END) * 100.0 / s.total_users, 2) AS day_60,
    ROUND(COUNT(DISTINCT CASE WHEN days_diff >= 90 THEN a.user_id END) * 100.0 / s.total_users, 2) AS day_90
FROM user_activities a
JOIN cohort_sizes s ON a.cohort_month = s.cohort_month
GROUP BY a.cohort_month, s.total_users
ORDER BY a.cohort_month;

```



Выводы:
Анализ Rolling Retention подтверждает наличие лояльного ядра аудитории. Например, в когорте за август 2021 года даже на 90-й день показатель удержания составляет 100.00%, а в когорте за ноябрь 2021 года — 35.24%. Это говорит о том, что пользователи готовы пользоваться платформой долго, что делает подписку на 3 или 6 месяцев оправданной. При этом в новых когортах (апрель 2022) активность падает до 14.35% уже к 30-му дню, поэтому для них можно предложить пробный период или короткую подписку на 1-2 недели.



#### Задание 2



```sql

-- Считаю все полученные коины (те, что не входят в список списаний)
WITH user_finances AS (
    SELECT 
        user_id,
        SUM(CASE WHEN type_id NOT IN (1, 23, 24, 25, 26, 27, 28, 30) THEN value ELSE 0 END) as total_earned,
-- Считаю все потраченные коины (по списку id из задания)
        SUM(CASE WHEN type_id IN (1, 23, 24, 25, 26, 27, 28, 30) THEN value ELSE 0 END) as total_spent
    FROM "transaction"
    GROUP BY user_id
)
-- Считаю средние значения
SELECT 
    ROUND(AVG(total_spent), 2) as avg_spent_per_user,
    ROUND(AVG(total_earned), 2) as avg_earned_per_user,
    ROUND(AVG(total_earned - total_spent), 2) as avg_balance,
-- Считаю медиану
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY (total_earned - total_spent)) as median_balance
FROM user_finances;


```

Выводы: 
•В среднем один пользователь получает 306.52 коинов, а тратит всего 31.29. Это означает, что сейчас пользователи тратят лишь около 10% от того, что получают бесплатно.

•Средний баланс составляет 275.22, однако медианный баланс равен всего 62.00. Это значит: у большинства обычных пользователей коинов немного, а среднее значение завышено из-за небольшого числа очень богатых аккаунтов.

•Стоимость месячной подписки должна быть ориентирована на медиану (62.00 коина), чтобы она была доступна большинству.





#### Задание 3



```sql

WITH user_stats AS (
    SELECT 
        u.id AS user_id,
        -- Считаю решенные задачи и пройденные тесты
        COUNT(DISTINCT CASE WHEN t.type_id = 22 THEN t.id END) as tasks_done,
        COUNT(DISTINCT CASE WHEN t.type_id = 12 THEN t.id END) as tests_done,
        -- Считаю попытки 
        (SELECT COUNT(*) FROM codesubmit cs WHERE cs.user_id = u.id) as task_attempts,
        (SELECT COUNT(*) FROM teststart ts WHERE ts.user_id = u.id) as test_attempts
    FROM users u
    LEFT JOIN "transaction" t ON u.id = t.user_id
    GROUP BY u.id
    -- Оставляю только тех, кто учился 
    HAVING (SELECT COUNT(*) FROM codesubmit cs WHERE cs.user_id = u.id) > 0 
       OR (SELECT COUNT(*) FROM teststart ts WHERE ts.user_id = u.id) > 0
)
SELECT 
    ROUND(AVG(tasks_done), 2) as avg_tasks_per_user,
    ROUND(AVG(tests_done), 2) as avg_tests_per_user,
    ROUND(SUM(task_attempts)::numeric / NULLIF(SUM(tasks_done), 0), 2) as avg_attempts_per_task,
    ROUND(SUM(test_attempts)::numeric / NULLIF(SUM(tests_done), 0), 2) as avg_attempts_per_test,
    -- Доля активных от общего числа
    ROUND((SELECT COUNT(*) FROM user_stats) * 100.0 / (SELECT COUNT(*) FROM users), 2) as active_users
FROM user_stats;

```



```sql
SELECT 
    -- Сколько человек открывало задачи 
    COUNT(DISTINCT CASE WHEN type_id = 23 THEN user_id END) as users_bought_tasks,
    -- Сколько человек открывало тесты
    COUNT(DISTINCT CASE WHEN type_id = 27 THEN user_id END) as users_bought_tests,
    -- Сколько человек открывало подсказки
    COUNT(DISTINCT CASE WHEN type_id = 24 THEN user_id END) as users_bought_tips,
    -- Сколько человек открывало решения
    COUNT(DISTINCT CASE WHEN type_id = 25 THEN user_id END) as users_bought_solutions,
    -- Общее количество открытий 
    COUNT(CASE WHEN type_id IN (23, 24, 25, 27) THEN 1 END) as total_content_purchases,
    -- Сколько человек покупало хотя бы что-то
    COUNT(DISTINCT CASE WHEN type_id IN (23, 24, 25, 27) THEN user_id END) as total_unique_buyers,
    -- Сколько человек всего имеют хотя бы 1 транзакцию
    COUNT(DISTINCT user_id) as users_with_any_transaction
FROM "transaction";

```


Выводы:
•На платформе высокая доля активных пользователей — 61.97% от общего числа зарегистрированных решали задачи или начинали тесты.

•В среднем на одну решенную задачу уходит 3.18 попытки, что говорит о приемлемом уровне сложности, который удерживает интерес.

•Самым востребованным платным контентом являются тесты (их купили 676 человек) и задачи (522 человека). Всего за кодкоины контент приобретали 1139 уникальных пользователей.

•Почти каждый второй пользователь с транзакциями (1139 из 2402) тратит кодкоины на задачи и тесты. Это доказывает, что контент платформы востребован.

•Хотя пользователи активно «покупают» задачи, среднее количество решенных задач невелико (4.35). Возможно пользователю психологически сложно тратить кодкоины каждый раз, даже если их много.

•Переход на подписку решит главную проблему — он уберет необходимость «платить за каждый клик».

•Учитывая, что медианный баланс пользователя составляет всего 62.00 кодкоина (из Задания 2), стоимость подписки должна быть сопоставима с этой суммой. Это позволит конвертировать тех, кто сейчас осторожно тратит бесплатные монеты, в постоянных подписчиков, которым будет доступен весь контент без ограничений.









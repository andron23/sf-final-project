--Задание 1
WITH cohort_users AS (
    SELECT 
        u.id AS user_id,
        DATE(u.date_joined) AS reg_date,
        TO_CHAR(u.date_joined, 'YYYY-MM') AS cohort_month
    FROM users u
),
user_activity AS (
    SELECT DISTINCT
        ue.user_id,
        DATE(ue.entry_at) AS activity_date   -- поле date, если оно так называется
    FROM userentry ue
),
daily_retention AS (
    SELECT 
        cu.cohort_month,
        cu.user_id,
        (ua.activity_date - cu.reg_date) AS day_diff
    FROM cohort_users cu
    LEFT JOIN user_activity ua ON cu.user_id = ua.user_id
),
cohort_size AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT user_id) AS total_users
    FROM cohort_users
    GROUP BY cohort_month
)
SELECT 
    rc.cohort_month,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 0 THEN rc.user_id END) / cs.total_users, 2) AS day0,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 1 THEN rc.user_id END) / cs.total_users, 2) AS day1,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 3 THEN rc.user_id END) / cs.total_users, 2) AS day3,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 7 THEN rc.user_id END) / cs.total_users, 2) AS day7,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 14 THEN rc.user_id END) / cs.total_users, 2) AS day14,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 30 THEN rc.user_id END) / cs.total_users, 2) AS day30,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 60 THEN rc.user_id END) / cs.total_users, 2) AS day60,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 90 THEN rc.user_id END) / cs.total_users, 2) AS day90
FROM daily_retention rc
JOIN cohort_size cs ON rc.cohort_month = cs.cohort_month
GROUP BY rc.cohort_month, cs.total_users
ORDER BY rc.cohort_month;
--Выводы:
--Удержание пользователей на платформе крайне низкое в долгосрочной перспективе.  
-- К 7-му дню retention составляет в среднем 25–30% (среди реалистичных когорт), к 30-му дню падает до 8–12%, а к 60–90 дню – практически обнуляется (0–5%).  
--Исключения (когорты 2021-08, 2021-07) являются статистическими аномалиями и не должны учитываться при принятии решений.
--Рекомендации по срокам подписки:  
-- Основной тариф – недельный (7 дней), так как основной пик активности приходится на первую неделю.  
-- Дополнительный тариф – месячный (для небольшого ядра постоянных пользователей).  
-- Годовую подписку вводить нецелесообразно – крайне малая доля пользователей остаётся активной дольше месяца.
--Дополнительно:  
-- Целесообразно внедрить бесплатный пробный период (3–7 дней) для повышения конверсии в платных пользователей.  

--Задание 2
WITH user_balances AS (
    SELECT 
        u.id AS user_id,
        COALESCE(SUM(CASE WHEN t.type_id  IN (1,23,24,25,26,27,28,30) THEN t.value ELSE 0 END), 0) AS total_spent,
        COALESCE(SUM(CASE WHEN t.type_id NOT IN (1,23,24,25,26,27,28,30) THEN t.value ELSE 0 END), 0) AS total_earned,
        COALESCE(SUM(CASE WHEN t.type_id NOT IN (1,23,24,25,26,27,28,30) THEN t.value ELSE 0 END), 0) 
        - COALESCE(SUM(CASE WHEN t.type_id IN (1,23,24,25,26,27,28,30) THEN t.value ELSE 0 END), 0) AS balance
    FROM users u
    LEFT JOIN transaction t ON u.id = t.user_id
    GROUP BY u.id
)
SELECT 
    ROUND(AVG(total_spent), 2) AS avg_spent_per_user,
    ROUND(AVG(total_earned), 2) AS avg_earned_per_user,
    ROUND(AVG(balance), 2) AS avg_balance,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balance) AS median_balance
FROM user_balances;
--Выводы:
--Текущая система монетизации через CodeCoins неэффективна: пользователи зарабатывают много монет, но почти не тратят их, что говорит о низкой востребованности платного
--контента или о нежелании расставаться с накоплениями. Переход на подписку позволит:
--Снять барьер «жаль тратить монеты» – пользователи получат доступ к контенту без списаний.
--Привлечь тех, у кого мало монет (медианный баланс всего 56) – они не могут позволить себе покупку отдельных материалов, но готовы платить фиксированную сумму за доступ.
--Увеличить средний чек – вместо разовых микропокупок (27 монет за всё время) получить регулярный ежемесячный платёж.
--Рекомендуемая стратегия:
--Запустить подписку с ценой ~300–500 руб./мес. (эквивалент 150–250 монет при курсе 1 монета = 2 руб.) с пробным периодом 7 дней.
--Включить в подписку решения, подсказки, топовые задачи и эксклюзивные разделы.
--Отслеживать конверсию и удержание, корректируя цену и состав на основе данных.

--Задание 3
WITH
-- 1. Статистика по задачам (только успешные решения)
task_stats AS (
    SELECT
        user_id,
        COUNT(DISTINCT problem_id) AS solved_tasks,
        COUNT(*) AS attempts
    FROM codesubmit
    WHERE is_false = 0   -- только успешные решения
    GROUP BY user_id
),
-- 2. Статистика по тестам (все запуски)
test_stats AS (
    SELECT
        user_id,
        COUNT(DISTINCT test_id) AS started_tests,
        COUNT(*) AS attempts
    FROM teststart
    GROUP BY user_id
),
-- 3. Активные пользователи (есть хотя бы одна запись в task_stats или test_stats)
active_users AS (
    SELECT user_id FROM task_stats
    UNION
    SELECT user_id FROM test_stats
),
-- 4. Общее число пользователей
total_users AS (
    SELECT COUNT(*) AS cnt FROM users
),
-- 5. Покупки контента (списания по типам 23,24,25,27)
purchases AS (
    SELECT
        user_id,
        type_id,
        COUNT(*) AS cnt
    FROM transaction
    WHERE type_id IN (23,24,25,27)   -- все типы покупок контента
    GROUP BY user_id, type_id
),
-- 6. Агрегаты по покупкам для итогового SELECT
purchase_agg AS (
    SELECT
        COUNT(DISTINCT CASE WHEN type_id = 23 THEN user_id END) AS users_bought_tasks,
        COUNT(DISTINCT CASE WHEN type_id = 27 THEN user_id END) AS users_bought_tests,
        COUNT(DISTINCT CASE WHEN type_id = 24 THEN user_id END) AS users_bought_tips,
        COUNT(DISTINCT CASE WHEN type_id = 25 THEN user_id END) AS users_bought_solutions,
        COUNT(CASE WHEN type_id IN (23,24,25,27) THEN 1 END) AS total_content_purchases,
        COUNT(DISTINCT CASE WHEN type_id IN (23,24,25,27) THEN user_id END) AS total_unique_buyers
    FROM purchases
),
-- 7. Пользователи с любой транзакцией (для последнего показателя)
any_trans AS (
    SELECT COUNT(DISTINCT user_id) AS cnt FROM transaction
)
-- ===== ИТОГОВЫЙ SELECT (все показатели одной строкой) =====
SELECT
    -- Средние по активности (только для активных пользователей)
    ROUND(COALESCE((SELECT AVG(solved_tasks) FROM task_stats), 0), 2) AS avg_tasks_per_user,
    ROUND(COALESCE((SELECT AVG(started_tests) FROM test_stats), 0), 2) AS avg_tests_per_user,
    ROUND(COALESCE(
        (SELECT SUM(attempts) * 1.0 / NULLIF(SUM(solved_tasks), 0) FROM task_stats),
        0
    ), 2) AS avg_attempts_per_task,
    ROUND(COALESCE(
        (SELECT SUM(attempts) * 1.0 / NULLIF(SUM(started_tests), 0) FROM test_stats),
        0
    ), 2) AS avg_attempts_per_test,
    -- Доля активных
    ROUND(COALESCE(
        (SELECT COUNT(*) FROM active_users) * 100.0 / (SELECT cnt FROM total_users),
        0
    ), 2) AS active_users_pct,
    -- Показатели покупок (из purchase_agg)
    (SELECT users_bought_tasks FROM purchase_agg) AS users_bought_tasks,
    (SELECT users_bought_tests FROM purchase_agg) AS users_bought_tests,
    (SELECT users_bought_tips FROM purchase_agg) AS users_bought_tips,
    (SELECT users_bought_solutions FROM purchase_agg) AS users_bought_solutions,
    (SELECT total_content_purchases FROM purchase_agg) AS total_content_purchases,
    (SELECT total_unique_buyers FROM purchase_agg) AS total_unique_buyers,
    -- Пользователи с любой транзакцией
    (SELECT cnt FROM any_trans) AS users_with_any_transaction;
--Выводы:
--Текущая модель микротранзакций за монеты неэффективна: пользователи покупают контент редко (в среднем 1 раз), хотя вовлечённость высокая (59% активных)
--Наиболее востребованы тесты и задачи, а подсказки и решения – второстепенны. Переход на подписку позволит:
--Превратить разовые покупки в регулярный доход.
--Монетизировать тех, кто копит монеты, но не тратит (более 1200 таких пользователей).
--Увеличить LTV (пожизненную ценность) за счёт постоянного доступа, а не разовых транзакций.
--Рекомендуемый состав подписки: неограниченный доступ к задачам и тестам + решения как бонус. Подсказки оставить бесплатными. Добавить эксклюзивный контент для повышения ценности.
--Цену установить на уровне, чуть превышающем среднюю стоимость разовых покупок за месяц (можно рассчитать на основе данных о частоте покупок и средней цене одного материала).

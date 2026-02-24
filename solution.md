Задание 1
SELECT
    to_char(DATE_TRUNC('month', u.date_joined), 'YYYY-MM') AS cohort_month,
    ROUND(
        COUNT(DISTINCT CASE WHEN ue.entry_at >= u.date_joined THEN u.id END)::numeric * 100.0 / COUNT(*), 2
    ) AS d0,
    ROUND(
        COUNT(DISTINCT CASE WHEN ue.entry_at >= u.date_joined + INTERVAL '1 day' THEN u.id END)::numeric * 100.0 / COUNT(*), 2
    ) AS d1,
    ROUND(
        COUNT(DISTINCT CASE WHEN ue.entry_at >= u.date_joined + INTERVAL '3 day' THEN u.id END)::numeric * 100.0 / COUNT(*), 2
    ) AS d3,
    ROUND(
        COUNT(DISTINCT CASE WHEN ue.entry_at >= u.date_joined + INTERVAL '7 day' THEN u.id END)::numeric * 100.0 / COUNT(*), 2
    ) AS d7,
    ROUND(
        COUNT(DISTINCT CASE WHEN ue.entry_at >= u.date_joined + INTERVAL '14 day' THEN u.id END)::numeric * 100.0 / COUNT(*), 2
    ) AS d14,
    ROUND(
        COUNT(DISTINCT CASE WHEN ue.entry_at >= u.date_joined + INTERVAL '30 day' THEN u.id END)::numeric * 100.0 / COUNT(*), 2
    ) AS d30,
    ROUND(
        COUNT(DISTINCT CASE WHEN ue.entry_at >= u.date_joined + INTERVAL '60 day' THEN u.id END)::numeric * 100.0 / COUNT(*), 2
    ) AS d60,
    ROUND(
        COUNT(DISTINCT CASE WHEN ue.entry_at >= u.date_joined + INTERVAL '90 day' THEN u.id END)::numeric * 100.0 / COUNT(*), 2
    ) AS d90
FROM users u
JOIN userentry ue ON ue.user_id = u.id
GROUP BY cohort_month
ORDER BY cohort_month

Выводы:
Общая активность пользователей
0 (день регистрации): колеблется от 1–45% в зависимости от месяца регистрации, обычно около 20–40% - это значит, что меньше половины новых пользователей активно пользуются продуктом сразу.
d1–d3: быстро падает — у большинства когорт доля активных пользователей на 3-й день уже падает в два раза и больше - это значит, что многие пользователи заходят один раз и не возвращаются.
d7–d30: очень резкое падение - сильного удержания пользователей нет. Большинство не возвращаются на платформу после первой недели.
d60–d90: почти всегда около 0–5% - это означает, что долгосрочная активность крайне низкая. Лояльных пользователей мало, и продукт теряет аудиторию через 2–3 месяца.
Вывод по активности:Пользователи чаще всего заходят один раз или несколько раз в первую неделю и быстро теряют интерес. 

Так как большинство пользователей не возвращаются через неделю и активность резко падает после 7–14 дней, короткие тарифы (1–2 недели) могут быть более эффективны для новых пользователей.
Долгосрочные тарифы (30–90 дней) будут малоэффективны, если пользователи не успевают оценить продукт за первую неделю.
Можно подумать о тестовом периоде 7–14 дней → затем предложить платное продление, чтобы «поймать» активных пользователей.
Вывод:
Ключевой период удержания: первые 7–14 дней после регистрации.
Оптимальная тарифная политика: короткий пробный период, с акцентом на быстрое вовлечение и ценность продукта в первые дни.

Задание 2
WITH trans AS (
    SELECT
        t.user_id,
        SUM(CASE WHEN tt.type IN (1,23,24,25,26,27,28,30) THEN -t.value  ELSE t.value END) AS balance,
        SUM(CASE WHEN tt.type IN (1,23,24,25,26,27,28,30) THEN t.value ELSE 0 END) AS total_spent,
        SUM(CASE WHEN tt.type NOT IN (1,23,24,25,26,27,28,30) THEN t.value ELSE 0 END) AS total_earned
    FROM transaction t
    JOIN transactiontype tt ON t.type_id = tt.type
    GROUP BY t.user_id
)
SELECT
    ROUND(AVG(total_spent), 2) AS avg_spent_per_user,
    ROUND(AVG(total_earned), 2) AS avg_earned_per_user,
    ROUND(AVG(balance), 2) AS avg_balance,
    ROUND(MODE() WITHIN GROUP (ORDER BY balance), 2) AS median_balance
FROM trans
Выводы:
сколько в среднем коинов списывает 1 человек - 31.29; 
сколько в среднем коинов начисляется 1 человеку - 306.52; 
какой средний баланс среди всех пользователей - 275.22;  
какой медианный баланс среди всех пользователей - 53.00.
Пользователи в среднем зарабатывают в 10 раз больше кодкоинов, чем тратят. При этом медианный баланс (53) значительно ниже среднего (275), что указывает на сильную неравномерность распределения и наличие небольшой группы пользователей с очень высокими накоплениями.
Это говорит о слабой монетизации внутренней экономики и недостаточной мотивации к трате коинов. При формировании цены подписки нужно учитывать среднее число задач, среднее число тестов, и показатели retention. 


Задание 3

WITH
-- 1. Задачи: сколько задач решил и сколько попыток было
tasks AS (
    SELECT
        cs.user_id,
        COUNT(DISTINCT cs.problem_id) AS tasks_cnt,
        COUNT(*) AS task_attempts
    FROM codesubmit cs
    GROUP BY cs.user_id
),

-- 2. Тесты: сколько тестов начал и сколько попыток тестов
tests AS (
    SELECT
        ts.user_id,
        COUNT(DISTINCT ts.test_id) AS tests_cnt,
        COUNT(*) AS test_attempts
    FROM teststart ts
    GROUP BY ts.user_id
),

-- 3. Активные пользователи (те, кто решал задачи или проходил тесты)
active_users AS (
    SELECT
        COALESCE(t.user_id, ts.user_id) AS user_id,
        COALESCE(t.tasks_cnt, 0) AS tasks_cnt,
        COALESCE(t.task_attempts, 0) AS task_attempts,
        COALESCE(ts.tests_cnt, 0) AS tests_cnt,
        COALESCE(ts.test_attempts, 0) AS test_attempts
    FROM tasks t
    FULL JOIN tests ts
        ON t.user_id = ts.user_id
)

--
SELECT
    -- Среднее число решённых задач на активного пользователя
    ROUND(AVG(tasks_cnt)::numeric, 2) AS avg_tasks_per_user,

    -- Среднее число тестов на активного пользователя
    ROUND(AVG(tests_cnt)::numeric, 2) AS avg_tests_per_user,

    -- Среднее число попыток на 1 задачу
    ROUND(
        SUM(task_attempts)::numeric / NULLIF(SUM(tasks_cnt), 0),
        2
    ) AS avg_attempts_per_task,

    -- Среднее число попыток на 1 тест
    ROUND(
        SUM(test_attempts)::numeric / NULLIF(SUM(tests_cnt), 0),
        2
    ) AS avg_attempts_per_test

FROM active_users

Выводы:
Сколько в среднем пользователь решает задач -  4.77
Сколько в среднем пользователь проходит тестов - 1.19
Сколько в среднем пользователь делает попыток для решения 1 задачи -  2.90
Сколько в среднем пользователь делает попыток для прохождения 1 теста - 1.26

// какая доля от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест - 61.97 
WITH active_users AS (
    SELECT DISTINCT user_id
    FROM codesubmit
    
    UNION
    
    SELECT DISTINCT user_id
    FROM teststart
)

SELECT
    ROUND(
        COUNT(a.user_id)::numeric
        /
        COUNT(DISTINCT u.id)
        * 100,
        2
    ) AS active_user_share_percent
FROM users u
LEFT JOIN active_users a
    ON u.id = a.user_id
    

// информация по покупкам материалов на платформе за кодкоины
Сколько человек открывало задачи за кодкоины - 0?
SELECT COUNT(DISTINCT t.user_id) AS users_opened_tasks
FROM transaction t
JOIN transactiontype tt ON t.type_id = tt.type
WHERE t.value < 0
  AND tt.type = 1
  AND tt.description ILIKE '%задач%'
  
Сколько человек открывало тесты за кодкоины - 0?
SELECT COUNT(DISTINCT t.user_id) AS users_opened_tests
FROM transaction t
JOIN transactiontype tt ON t.type_id = tt.type
WHERE t.value < 0
  AND tt.type = 1
  AND tt.description ILIKE '%тест%'
Сколько человек открывало подсказки за кодкоины - 
Сколько человек открывало решения за кодкоины - 
Сколько подсказок/тестов/задач/решений было открыто за кодкоины (если задача/... открыта разными людьми, то это считаем разными фактами открытия) - 
Сколько человек покупало хотя бы что-то из вышеперечисленного - 
Сколько человек всего имеют хотя бы 1 транзакцию, пусть даже только начисление - 



Дополнительное задание 1
Дополнительная метрика 1: Среднее время между попытками решения задач
Что это:
Мне кажется, важно посчитать, как часто пользователи повторно пытаются решить задачи. Для этого я предлагаю посчитать среднее время между последующими codesubmit для одного пользователя.
Это полезно, потому что:
1) позволяет оценить вовлечённость и темп обучения.
2) если пользователи долго не делают повторных попыток → стоит подумать о напоминаниях или подсказках.

Код для расчета:
WITH attempts AS (
    SELECT
        user_id,
        problem_id,
        created_at,
        LAG(created_at) OVER (PARTITION BY user_id, problem_id ORDER BY created_at) AS prev_attempt
    FROM codesubmit
)
SELECT
    ROUND(AVG(EXTRACT(EPOCH FROM (created_at - prev_attempt))/3600)::numeric, 2) AS avg_hours_between_attempts
FROM attempts
WHERE prev_attempt IS NOT NULL

Результат: среднее количество часов между попытками решения задач 

Дополнительная метрика 2: Процент пользователей, завершивших хотя бы одну задачу и один тест
Что это:
Важно посчитать, сколько пользователей одновременно решают задачи и проходят тесты.
Почему?
1)это поможет понять перекрестную активность и повлиять на стратегию формирования тарифов: если пользователи, которые делают и то, и другое, более активны и склонны к покупкам → можно выделить премиум-пакет.
Код для расчета:

WITH task_users AS (
    SELECT DISTINCT user_id
    FROM coderun
),
test_users AS (
    SELECT DISTINCT user_id
    FROM teststart
)
SELECT
    ROUND(100.0 * COUNT(DISTINCT tu.user_id) 
        / (SELECT COUNT(DISTINCT user_id) FROM users), 2) AS percent_users_tasks_and_tests
FROM task_users tu
JOIN test_users ts ON tu.user_id = ts.user_id

Дополнительная метрика 3: 
Предлагаю посчитать Среднее количество CodeCoins, потраченных на одну задачу или тест
Это покажет эффективность монетизации и стоимость контента, что полезно, так как:
1) поможет корректно формировать тарифы и определять ценность разных видов контента.
2) поможет выявить, какие элементы контента приносят больше дохода.

Код:
-- Средние затраты на задачи
SELECT
    ROUND(AVG(ABS(t.value))::numeric, 2) AS avg_spent_per_task
FROM transaction t
JOIN coderun cr ON t.user_id = cr.user_id
WHERE t.value < 0 AND t.type_id = 1;

-- Средние затраты на тесты
SELECT
    ROUND(AVG(ABS(t.value))::numeric, 2) AS avg_spent_per_test
FROM transaction t
JOIN teststart ts ON t.user_id = ts.user_id
WHERE t.value < 0 AND t.type_id = 1

Вывод: эти метрики помогут 
1) понять вовлечённость пользователей (время между попытками),
2) выявить активных пользователей, которые делают и задачи, и тесты,
3) оценить средние расходы на разные виды контента → полезно для тарификации и монетизации.

Итоговые выводы:
Предлагаемая модель монетизации:
Я предлагаю сделать несколько подписок:
1) Краткосрочную подписку на 1 неделю, что бы пользователи могли попробовать весь платный функционал за короткий период. 
2) Месячная подписка включает: задачи + тесты + подсказки + решения за фиксированное количество CodeCoins/месяц.
3) Годовая "премиум" подписка для постоянных пользователей (со значительной скидкой)

Стоимость подписки: 
Так как средний пользователь тратит около 31 codecoin за покупку контента, но средний баланс на счету 275 codecoin, то лучше сделать:
1) Подписка краткосрочная на неделю5 50-70 codecoin (низкий порог, что бы попробоавть платформу)
2) Месячная подписка 150-200 codecoin (покрывает средний объем активности пользователей)
3) Годовая подписка 1200-15000 codecoin (со скидкой 15-25%) - мотивирует сразу полатить полный пакет и повышает retention.

В состав платной подписки можно включить: 
  - возможность решать неограниченное кол-во задач/тестов
  - подсказки, решения

Можно ограничить бесплатную версию по количеству попыток или количеству задач в день. 


Важно стимулирование вовлечённость, так как она низкая:
Напоминания о незавершённых задачах и тестах.
Бонусы за ежедневное или недельное использование.
Внутренняя валюта (CodeCoins) должна быть видимой и используемой, чтобы пользователи видели ценность расхода.

Среднее время между попытками и доля пользователей, проходящих и задачи, и тесты, показывает, что активные пользователи концентрируются на задачах и тестах одновременно.
Поэтому в подписке стоит включить оба типа контента, чтобы повысить retention и стимулировать траты.
Важно перейти от модели разрозненных списаний за отдельные задачи/тесты → к подписке с доступом к пакетам контента + бонусами за активность.
Продумать ценовую стратегию пакетов, исходя из среднего числа попыток на задачу/тест и среднего расхода CodeCoins.
Оставить микропокупки для «дополнительных подсказок и решений», чтобы пользователи могли «доплачивать» за конкретный бонус.


Дополнительное задание 2.

Код:
WITH all_activity AS (
    SELECT
        user_id,
        created_at,
        'task_attempt' AS activity_type
    FROM codesubmit
    UNION ALL
    SELECT
        user_id,
        created_at,
        'task_open' AS activity_type
    FROM coderun
    UNION ALL
    SELECT
        user_id,
        created_at,
        'test_start' AS activity_type
    FROM teststart
)

SELECT
    EXTRACT(DOW FROM created_at) AS day_of_week,   -- 0 = воскресенье, 1 = понедельник ...
    EXTRACT(HOUR FROM created_at) AS hour_of_day,  -- 0..23
    activity_type,
    COUNT(*) AS activity_count
FROM all_activity
GROUP BY day_of_week, hour_of_day, activity_type
ORDER BY day_of_week, hour_of_day, activity_type

Выводы: из данных видно, что максимальная активность приходится на пятницу и субботу (особенно с 6:00 до 18:00), в воскресенье активность ниже (особенно ночью или ранним утром). Итого, релизы лучше планировать в дни с низкой активностью: поздний вечер воскресенья или ночь понедельника.
Оптимальное время для релизов - ночь (0:00-5:00). Для релиза задач - обязательно ночное время, по тестам можно более гибко, так как там нагрузка меньше.

<img width="1836" height="232" alt="image" src="https://github.com/user-attachments/assets/5162ce24-9bde-45ed-a17e-f8611f009a9f" /># Задание 1

WITH t1 AS (
    SELECT 
        u.id,
        TO_CHAR(u.date_joined, 'YYYY-MM') AS cohorta,
        ue.entry_at::date - u.date_joined::date AS diff
    FROM users u
    JOIN userentry ue ON u.id = ue.user_id
    WHERE u.date_joined <= ue.entry_at
)
SELECT 
    cohorta, 
    ROUND(COUNT(DISTINCT CASE WHEN diff >= 0 THEN id END) * 100.0 / COUNT(DISTINCT CASE WHEN diff >= 0 THEN id END), 2) AS "day0",
    ROUND(COUNT(DISTINCT CASE WHEN diff >= 1 THEN id END) * 100.0 / COUNT(DISTINCT CASE WHEN diff >= 0 THEN id END), 2) AS "day1",
    ROUND(COUNT(DISTINCT CASE WHEN diff >= 3 THEN id END) * 100.0 / COUNT(DISTINCT CASE WHEN diff >= 0 THEN id END), 2) AS "day3",
    ROUND(COUNT(DISTINCT CASE WHEN diff >= 7 THEN id END) * 100.0 / COUNT(DISTINCT CASE WHEN diff >= 0 THEN id END), 2) AS "day7",
    ROUND(COUNT(DISTINCT CASE WHEN diff >= 14 THEN id END) * 100.0 / COUNT(DISTINCT CASE WHEN diff >= 0 THEN id END), 2) AS "day14",
    ROUND(COUNT(DISTINCT CASE WHEN diff >= 30 THEN id END) * 100.0 / COUNT(DISTINCT CASE WHEN diff >= 0 THEN id END), 2) AS "day30",
    ROUND(COUNT(DISTINCT CASE WHEN diff >= 60 THEN id END) * 100.0 / COUNT(DISTINCT CASE WHEN diff >= 0 THEN id END), 2) AS "day60",
    ROUND(COUNT(DISTINCT CASE WHEN diff >= 90 THEN id END) * 100.0 / COUNT(DISTINCT CASE WHEN diff >= 0 THEN id END), 2) AS "day90"
FROM t1
GROUP BY cohorta
ORDER BY cohorta;

ВЫВОД: данный анализ показывает резкое снижение активности пользователей после первых суток, т.к. к 7му дню 
удерживается лишь небольшая часть аудитории, к 30-му дню удержание падает до 8–10%, а к 90-му устремляется к нулю (к 30 и 90 дням
возвращаются только самые вовлеченные пользователи) 
подписка на короткий срок неэффективная из-за высокой стоимости привлечения.
поэтому стоит сфокусироваться на двух ключевых тарифах: 1 месяц (для пользователей, закрывающих точечные задачи) и 1 год 
со значительной скидкой (для удержания целевой аудитории в долгосрочной перспективе).

# Задание 2
-- CTE 1: расчет суммы списаний (трат) по каждому пользователю
WITH spends AS (
    SELECT 
        SUM(t.value) AS spent_value, 
        t.user_id
    FROM transaction t
    INNER JOIN transactiontype tt ON t.type_id = tt.type
    WHERE tt.type IN (1, 23, 24, 25, 26, 27, 28, 30)
    GROUP BY t.user_id
),
-- CTE 2: расчет суммы начислений (пополнений) по каждому пользователю
charge AS (
    SELECT 
        SUM(t.value) AS charge_value, 
        t.user_id
    FROM transaction t
    INNER JOIN transactiontype tt ON t.type_id = tt.type
    WHERE tt.type NOT IN (1, 23, 24, 25, 26, 27, 28, 30)
    GROUP BY t.user_id
),
-- CTE 3: объединение начислений и списаний для каждого пользователя
diff AS (
    SELECT 
        COALESCE(s.spent_value, 0) AS spent_value, 
        COALESCE(s.user_id, c.user_id) AS user_id,
        COALESCE(c.charge_value, 0) AS charge_value
    FROM spends s
    FULL JOIN charge c ON s.user_id = c.user_id
)
-- итоговый расчет агрегированных метрик по всей выборке
SELECT 
    AVG(spent_value) AS spent_value,
    AVG(charge_value) AS charge_value,
    AVG(charge_value - spent_value) AS avg_balance,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY charge_value - spent_value) AS median
FROM diff;

оборот коинов сильно перенасыщен, т.к. пользователи получают в среднем 306,5 коинов, а тратят всего 31,3, из-за чего на балансах копится 
неиспользованный остаток (медиана 62 коина). переход на подписку позволит исключить этот профицит, а базовую цену тарифа стоит 
рассчитывать исходя из эквивалента реального ежемесячного расхода в 31–62 коина.

# Задание 3
-- 1. Среднее число решенных задач на пользователя
WITH table1 AS (
    SELECT user_id, problem_id FROM coderun
    UNION ALL
    SELECT user_id, problem_id FROM codesubmit
),
table2 AS (
    SELECT user_id, COUNT(DISTINCT problem_id) AS count_problem
    FROM table1
    GROUP BY user_id
)
SELECT AVG(count_problem) AS avg_problem 
FROM table2;

-- 2. Среднее число пройденных тестов на пользователя
WITH table2 AS (
    SELECT user_id, COUNT(DISTINCT test_id) AS tests
    FROM teststart
    GROUP BY user_id
)
SELECT ROUND(AVG(tests), 2) AS avg_tests_quantity
FROM table2;

-- 3. Среднее количество попыток на 1 тест
WITH table3 AS (
    SELECT COUNT(created_at) AS quantity_attempt, test_id, user_id
    FROM teststart
    GROUP BY test_id, user_id
)
SELECT ROUND(AVG(quantity_attempt), 2) AS quantity_attempt
FROM table3;

-- 4. Среднее количество попыток на 1 задачу
WITH table4 AS (
    SELECT user_id, problem_id, created_at FROM coderun
    UNION ALL
    SELECT user_id, problem_id, created_at FROM codesubmit
),
table5 AS (
    SELECT user_id, problem_id, COUNT(created_at) AS quantity_attempt
    FROM table4
    GROUP BY problem_id, user_id
)
SELECT ROUND(AVG(quantity_attempt), 2) AS quantity_attempt
FROM table5;

-- 5. Доля пользователей, решавших хотя бы 1 задачу или проходивших 1 тест
WITH table6 AS (
    SELECT user_id FROM coderun
    UNION 
    SELECT user_id FROM codesubmit
    UNION
    SELECT user_id FROM teststart
)
SELECT COUNT(t.user_id) * 1.0 / COUNT(u.id) AS dolya
FROM table6 t 
RIGHT JOIN users u ON t.user_id = u.id;

-- 6. Покупки материалов за кодкоины и статистика транзакций
SELECT 
    COUNT(DISTINCT CASE WHEN tt.description ILIKE '%задач%' THEN user_id END) AS task_user_count,
    COUNT(DISTINCT CASE WHEN tt.description ILIKE '%подсказк%' THEN user_id END) AS clue_user_count,
    COUNT(DISTINCT CASE WHEN tt.description ILIKE '%тест%' THEN user_id END) AS test_user_count,
    COUNT(DISTINCT CASE WHEN tt.description ILIKE '%решен%' THEN user_id END) AS sol_user_count,
    COUNT(CASE WHEN tt.description ILIKE '%задач%'
                 OR tt.description ILIKE '%подсказк%'
                 OR tt.description ILIKE '%тест%'
                 OR tt.description ILIKE '%решен%' THEN t.id END) AS total_coin,
    COUNT(DISTINCT CASE WHEN tt.description ILIKE '%задач%'
                 OR tt.description ILIKE '%подсказк%'
                 OR tt.description ILIKE '%тест%'
                 OR tt.description ILIKE '%решен%' THEN user_id END) AS purchases,
    COUNT(DISTINCT user_id) AS trans_count
FROM transaction t
INNER JOIN transactiontype tt ON t.type_id = tt.type;

ВЫВОД: около 63,5% зарегистрированных пользователей проявляют активность (решают задачи или проходят тесты), отправляя в среднем по 9,35 попыток на одну задачу.
активные пользователи проходят в среднем 9,18 задач и 1,68 теста, что подтверждает устойчивый интерес к практическому материалу платформы.

--ДОПОЛНИТЕЛЬНОЕ ЗАДАНИЕ

-- 1) Мода: мода по типу списания показывает функционал платформы с максимальным спросом, 
--за который пользователи готовы платить кодкоинами прямо сейчас. 
--Знание этой метрики помогает продуктовой команде сформировать наиболее привлекательный наполняющий
--состав новой подписки, чтобы гарантировать высокую конверсию при переходе к новой модели.
SELECT mode() WITHIN GROUP (ORDER BY tt.description) AS moda
FROM transactiontype tt
inner join transaction t on tt.type = t.type_id 
where  tt.type in (1, 23, 24, 25, 26, 27, 28, 30)

--% пользователей от числа активных (проходивших тесты или запускавших код), 
-- которые потратили хотя бы 1 кодкоин на покупку материалов.
-- позволяет оценить размер платящего сегмента внутри ядра аудитории и спрогнозировать потенциальный Conversion Rate в платную подписку
WITH active_users AS (
    SELECT user_id FROM coderun
    UNION
    SELECT user_id FROM codesubmit
    UNION
    SELECT user_id FROM teststart
),
buyers AS (
    SELECT DISTINCT t.user_id
    FROM transaction t
    INNER JOIN transactiontype tt ON t.type_id = tt.type
    WHERE tt.description ILIKE '%задач%'
       OR tt.description ILIKE '%подсказк%'
       OR tt.description ILIKE '%тест%'
       OR tt.description ILIKE '%решен%'
)
SELECT 
    COUNT(a.user_id) AS active_users,
    COUNT(b.user_id) AS buyer_users,
    ROUND(COUNT(b.user_id) * 1.0 / COUNT(a.user_id), 2) AS dolya
FROM active_users a
LEFT JOIN buyers b ON a.user_id = b.user_id;


-- АВС анализ  по парето разделяет пользователей на три группы 
--(A, B и C) по их вкладу в общую выручку. это помогает установить адекватную цену подписки,
--сохранив доход от самых активных покупателей  и минимизировав отток массовой аудитории
WITH values AS (
    SELECT 
        t.user_id, 
        SUM(t.value) AS sum_value
    FROM transaction t
    INNER JOIN transactiontype tt ON t.type_id = tt.type
    WHERE tt.type IN (1, 23, 24, 25, 26, 27, 28, 30)
      AND t.value > 0
    GROUP BY t.user_id
    ORDER BY sum_value DESC
),
accumulation AS (
    SELECT 
        user_id, 
        ROUND(SUM(sum_value) OVER(ORDER BY sum_value DESC) * 100.0 / SUM(sum_value) OVER(), 1) AS nakoplenie
    FROM values
)
SELECT 
    nakoplenie,
    CASE
        WHEN nakoplenie <= 80.0 THEN 'A'
        WHEN nakoplenie BETWEEN 80.0 AND 95.0 THEN 'B'
        ELSE 'C'
    END AS category
FROM accumulation;


--ДОПОЛНИТЕЛЬНОЕ ЗАДАНИЕ 2
-- в какие дни чаще/реже всего люди проявляют активность на платформе
-- в какое время люди больше/меньше всего решают задачи/тесты на платформе
WITH active_users2 AS (
    SELECT user_id, created_at
    FROM coderun
    UNION ALL
    SELECT user_id, created_at 
    FROM codesubmit
    UNION ALL
    SELECT user_id, created_at
    FROM teststart
)
SELECT 
    TO_CHAR(created_at, 'Dy') AS dayli_activity,
    EXTRACT(HOUR FROM created_at) AS activity_hour,
    COUNT(user_id) AS user_quantity
FROM active_users2
GROUP BY TO_CHAR(created_at, 'Dy'), EXTRACT(HOUR FROM created_at)
ORDER BY dayli_activity, activity_hour;
-- ВЫВОД : анализ активности показывает, что наибольшая нагрузка на платформу приходится на будние дни с дневным и вечерним пиками в 10:00–13:00 и 18:00–19:00. Минимальное число пользователей зафиксировано в ночные часы с 02:00 до 04:00, поэтому технические работы и релизы наиболее оптимально проводить в этот интервал в ночь с субботы на воскресенье.

-- код для вывод графика (тепловой карты) с последующим экспортом в csv и выводом в эксель
WITH active_users2 AS (
    SELECT created_at FROM coderun
    UNION ALL
    SELECT created_at FROM codesubmit
    UNION ALL
    SELECT created_at FROM teststart
)
SELECT 
    EXTRACT(ISODOW FROM created_at) AS day_num,
    TO_CHAR(created_at, 'Dy') AS day_name,
    
    -- Разворачиваем часы в столбцы
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 0 THEN 1 END) AS "00:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 1 THEN 1 END) AS "01:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 2 THEN 1 END) AS "02:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 3 THEN 1 END) AS "03:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 4 THEN 1 END) AS "04:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 5 THEN 1 END) AS "05:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 6 THEN 1 END) AS "06:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 7 THEN 1 END) AS "07:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 8 THEN 1 END) AS "08:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 9 THEN 1 END) AS "09:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 10 THEN 1 END) AS "10:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 11 THEN 1 END) AS "11:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 12 THEN 1 END) AS "12:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 13 THEN 1 END) AS "13:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 14 THEN 1 END) AS "14:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 15 THEN 1 END) AS "15:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 16 THEN 1 END) AS "16:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 17 THEN 1 END) AS "17:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 18 THEN 1 END) AS "18:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 19 THEN 1 END) AS "19:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 20 THEN 1 END) AS "20:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 21 THEN 1 END) AS "21:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 22 THEN 1 END) AS "22:00",
    COUNT(CASE WHEN EXTRACT(HOUR FROM created_at) = 23 THEN 1 END) AS "23:00"
FROM active_users2
GROUP BY day_num, day_name
ORDER BY day_num;
<img width="1836" height="232" alt="image" src="https://github.com/user-attachments/assets/b21f62ef-b5bc-465e-ad24-d3370071791e" />
ВЫВОД ПО ТЕПЛОВОЙ КАРТЕ : пользователи проявляют наибольшую активность в будние дни с четким разделением на дневной (10:00–13:00) и вечерний (18:00–19:00) пики, достигая максимума в четверг в 12:00 (1 214 действий). а наименьшая нагрузка на платформу фиксируется по выходным дням, а абсолютный минимум действий приходится на ночные часы с 01:00 до 04:00. т.е. техническому директору наиболее оптимально выкатывать релизы и проводить обслуживание системы в ночь с субботы на воскресенье с 01:00 до 04:00, когда число активных пользователей падает до 5–6 человек в час

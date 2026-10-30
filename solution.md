Автор: {{Дужнова В.Е.}}
Задание 1. 

WITH base AS (
    SELECT u.id AS user_id,
           DATE_TRUNC('month', u.date_joined)::date AS cohort_month,
           -- день последней активности относительно дня регистрации;
           -- если активностей нет, считаем, что человек отвалился сразу
           COALESCE(MAX(e.entry_at::date - u.date_joined::date), -1) AS last_active_day
    FROM users u
    LEFT JOIN userentry e ON e.user_id = u.id
    GROUP BY u.id, DATE_TRUNC('month', u.date_joined)::date
)
SELECT cohort_month,
       COUNT(*) AS users,
       ROUND(100.0 * COUNT(*) FILTER (WHERE last_active_day >= 0)  / COUNT(*), 2) AS day_0,
       ROUND(100.0 * COUNT(*) FILTER (WHERE last_active_day >= 1)  / COUNT(*), 2) AS day_1,
       ROUND(100.0 * COUNT(*) FILTER (WHERE last_active_day >= 3)  / COUNT(*), 2) AS day_3,
       ROUND(100.0 * COUNT(*) FILTER (WHERE last_active_day >= 7)  / COUNT(*), 2) AS day_7,
       ROUND(100.0 * COUNT(*) FILTER (WHERE last_active_day >= 14) / COUNT(*), 2) AS day_14,
       ROUND(100.0 * COUNT(*) FILTER (WHERE last_active_day >= 30) / COUNT(*), 2) AS day_30,
       ROUND(100.0 * COUNT(*) FILTER (WHERE last_active_day >= 60) / COUNT(*), 2) AS day_60,
       ROUND(100.0 * COUNT(*) FILTER (WHERE last_active_day >= 90) / COUNT(*), 2) AS day_90
FROM base
GROUP BY cohort_month
ORDER BY cohort_month;

 Результат

| Когорта | Польз. | d0 | d1 | d3 | d7 | d14 | d30 | d60 | d90 |
|---|---|---|---|---|---|---|---|---|---|
| 2021-03 | 5 | 100.00 | 100.00 | 100.00 | 100.00 | 100.00 | 20.00 | 0.00 | 0.00 |
| 2021-04 | 15 | 60.00 | 60.00 | 46.67 | 33.33 | 33.33 | 0.00 | 0.00 | 0.00 |
| 2021-05 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| 2021-06 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| 2021-07 | 2 | 50.00 | 50.00 | 50.00 | 50.00 | 50.00 | 50.00 | 50.00 | 50.00 |
| 2021-08 | 1 | 100.00 | 100.00 | 100.00 | 100.00 | 100.00 | 100.00 | 100.00 | 100.00 |
| 2021-09 | 13 | 15.38 | 15.38 | 15.38 | 7.69 | 7.69 | 7.69 | 7.69 | 7.69 |
| 2021-10 | 8 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| 2021-11 | 210 | 90.00 | 65.24 | 59.52 | 57.62 | 54.76 | 47.14 | 36.67 | 26.67 |
| 2021-12 | 132 | 91.67 | 50.00 | 40.15 | 38.64 | 33.33 | 28.79 | 21.21 | 12.12 |
| 2022-01 | 602 | 82.72 | 36.88 | 30.56 | 25.08 | 20.93 | 12.79 | 7.64 | 3.82 |
| 2022-02 | 1058 | 84.22 | 27.60 | 20.04 | 13.89 | 10.87 | 8.03 | 4.82 | 1.04 |
| 2022-03 | 479 | 86.64 | 30.06 | 22.76 | 16.08 | 12.53 | 7.31 | 1.04 | 0.00 |
| 2022-04 | 237 | 87.76 | 41.77 | 32.07 | 25.74 | 19.41 | 9.28 | 0.00 | 0.00 |

 Выводы

Маленькие когорты (до октября 2021 — по 2–15 человек) не подходят для выводов: слишком мало людей. Более 95% пользователей приходятся на когорты с ноября 2021 по апрель 2022.
Самое важное происходит в первые сутки: в день регистрации на платформу заходят почти все (84–90%), но уже на следующий день их остаётся 28–65%. Если человек не вернулся на второй день, дальше он, скорее всего, не вернётся уже никогда.
Дальше люди «отваливаются» гораздо медленнее. К концу первой недели (дни 7–14) картина почти не меняется — те, кто остался, уже превращаются в постоянных пользователей.
Месяц доживают только 7–12%, три месяца — почти никто (0–4%).
Что это значит для подписки: люди делятся на две группы — «зашёл на недельку порешать» и «занимается постоянно». Под это и делаем тарифы: короткий (неделя — для первой группы) и месяц/год со скидкой (для постоянных пользователей). Годовой без большой скидки продавать бессмысленно — людей, которые пользуются платформой так долго, слишком мало.
Отдельно интересна когорта ноября 2021 — у неё лучший результат (26.67% остаются через 90 дней). Это первые пользователи после запуска; что-то в этот период работало особенно хорошо — стоит разобраться, что именно, и повторить.

Задание 2.


WITH bal AS (
    SELECT user_id,
           SUM(CASE WHEN type_id IN (1, 23, 24, 25, 26, 27, 28) THEN value ELSE 0 END) AS spent,
           SUM(CASE WHEN type_id NOT IN (1, 23, 24, 25, 26, 27, 28) THEN value ELSE 0 END) AS earned
    FROM "transaction"
    GROUP BY user_id
)
SELECT ROUND(AVG(spent)::numeric, 2)                 AS avg_spent,
       ROUND(AVG(earned)::numeric, 2)                AS avg_earned,
       ROUND(AVG(earned - spent)::numeric, 2)        AS avg_balance,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY earned - spent))::numeric, 2) AS median_balance
FROM bal;
 
Примечание: медиана посчитана через `PERCENTILE_CONT(0.5) WITHIN GROUP` — корректное определение медианы в PostgreSQL. Упомянутая в задании конструкция `mode within group` возвращает моду (самое частое значение), а не медиану.

 Результат

| Метрика | Значение (коины) |
|---|---|
| Средние списания на 1 человека | 31.29 |
| Средние начисления на 1 человека | 306.52 |
| Средний баланс | 275.22 |
| Медианный баланс | 62.00 |

Вариант усреднения по всем 2 774 пользователям: списания 27.10, начисления 265.41, средний баланс 238.31, медиана 56.00.

 Выводы

Среднее на счету (275 коинов) в 4.5 раза больше, чем у половины пользователей (медиана — 62). Это значит, что несколько «китов» с огромными балансами завышают среднюю картинку, а у обычного пользователя на счету совсем немного — всего 62 коина.
Люди тратят мало: в среднем за всё время списывается 31 коин на человека, хотя начислено 306. То есть коины копятся, а не тратятся. При этом за деньги коины почти никто не покупал: за всё время было всего 37 пополнений на 2 402 пользователей (то есть примерно 1 из 65). Получается, платформа практически ничего не зарабатывает на текущей модели — значит, переход на подписку действительно нужен.
Цену подписки логично привязывать к обычному пользователю (медиане), а не к среднему: типичный пользователь тратит десятки коинов. Если примерно прикинуть, что 1 коин стоит 2–4 рубля, месячная подписка в районе 150–300 рублей закроет его потребности. Точный курс коина к рублю нужно уточнить у IT Resume — тогда цену можно зафиксировать точнее.
У многих пользователей просто лежат «мёртвые» коины (в среднем 275 на человека). Хорошая идея — позволить обменять эти накопления на скидку или первые месяцы подписки. Так пользователи не потеряют накопленное и охотнее перейдут на новый формат.

Задание 3. Активность и покупки за CodeCoins


WITH users_total AS (
    SELECT COUNT(*) AS total_users FROM users
),
task_stats AS (
    SELECT COUNT(DISTINCT user_id) AS users_submitted,
           COUNT(DISTINCT user_id || '-' || problem_id) AS user_problem_pairs,
           COUNT(*) AS attempts
    FROM codesubmit
),
solved_stats AS (
    SELECT user_id, COUNT(DISTINCT problem_id) AS solved_cnt
    FROM codesubmit WHERE is_false = 0
    GROUP BY user_id
),
test_start AS (
    SELECT COUNT(DISTINCT user_id) AS users_started,
           COUNT(DISTINCT user_id || '-' || test_id) AS user_test_pairs,
           COUNT(*) AS attempts
    FROM teststart
),
test_pass AS (
    SELECT user_id, COUNT(DISTINCT test_id) AS passed_cnt
    FROM testresult
    GROUP BY user_id
),
purchases AS (
    SELECT 'task' AS what, COUNT(DISTINCT user_id) AS users, COUNT(*) AS opens
    FROM "transaction" WHERE type_id = 23
    UNION ALL
    SELECT 'test', COUNT(DISTINCT user_id), COUNT(*)
    FROM "transaction" WHERE type_id = 27
    UNION ALL
    SELECT 'hint', COUNT(DISTINCT user_id), COUNT(*)
    FROM "transaction" WHERE type_id = 24
    UNION ALL
    SELECT 'solution', COUNT(DISTINCT user_id), COUNT(*)
    FROM "transaction" WHERE type_id = 25
)
SELECT
    (SELECT ROUND(AVG(solved_cnt)::numeric, 2) FROM solved_stats)               AS avg_solved_tasks,
    (SELECT ROUND(AVG(passed_cnt)::numeric, 2) FROM test_pass)                  AS avg_passed_tests,
    (SELECT ROUND(attempts::numeric / user_problem_pairs, 2) FROM task_stats)   AS avg_attempts_per_task,
    (SELECT ROUND(attempts::numeric / user_test_pairs, 2) FROM test_start)      AS avg_attempts_per_test,
    ROUND(100.0 * (SELECT COUNT(DISTINCT user_id)
                   FROM (SELECT user_id FROM codesubmit
                         UNION
                         SELECT user_id FROM teststart) a)
                 / (SELECT total_users FROM users_total), 2)                    AS pct_active_users,
    (SELECT users FROM purchases WHERE what = 'task')                           AS users_bought_tasks,
    (SELECT users FROM purchases WHERE what = 'test')                           AS users_bought_tests,
    (SELECT users FROM purchases WHERE what = 'hint')                           AS users_bought_hints,
    (SELECT users FROM purchases WHERE what = 'solution')                       AS users_bought_solutions,
    (SELECT SUM(opens) FROM purchases)                                          AS total_opens,
    (SELECT COUNT(DISTINCT user_id) FROM "transaction"
     WHERE type_id IN (23, 24, 25, 26, 27, 28))                                 AS users_any_purchase,
    (SELECT COUNT(DISTINCT user_id) FROM "transaction")                         AS users_any_transaction,
    (SELECT total_users FROM users_total)                                       AS total_users;

 Результат

| Метрика | Значение |
|---|---|
| Среднее число решённых задач (на решающего) | 10.53 |
| Среднее число пройденных тестов (на проходящего) | 1.62 |
| Среднее число попыток на 1 задачу | 2.90 |
| Среднее число попыток на 1 тест | 1.26 |
| Доля пользователей, решавших задачу или начинавших тест | 61.97% |
| Покупали задачи за коины | 522 чел. |
| Покупали тесты за коины | 676 чел. |
| Покупали подсказки за коины | 53 чел. |
| Покупали решения за коины | 151 чел. |
| Всего фактов открытия контента за коины | 3 205 |
| Покупали хотя бы что-то из этого | 1 139 чел. |
| Пользователей с хотя бы 1 транзакцией | 2 402 чел. |
| Всего пользователей | 2 774 чел. |

 Выводы

Активность хорошая: почти 2 из 3 пользователей (62%) решают задачи или проходят тесты. Значит, можно смело оставлять большую часть контента бесплатной — люди и так занимаются.
На одну задачу пользователь тратит примерно 3 попытки — то есть задачи даются непросто, и помощь (подсказки, решения) была бы очень кстати. Но подсказки и решения почти не покупают за коины — их взяли всего 53 и 151 человек соответственно. Видимо, отдельно покупать их не хочется,но в подписке они могут идти бесплатно.
Что покупают охотнее всего: тесты (676 человек), на втором месте — задачи (522). Тесты короткие и дешёвые, как раз для тех, кто хочет позаниматься срочно и ненадолго. Под это подходит недельный тариф.
Покупать за коины хотя бы что-то пробовали 1 139 человек — это 41% всех пользователей. Это готовая аудитория для подписки: им просто нужно предложить удобство — «плати раз в месяц и решай всё без ограничений», — вместо того чтобы каждый раз откладывать коины.
Есть и риск: почти половина пользователей (45%) заходила на платформу, но ничего не покупала. Чтобы не потерять их, в бесплатной версии должны остаться базовые задачи и хотя бы часть тестов.

 
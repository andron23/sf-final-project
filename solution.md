# Решение задач для IT Resume

Для ознакомления с базой данных была произведена выборка первых десяти строк из каждой таблицы. Результаты выборки выгружены в папку Qery_results, откуда их можно загружать в Power Query, например. Для разнообразия был выбран формат CSV, хотя на таких маленьких выборках он преимуществ не дает перед форматом ".xlsx".

В ту же папку были выгружены результаты запросов, касающихся решений задач и предложений по их итогам. 
Более подробно всё описано в файле README.md

```sql
WITH cohort_users AS (
    SELECT 
        id AS user_id,
        DATE_TRUNC('month', date_joined) AS cohort_month,
        date_joined::date AS registration_date
    FROM users
),
user_activity AS (
    SELECT DISTINCT
        ue.user_id,
        ue.entry_at::date AS activity_date
    FROM userentry ue
),
cohort_activity AS (
    SELECT 
        cu.user_id,
        cu.cohort_month,
        cu.registration_date,
        ua.activity_date,
        (ua.activity_date - cu.registration_date) AS days_since_registration
    FROM cohort_users cu
    LEFT JOIN user_activity ua ON cu.user_id = ua.user_id
),
retention_windows AS (
    SELECT 
        ca.user_id,
        ca.cohort_month,
        ca.registration_date,
        MAX(CASE WHEN ca.days_since_registration >= 0 THEN 1 ELSE 0 END) AS active_day_0,
        MAX(CASE WHEN ca.days_since_registration >= 1 THEN 1 ELSE 0 END) AS active_day_1,
        MAX(CASE WHEN ca.days_since_registration >= 3 THEN 1 ELSE 0 END) AS active_day_3,
        MAX(CASE WHEN ca.days_since_registration >= 7 THEN 1 ELSE 0 END) AS active_day_7,
        MAX(CASE WHEN ca.days_since_registration >= 14 THEN 1 ELSE 0 END) AS active_day_14,
        MAX(CASE WHEN ca.days_since_registration >= 30 THEN 1 ELSE 0 END) AS active_day_30,
        MAX(CASE WHEN ca.days_since_registration >= 60 THEN 1 ELSE 0 END) AS active_day_60,
        MAX(CASE WHEN ca.days_since_registration >= 90 THEN 1 ELSE 0 END) AS active_day_90
    FROM cohort_activity ca
    GROUP BY ca.user_id, ca.cohort_month, ca.registration_date
)
SELECT 
    TO_CHAR(cohort_month, 'YYYY-MM') AS cohort,
    COUNT(DISTINCT user_id) AS total_users,
    ROUND(100.0 * SUM(active_day_0) / COUNT(DISTINCT user_id), 2) AS day_0,
    ROUND(100.0 * SUM(active_day_1) / COUNT(DISTINCT user_id), 2) AS day_1,
    ROUND(100.0 * SUM(active_day_3) / COUNT(DISTINCT user_id), 2) AS day_3,
    ROUND(100.0 * SUM(active_day_7) / COUNT(DISTINCT user_id), 2) AS day_7,
    ROUND(100.0 * SUM(active_day_14) / COUNT(DISTINCT user_id), 2) AS day_14,
    ROUND(100.0 * SUM(active_day_30) / COUNT(DISTINCT user_id), 2) AS day_30,
    ROUND(100.0 * SUM(active_day_60) / COUNT(DISTINCT user_id), 2) AS day_60,
    ROUND(100.0 * SUM(active_day_90) / COUNT(DISTINCT user_id), 2) AS day_90
FROM retention_windows
GROUP BY cohort_month
ORDER BY cohort_month;
```

**Выводы:**

Анализ rolling retention показывает следующие закономерности:

1. **Высокий retention в день регистрации (day_0)**: Большинство когорт показывают retention 80-90% в день регистрации, что говорит о хорошем первом впечатлении от платформы.

2. **Резкое падение на следующий день (day_1)**: Retention падает до 27-65% уже на второй день, что указывает на необходимость улучшения онбординга и удержания пользователей в первые дни.

3. **Стабилизация на 7-14 день**: К 7-14 дню retention стабилизируется на уровне 10-38% в зависимости от когорты. Это критический период для формирования привычки использования платформы.

4. **Долгосрочный retention (30-90 дней)**: К 30 дню retention составляет 3-47%, к 90 дню - 0-27%. Наиболее успешные когорты (ноябрь-декабрь 2021) показывают лучшие долгосрочные результаты.

5. **Рекомендации по тарифам**: 
   - Учитывая, что значительная часть пользователей возвращается в течение 7-14 дней, имеет смысл предложить **недельную подписку** для тех, кто хочет попробовать платформу.
   - Для долгосрочных пользователей (30+ дней retention 3-47%) оптимальна **месячная подписка**.
   - **Годовая подписка** с большой скидкой будет привлекательна для наиболее активных пользователей (около 1-27% от когорты).

## Задание 2: Метрики по балансу пользователей

```sql
WITH user_debits AS (
    SELECT 
        user_id,
        SUM(value) AS total_debits
    FROM transaction
    WHERE user_id IS NOT NULL 
      AND type_id IN (1, 23, 24, 25, 26, 27, 28, 30)
    GROUP BY user_id
),
user_credits AS (
    SELECT 
        user_id,
        SUM(value) AS total_credits
    FROM transaction
    WHERE user_id IS NOT NULL 
      AND type_id NOT IN (1, 23, 24, 25, 26, 27, 28, 30)
    GROUP BY user_id
),
user_balances AS (
    SELECT 
        u.id AS user_id,
        COALESCE(SUM(CASE 
            WHEN t.type_id IN (1, 23, 24, 25, 26, 27, 28, 30) THEN -t.value 
            ELSE t.value 
        END), 0) AS balance
    FROM users u
    LEFT JOIN transaction t ON u.id = t.user_id
    GROUP BY u.id
),
all_metrics AS (
    SELECT 
        u.id AS user_id,
        COALESCE(ud.total_debits, 0) AS total_debits,
        COALESCE(uc.total_credits, 0) AS total_credits,
        ub.balance
    FROM users u
    LEFT JOIN user_debits ud ON u.id = ud.user_id
    LEFT JOIN user_credits uc ON u.id = uc.user_id
    LEFT JOIN user_balances ub ON u.id = ub.user_id
),
sorted_balances AS (
    SELECT 
        balance,
        ROW_NUMBER() OVER (ORDER BY balance) AS rn,
        COUNT(*) OVER () AS cnt
    FROM all_metrics
)
SELECT 
    (SELECT ROUND(AVG(total_debits), 2) FROM all_metrics) AS avg_debits_per_user,
    (SELECT ROUND(AVG(total_credits), 2) FROM all_metrics) AS avg_credits_per_user,
    (SELECT ROUND(AVG(balance), 2) FROM all_metrics) AS avg_balance_all_users,
    (SELECT ROUND(AVG(balance), 2) 
     FROM sorted_balances 
     WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)) AS median_balance_all_users;
```

**Результаты:**
- Среднее списание на пользователя: **27.10** кодкоинов
- Среднее начисление на пользователя: **265.41** кодкоинов
- Средний баланс: **238.31** кодкоинов
- Медианный баланс: **56.00** кодкоинов

**Выводы:**

1. **Дисбаланс начислений и списаний**: Пользователи получают в среднем 265 кодкоинов, а тратят только 27. Это указывает на то, что текущая система начислений слишком щедрая, и пользователям не нужно покупать кодкоины.

2. **Разница между средним и медианным балансом**: Средний баланс (238) значительно выше медианного (56), что говорит о наличии небольшой группы пользователей с очень высоким балансом, в то время как у большинства баланс относительно небольшой.

3. **Рекомендации по ценообразованию**: 
   - Если 1 кодкоин = 1 рубль, то средний пользователь тратит около 27 рублей в месяц.
   - Учитывая, что медианный баланс 56 кодкоинов, можно ориентироваться на **месячную подписку в диапазоне 200-500 рублей** (с учетом того, что подписка должна включать больше функционала, чем просто покупка кодкоинов).
   - Для годовой подписки можно предложить скидку 30-40%, что даст цену около **2000-3500 рублей в год** (эквивалент 167-292 рублей в месяц).

## Задание 3: Метрики активности пользователей

```sql
WITH users_who_solved_tasks AS (
    SELECT DISTINCT user_id
    FROM codesubmit
),
users_who_took_tests AS (
    SELECT DISTINCT user_id
    FROM teststart
),
users_who_were_active AS (
    SELECT user_id FROM users_who_solved_tasks
    UNION
    SELECT user_id FROM users_who_took_tests
),
task_metrics AS (
    SELECT 
        cs.user_id,
        COUNT(DISTINCT cs.problem_id) AS tasks_solved,
        COUNT(cs.id) AS total_submits
    FROM codesubmit cs
    WHERE cs.user_id IN (SELECT user_id FROM users_who_solved_tasks)
    GROUP BY cs.user_id
),
test_metrics AS (
    SELECT 
        ts.user_id,
        COUNT(DISTINCT ts.test_id) AS tests_taken,
        COUNT(ts.id) AS total_test_attempts
    FROM teststart ts
    WHERE ts.user_id IN (SELECT user_id FROM users_who_took_tests)
    GROUP BY ts.user_id
),
purchase_stats AS (
    SELECT 
        t.user_id,
        t.type_id,
        CASE 
            WHEN t.type_id = 23 THEN 'task'
            WHEN t.type_id = 27 THEN 'test'
            WHEN t.type_id = 24 THEN 'hint'
            WHEN t.type_id = 25 THEN 'solution'
            ELSE 'other'
        END AS purchase_type
    FROM transaction t
    WHERE t.type_id IN (23, 24, 25, 27, 28)
      AND t.user_id IS NOT NULL
),
all_metrics AS (
    SELECT 
        (SELECT ROUND(AVG(tasks_solved), 2) FROM task_metrics) AS avg_tasks_solved_per_user,
        (SELECT ROUND(AVG(tests_taken), 2) FROM test_metrics) AS avg_tests_taken_per_user,
        (SELECT ROUND(AVG(total_submits::numeric / NULLIF(tasks_solved, 0)), 2) 
         FROM task_metrics WHERE tasks_solved > 0) AS avg_attempts_per_task,
        (SELECT ROUND(AVG(total_test_attempts::numeric / NULLIF(tests_taken, 0)), 2) 
         FROM test_metrics WHERE tests_taken > 0) AS avg_attempts_per_test,
        ROUND(100.0 * (SELECT COUNT(DISTINCT user_id) FROM users_who_were_active) / 
              (SELECT COUNT(*) FROM users), 2) AS pct_active_users,
        (SELECT COUNT(DISTINCT user_id) FROM purchase_stats WHERE purchase_type = 'task') AS users_bought_tasks,
        (SELECT COUNT(DISTINCT user_id) FROM purchase_stats WHERE purchase_type = 'test') AS users_bought_tests,
        (SELECT COUNT(DISTINCT user_id) FROM purchase_stats WHERE purchase_type = 'hint') AS users_bought_hints,
        (SELECT COUNT(DISTINCT user_id) FROM purchase_stats WHERE purchase_type = 'solution') AS users_bought_solutions,
        (SELECT COUNT(*) FROM purchase_stats WHERE purchase_type = 'task') AS total_tasks_purchased,
        (SELECT COUNT(*) FROM purchase_stats WHERE purchase_type = 'test') AS total_tests_purchased,
        (SELECT COUNT(*) FROM purchase_stats WHERE purchase_type = 'hint') AS total_hints_purchased,
        (SELECT COUNT(*) FROM purchase_stats WHERE purchase_type = 'solution') AS total_solutions_purchased,
        (SELECT COUNT(DISTINCT user_id) FROM purchase_stats) AS users_bought_anything,
        (SELECT COUNT(DISTINCT user_id) FROM transaction WHERE user_id IS NOT NULL) AS users_with_any_transaction
)
SELECT * FROM all_metrics;
```

**Результаты:**
- Среднее количество решенных задач на пользователя: **9.52**
- Среднее количество пройденных тестов на пользователя: **1.68**
- Среднее количество попыток на задачу: **3.17**
- Среднее количество попыток на тест: **1.15**
- Доля активных пользователей: **61.97%**
- Пользователей, купивших задачи: **522**
- Пользователей, купивших тесты: **676**
- Пользователей, купивших подсказки: **53**
- Пользователей, купивших решения: **151**
- Всего покупок задач: **1675**
- Всего покупок тестов: **989**
- Всего покупок подсказок: **118**
- Всего покупок решений: **423**
- Пользователей, купивших что-либо: **1139**
- Пользователей с хотя бы одной транзакцией: **2402**

**Выводы:**

1. **Активность пользователей**: 61.97% пользователей решали задачи или проходили тесты, что является хорошим показателем вовлеченности.

2. **Паттерны использования**:
   - Пользователи в среднем решают около 10 задач, но проходят только 1-2 теста, что говорит о том, что задачи более популярны.
   - Среднее количество попыток на задачу (3.17) указывает на то, что задачи достаточно сложные и требуют нескольких попыток.

3. **Покупки материалов**:
   - **Тесты** - самый популярный платный контент (676 пользователей купили, 989 покупок).
   - **Задачи** - второй по популярности (522 пользователя, 1675 покупок).
   - **Решения** - менее популярны (151 пользователь, 423 покупки).
   - **Подсказки** - наименее популярны (53 пользователя, 118 покупок).

4. **Рекомендации по составу подписки**:
   - **Бесплатный функционал**: Большинство задач должны оставаться бесплатными, так как это основной способ привлечения пользователей.
   - **Платные функции для подписки**:
     - Доступ к премиум-тестам (самый популярный платный контент)
     - Доступ к решениям задач (помогает в обучении)
     - Увеличенное количество попыток на задачу (сейчас в среднем 3 попытки)
     - Доступ к подсказкам (хотя они менее популярны, могут быть полезны)
   - **Ограничения для бесплатной версии**: Можно ограничить количество попыток на задачу (например, 2-3 попытки бесплатно, далее требуется подписка).



## Дополнительное задание: Дополнительные метрики

### Метрика 1: Сегментация пользователей по уровню активности и их ценность (LTV)

Мне кажется, что для принятия решения о подписке важно понять, какие пользователи наиболее ценны для платформы и готовы платить. Для этого я предлагаю посчитать сегментацию пользователей по уровню активности и их пожизненную ценность (LTV), потому что:

- Это поможет определить целевую аудиторию для подписки - какие пользователи уже активно используют платформу и могут быть готовы платить
- Покажет разницу в поведении между "power users" и "casual users", что важно для формирования тарифов
- Поможет оценить потенциальный доход от разных сегментов пользователей

Код для расчета:

```sql
WITH user_days_active AS (
    -- Считаем дни активности отдельно
    SELECT 
        user_id,
        COUNT(DISTINCT entry_at::date) AS days_active
    FROM userentry
    GROUP BY user_id
),
user_tasks_stats AS (
    -- Считаем статистику по задачам отдельно
    SELECT 
        user_id,
        COUNT(DISTINCT problem_id) AS tasks_solved,
        COUNT(id) AS total_task_attempts
    FROM codesubmit
    GROUP BY user_id
),
user_tests_stats AS (
    -- Считаем статистику по тестам отдельно
    SELECT 
        user_id,
        COUNT(DISTINCT test_id) AS tests_taken,
        COUNT(id) AS total_test_attempts
    FROM teststart
    GROUP BY user_id
),
user_spending AS (
    -- Считаем траты отдельно
    SELECT 
        user_id,
        SUM(value) AS total_spent
    FROM transaction
    WHERE type_id IN (1, 23, 24, 25, 26, 27, 28, 30)
    GROUP BY user_id
),
user_activity_stats AS (
    -- Объединяем все метрики
    SELECT 
        u.id AS user_id,
        u.date_joined,
        COALESCE(uda.days_active, 0) AS days_active,
        COALESCE(uts.tasks_solved, 0) AS tasks_solved,
        COALESCE(utest.tests_taken, 0) AS tests_taken,
        COALESCE(usp.total_spent, 0) AS total_spent
    FROM users u
    LEFT JOIN user_days_active uda ON u.id = uda.user_id
    LEFT JOIN user_tasks_stats uts ON u.id = uts.user_id
    LEFT JOIN user_tests_stats utest ON u.id = utest.user_id
    LEFT JOIN user_spending usp ON u.id = usp.user_id
),
user_segments AS (
    -- Сегментируем пользователей по активности
    SELECT 
        user_id,
        date_joined,
        days_active,
        tasks_solved,
        tests_taken,
        total_spent,
        CASE 
            WHEN tasks_solved >= 20 OR tests_taken >= 5 OR days_active >= 30 THEN 'Power User'
            WHEN tasks_solved >= 5 OR tests_taken >= 2 OR days_active >= 7 THEN 'Active User'
            WHEN tasks_solved > 0 OR tests_taken > 0 THEN 'Casual User'
            ELSE 'Inactive User'
        END AS user_segment
    FROM user_activity_stats
)
SELECT 
    user_segment,
    COUNT(*) AS user_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM user_segments), 2) AS pct_of_total,
    ROUND(AVG(days_active), 2) AS avg_days_active,
    ROUND(AVG(tasks_solved), 2) AS avg_tasks_solved,
    ROUND(AVG(tests_taken), 2) AS avg_tests_taken,
    ROUND(AVG(total_spent), 2) AS avg_spent,
    ROUND(SUM(total_spent), 2) AS total_spent_by_segment,
    ROUND(100.0 * COUNT(CASE WHEN total_spent > 0 THEN 1 END) / COUNT(*), 2) AS pct_paying_users
FROM user_segments
GROUP BY user_segment
ORDER BY 
    CASE user_segment
        WHEN 'Power User' THEN 1
        WHEN 'Active User' THEN 2
        WHEN 'Casual User' THEN 3
        WHEN 'Inactive User' THEN 4
    END;
```

**Выводы:**

Анализ сегментации пользователей показывает четкое разделение на группы:

1. **Power Users (5.91% пользователей)** - наиболее ценная группа:
   - В среднем активны 16 дней, решают 35 задач, проходят 3 теста
   - Средние траты: 229.66 кодкоинов на пользователя
   - 67% из них платят за контент
   - Генерируют 52% всех трат (37,665 из 75,170 кодкоинов)
   - **Рекомендация**: Это основная целевая аудитория для премиум-подписки. Готовы платить за качественный контент.

2. **Active Users (17.63% пользователей)** - стабильная группа:
   - В среднем активны 4 дня, решают 4 задачи, проходят 2 теста
   - Средние траты: 42.57 кодкоинов
   - 69% платят (самый высокий процент конверсии!)
   - **Рекомендация**: Хорошая целевая аудитория для месячной подписки. Высокая готовность платить.

3. **Casual Users (38.86% пользователей)** - самая большая группа:
   - В среднем активны 1.5 дня, решают менее 1 задачи
   - Средние траты: 13.61 кодкоинов
   - Только 44% платят
   - **Рекомендация**: Нужны стимулы для конверсии. Возможно, бесплатный пробный период подписки.

4. **Inactive Users (37.60% пользователей)** - неактивная группа:
   - Почти не используют платформу
   - Только 7% платят
   - **Рекомендация**: Фокус на удержание и онбординг, а не на монетизацию.

**Итог**: 23.54% пользователей (Power + Active) генерируют основную часть дохода и являются основной целевой аудиторией для подписки.

### Метрика 2: Время до первой покупки и конверсия в платящих пользователей

Мне кажется, что важно понять, как быстро пользователи начинают тратить деньги после регистрации и какой процент пользователей вообще когда-либо платил. Для этого я предлагаю посчитать время до первой покупки и конверсию в платящих, потому что:

- Это покажет оптимальный момент для предложения подписки - когда пользователь уже готов платить
- Поможет понять, нужно ли стимулировать первых покупок для увеличения конверсии
- Покажет разницу между пользователями, которые платят сразу, и теми, кто долго "присматривается"

Код для расчета:

```sql
WITH user_registration AS (
    SELECT 
        id AS user_id,
        date_joined
    FROM users
),
first_purchase AS (
    SELECT 
        t.user_id,
        MIN(t.created_at) AS first_purchase_date
    FROM transaction t
    WHERE t.user_id IS NOT NULL 
      AND t.type_id IN (1, 23, 24, 25, 26, 27, 28, 30)  -- только списания
    GROUP BY t.user_id
),
users_with_purchase_info AS (
    SELECT 
        ur.user_id,
        ur.date_joined,
        fp.first_purchase_date,
        CASE 
            WHEN fp.first_purchase_date IS NOT NULL THEN 
                EXTRACT(EPOCH FROM (fp.first_purchase_date - ur.date_joined)) / 86400.0
            ELSE NULL
        END AS days_to_first_purchase
    FROM user_registration ur
    LEFT JOIN first_purchase fp ON ur.user_id = fp.user_id
),
sorted_purchases AS (
    SELECT 
        days_to_first_purchase,
        ROW_NUMBER() OVER (ORDER BY days_to_first_purchase) AS rn,
        COUNT(*) OVER () AS cnt
    FROM users_with_purchase_info
    WHERE days_to_first_purchase IS NOT NULL
)
SELECT 
    (SELECT COUNT(*) FROM users_with_purchase_info) AS total_users,
    (SELECT COUNT(*) FROM users_with_purchase_info WHERE first_purchase_date IS NOT NULL) AS users_who_paid,
    ROUND(100.0 * (SELECT COUNT(*) FROM users_with_purchase_info WHERE first_purchase_date IS NOT NULL) / 
          (SELECT COUNT(*) FROM users_with_purchase_info), 2) AS conversion_to_paying_pct,
    (SELECT ROUND(AVG(days_to_first_purchase)::numeric, 2) FROM users_with_purchase_info WHERE days_to_first_purchase IS NOT NULL) AS avg_days_to_first_purchase,
    (SELECT ROUND(AVG(days_to_first_purchase)::numeric, 2) 
     FROM sorted_purchases 
     WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)) AS median_days_to_first_purchase,
    (SELECT ROUND(MIN(days_to_first_purchase)::numeric, 2) FROM users_with_purchase_info WHERE days_to_first_purchase IS NOT NULL) AS min_days_to_first_purchase,
    (SELECT ROUND(MAX(days_to_first_purchase)::numeric, 2) FROM users_with_purchase_info WHERE days_to_first_purchase IS NOT NULL) AS max_days_to_first_purchase,
    (SELECT COUNT(*) FROM users_with_purchase_info WHERE days_to_first_purchase <= 1) AS paid_within_1_day,
    (SELECT COUNT(*) FROM users_with_purchase_info WHERE days_to_first_purchase <= 7) AS paid_within_7_days,
    (SELECT COUNT(*) FROM users_with_purchase_info WHERE days_to_first_purchase <= 30) AS paid_within_30_days;
```

**Выводы:**

Анализ конверсии в платящих пользователей показывает важные паттерны:

1. **Общая конверсия**: 41.10% пользователей когда-либо платили за контент - это хороший показатель готовности платить.

2. **Скорость конверсии**:
   - **977 пользователей (86% платящих)** платят в первый же день после регистрации!
   - **1049 пользователей (92%)** платят в течение первой недели
   - **1094 пользователей (96%)** платят в течение первого месяца
   - Медианное время до первой покупки: **0 дней** (большинство платят сразу)

3. **Выводы**:
   - Пользователи готовы платить сразу после регистрации - это говорит о высоком доверии к платформе
   - Предложение подписки нужно делать **сразу при регистрации** или в первые дни использования
   - Бесплатный пробный период может быть не так эффективен, как скидка на первую подписку
   - **Рекомендация**: Предлагать подписку в онбординге, сразу после регистрации, с привлекательным предложением для новых пользователей

4. **Среднее время до покупки**: 3.75 дня, но это искажено небольшим количеством пользователей, которые платят позже. Большинство платят сразу.

### Метрика 3: Частота использования платформы (DAU/MAU ratio и паттерны активности)

Мне кажется, что важно понять, как часто пользователи возвращаются на платформу и какие у них паттерны активности. Для этого я предлагаю посчитать соотношение DAU/MAU и частоту использования, потому что:

- Это покажет, насколько "липким" является продукт - возвращаются ли пользователи регулярно
- Поможет определить оптимальные сроки подписки - если пользователи заходят каждый день, им подойдет месячная подписка, если раз в неделю - возможно, лучше годовая
- Покажет, есть ли сезонность или другие паттерны в использовании

Код для расчета:

```sql
WITH monthly_active_users AS (
    -- Пользователи, активные в каждом месяце
    SELECT 
        DATE_TRUNC('month', ue.entry_at) AS activity_month,
        COUNT(DISTINCT ue.user_id) AS mau
    FROM userentry ue
    GROUP BY DATE_TRUNC('month', ue.entry_at)
),
daily_active_users AS (
    -- Пользователи, активные в каждый день
    SELECT 
        DATE_TRUNC('month', ue.entry_at) AS activity_month,
        ue.entry_at::date AS activity_date,
        COUNT(DISTINCT ue.user_id) AS dau
    FROM userentry ue
    GROUP BY DATE_TRUNC('month', ue.entry_at), ue.entry_at::date
),
dau_mau_ratio AS (
    -- Соотношение DAU/MAU по месяцам
    SELECT 
        mau.activity_month,
        mau.mau,
        ROUND(AVG(dau.dau), 2) AS avg_dau,
        ROUND(100.0 * AVG(dau.dau) / mau.mau, 2) AS dau_mau_ratio_pct
    FROM monthly_active_users mau
    LEFT JOIN daily_active_users dau ON mau.activity_month = dau.activity_month
    GROUP BY mau.activity_month, mau.mau
),
user_frequency AS (
    -- Частота использования для каждого пользователя
    SELECT 
        ue.user_id,
        COUNT(DISTINCT ue.entry_at::date) AS total_active_days,
        MIN(ue.entry_at::date) AS first_activity,
        MAX(ue.entry_at::date) AS last_activity,
        (MAX(ue.entry_at::date) - MIN(ue.entry_at::date) + 1) AS days_between_first_last,
        CASE 
            WHEN (MAX(ue.entry_at::date) - MIN(ue.entry_at::date) + 1) > 0 
            THEN COUNT(DISTINCT ue.entry_at::date)::numeric / (MAX(ue.entry_at::date) - MIN(ue.entry_at::date) + 1)
            ELSE 0
        END AS activity_frequency
    FROM userentry ue
    GROUP BY ue.user_id
)
SELECT 
    'DAU/MAU Ratio by Month' AS metric_type,
    TO_CHAR(activity_month, 'YYYY-MM') AS period,
    mau,
    avg_dau,
    dau_mau_ratio_pct
FROM dau_mau_ratio
UNION ALL
SELECT 
    'User Activity Frequency' AS metric_type,
    'Overall' AS period,
    NULL AS mau,
    ROUND(AVG(total_active_days), 2) AS avg_dau,
    ROUND(AVG(activity_frequency) * 100, 2) AS dau_mau_ratio_pct
FROM user_frequency
WHERE days_between_first_last > 0
ORDER BY metric_type, period;
```

**Выводы:**

Анализ частоты использования показывает "липкость" продукта:

1. **DAU/MAU Ratio**: 
   - В среднем составляет 6-12% в зависимости от месяца
   - Это означает, что из всех пользователей, активных в месяце, только 6-12% активны каждый день
   - Для образовательной платформы это нормальный показатель (пользователи не заходят каждый день)

2. **Паттерны по месяцам**:
   - Наиболее активные месяцы: ноябрь-декабрь 2021, февраль-май 2022
   - DAU/MAU ratio растет со временем (с 6.4% в феврале до 11.7% в мае), что говорит об улучшении удержания

3. **Частота активности пользователей**:
   - Средняя частота активности: **77.26%** - это очень высокий показатель!
   - Это означает, что активные пользователи используют платформу в 77% дней между первым и последним визитом
   - Среднее количество активных дней: 2.90

4. **Выводы для подписки**:
   - Пользователи не заходят каждый день, но когда заходят - используют платформу интенсивно
   - **Месячная подписка** оптимальна, так как покрывает период активного использования
   - **Годовая подписка** с большой скидкой привлекательна для тех, кто планирует заниматься долгосрочно
   - Недельная подписка может быть слишком короткой для большинства пользователей

**Рекомендация**: Основной фокус на месячную подписку, годовая - как опция со скидкой для долгосрочных пользователей.



## Дополнительное задание 2: Анализ времени активности для определения оптимального времени релизов

### SQL-запрос для выгрузки данных

Для выгрузки данных об активностях пользователей используем следующий SQL-запрос:

```sql
WITH all_activities AS (
    -- Объединяем все активности: входы, запуски кода, отправки решений, начало тестов
    SELECT 
        ue.entry_at AS activity_time,
        'entry' AS activity_type
    FROM userentry ue
    
    UNION ALL
    
    SELECT 
        cr.created_at AS activity_time,
        'coderun' AS activity_type
    FROM coderun cr
    
    UNION ALL
    
    SELECT 
        cs.created_at AS activity_time,
        'codesubmit' AS activity_type
    FROM codesubmit cs
    
    UNION ALL
    
    SELECT 
        ts.created_at AS activity_time,
        'teststart' AS activity_type
    FROM teststart ts
)
SELECT 
    activity_time,
    activity_type,
    EXTRACT(DOW FROM activity_time) AS day_of_week,  -- 0=воскресенье, 6=суббота
    CASE EXTRACT(DOW FROM activity_time)
        WHEN 0 THEN 'Воскресенье'
        WHEN 1 THEN 'Понедельник'
        WHEN 2 THEN 'Вторник'
        WHEN 3 THEN 'Среда'
        WHEN 4 THEN 'Четверг'
        WHEN 5 THEN 'Пятница'
        WHEN 6 THEN 'Суббота'
    END AS day_name,
    EXTRACT(HOUR FROM activity_time) AS hour_of_day,
    activity_time::date AS activity_date
FROM all_activities
WHERE activity_time IS NOT NULL
ORDER BY activity_time;
```

### Python-код для анализа и визуализации

Для загрузки данных, построения графиков и анализа используем следующий код:

```python
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import numpy as np

# Настройка стиля графиков
plt.style.use('seaborn-v0_8-darkgrid')
sns.set_palette("husl")

# Загрузка данных из CSV файла
df = pd.read_csv('Query_results/activity_times.csv', parse_dates=['activity_time'])

# Преобразуем day_of_week в правильный формат (0=понедельник, 6=воскресенье)
# В PostgreSQL DOW: 0=воскресенье, поэтому преобразуем для удобства
df['day_of_week'] = df['activity_time'].dt.dayofweek  # 0=понедельник, 6=воскресенье
df['day_name'] = df['activity_time'].dt.day_name()
df['hour_of_day'] = df['activity_time'].dt.hour

# Создаем фигуру с несколькими графиками
fig, axes = plt.subplots(2, 2, figsize=(16, 12))
fig.suptitle('Анализ времени активности пользователей на платформе', fontsize=16, fontweight='bold')

# График 1: Распределение активности по дням недели
ax1 = axes[0, 0]
day_order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
day_counts = df['day_name'].value_counts().reindex(day_order)
day_counts.plot(kind='bar', ax=ax1, color='steelblue', edgecolor='black')
ax1.set_title('Активность по дням недели', fontsize=12, fontweight='bold')
ax1.set_xlabel('День недели', fontsize=10)
ax1.set_ylabel('Количество активностей', fontsize=10)
ax1.tick_params(axis='x', rotation=45)
ax1.grid(axis='y', alpha=0.3)

# Добавляем значения на столбцы
for i, v in enumerate(day_counts):
    if not pd.isna(v):
        ax1.text(i, v, f'{int(v):,}', ha='center', va='bottom', fontsize=9)

# График 2: Распределение активности по времени суток
ax2 = axes[0, 1]
hour_counts = df['hour_of_day'].value_counts().sort_index()
hour_counts.plot(kind='bar', ax=ax2, color='coral', edgecolor='black')
ax2.set_title('Активность по времени суток', fontsize=12, fontweight='bold')
ax2.set_xlabel('Час дня', fontsize=10)
ax2.set_ylabel('Количество активностей', fontsize=10)
ax2.tick_params(axis='x', rotation=0)
ax2.grid(axis='y', alpha=0.3)

# График 3: Тепловая карта активности (день недели × час дня)
ax3 = axes[1, 0]
heatmap_data = df.groupby(['day_name', 'hour_of_day']).size().unstack(fill_value=0)
heatmap_data = heatmap_data.reindex(day_order)
sns.heatmap(heatmap_data, ax=ax3, cmap='YlOrRd', annot=False, fmt='d', cbar_kws={'label': 'Количество активностей'})
ax3.set_title('Тепловая карта активности (День недели × Час дня)', fontsize=12, fontweight='bold')
ax3.set_xlabel('Час дня', fontsize=10)
ax3.set_ylabel('День недели', fontsize=10)

# График 4: Активность по типам действий по времени суток
ax4 = axes[1, 1]
activity_by_hour = df.groupby(['hour_of_day', 'activity_type']).size().unstack(fill_value=0)
activity_by_hour.plot(kind='line', ax=ax4, marker='o', linewidth=2, markersize=6)
ax4.set_title('Активность по типам действий по времени суток', fontsize=12, fontweight='bold')
ax4.set_xlabel('Час дня', fontsize=10)
ax4.set_ylabel('Количество активностей', fontsize=10)
ax4.legend(title='Тип активности', fontsize=9)
ax4.grid(alpha=0.3)

plt.tight_layout()
plt.savefig('activity_analysis.png', dpi=300, bbox_inches='tight')
print("График сохранен в файл activity_analysis.png")

# Выводим статистику
print("\n" + "="*60)
print("СТАТИСТИКА ПО ДНЯМ НЕДЕЛИ")
print("="*60)
day_stats = df['day_name'].value_counts().reindex(day_order)
for day, count in day_stats.items():
    pct = (count / len(df)) * 100
    print(f"{day:15s}: {count:8,} активностей ({pct:5.2f}%)")

print("\n" + "="*60)
print("СТАТИСТИКА ПО ВРЕМЕНИ СУТОК")
print("="*60)
hour_stats = df['hour_of_day'].value_counts().sort_index()
for hour, count in hour_stats.items():
    pct = (count / len(df)) * 100
    print(f"Час {hour:2d}:00-{hour+1:2d}:00: {count:8,} активностей ({pct:5.2f}%)")

# Находим наименее активные периоды
print("\n" + "="*60)
print("НАИМЕНЕЕ АКТИВНЫЕ ПЕРИОДЫ (оптимальное время для релизов)")
print("="*60)
min_day = day_stats.idxmin()
min_day_count = day_stats.min()
min_hour = hour_stats.idxmin()
min_hour_count = hour_stats.min()

print(f"\nСамый неактивный день: {min_day} ({min_day_count:,} активностей)")
print(f"Самый неактивный час: {min_hour}:00-{min_hour+1}:00 ({min_hour_count:,} активностей)")

# Находим наименее активные комбинации день+час
print("\n" + "="*60)
print("ТОП-5 НАИМЕНЕЕ АКТИВНЫХ ПЕРИОДОВ (день + час)")
print("="*60)
period_counts = df.groupby(['day_name', 'hour_of_day']).size().reset_index(name='count')
period_counts = period_counts.sort_values('count').head(5)
for idx, row in period_counts.iterrows():
    print(f"{row['day_name']:15s} {row['hour_of_day']:2d}:00 - {row['count']:6,} активностей")
```

**Выводы:**

Рекомендую проводить релизы в следующие периоды:

1. **По дням недели**: 
   - Наименее активные дни - оптимальное время для релизов, чтобы минимизировать влияние на пользователей
   - Обычно это выходные дни (суббота, воскресенье) или понедельник утром

2. **По времени суток**:
   - Наименее активные часы - раннее утро (2-6 часов) или поздний вечер (после 22:00)
   - Эти периоды оптимальны для технических релизов

3. **Рекомендации CTO**:
   - **Оптимальное время**: Выходные дни (суббота/воскресенье) в ранние утренние часы (2-6 утра)
   - **Альтернатива**: Понедельник утром (6-8 утра) - перед началом рабочей недели
   - Избегать: Будние дни в рабочее время (9-18 часов) - период максимальной активности
   - **Стратегия**: Планировать релизы на периоды с минимальной активностью, чтобы:
     - Минимизировать влияние на пользователей
     - Иметь время на откат в случае проблем
     - Не прерывать активное использование платформы

Конкретные рекомендации будут зависеть от результатов анализа данных, которые покажут точные периоды минимальной активности.

## Итоговые выводы по смене модели монетизации

На основе проведенного анализа данных, я считаю, что переход на модель подписки является правильным решением для IT Resume, потому что:

### 1. Структура тарифов

**Рекомендуемая структура:**

1. **Бесплатный тариф** (Free):
   - Доступ к большинству задач (базовый функционал)
   - Ограничение: 2-3 попытки на задачу
   - Ограниченный доступ к тестам (например, 1-2 теста в неделю)
   - Без доступа к решениям и подсказкам

2. **Недельная подписка** (Trial/Short-term):
   - Цена: 99-149 рублей
   - Целевая аудитория: Пользователи, которые хотят попробовать платформу
   - Включает: неограниченные попытки, доступ к решениям, 5-10 премиум-тестов

3. **Месячная подписка** (Основной тариф):
   - Цена: 299-499 рублей (ориентируясь на средние траты 27 кодкоинов/месяц и медианный баланс 56 кодкоинов)
   - Целевая аудитория: Active Users и Power Users (23.54% пользователей)
   - Включает: 
     - Неограниченные попытки на все задачи
     - Доступ ко всем тестам (самый популярный платный контент)
     - Доступ к решениям задач
     - Доступ к подсказкам
     - Приоритетная поддержка

4. **Годовая подписка** (Долгосрочная):
   - Цена: 2499-2999 рублей (скидка 30-40% от месячной)
   - Эквивалент: 208-250 рублей/месяц
   - Целевая аудитория: Power Users и долгосрочные пользователи (retention 30+ дней)
   - Дополнительные бонусы: эксклюзивные задачи от компаний, ранний доступ к новым функциям

### 2. Обоснование цен

- **Средние траты пользователей**: 27 кодкоинов/месяц (если 1 кодкоин = 1 рубль, то 27 руб/месяц)
- **Медианный баланс**: 56 кодкоинов - показывает, что большинство пользователей имеют небольшой баланс
- **Готовность платить**: 41% пользователей уже платят, 86% платящих делают это в первый день
- **Ценность для пользователей**: Power Users тратят в среднем 230 кодкоинов, что показывает готовность платить за качественный контент

**Вывод**: Месячная подписка в диапазоне 299-499 рублей является оптимальной, так как:
- Превышает текущие средние траты, но включает больше функционала
- Доступна для большинства пользователей (медианный баланс 56 кодкоинов)
- Привлекательна для 23.54% наиболее активных пользователей

### 3. Что включить в подписку

**На основе анализа покупок:**

1. **Обязательно включить:**
   - **Тесты** - самый популярный платный контент (676 пользователей покупали, 989 покупок)
   - **Решения задач** - 151 пользователь покупал, помогает в обучении
   - **Неограниченные попытки** - сейчас в среднем 3.17 попытки на задачу, это боль больших пользователей

2. **Опционально включить:**
   - **Подсказки** - менее популярны (53 пользователя), но могут быть полезны как дополнительная ценность

3. **Оставить бесплатным:**
   - **Большинство задач** - это основной способ привлечения пользователей
   - Ограничить попытки для бесплатных пользователей (2-3 попытки)

### 4. Стратегия внедрения

**Критические моменты:**

1. **Момент предложения подписки:**
   - **Сразу при регистрации** - 86% платящих пользователей платят в первый день
   - В онбординге с привлекательным предложением для новых пользователей
   - Не использовать бесплатный пробный период (неэффективно), лучше скидка на первую подписку

2. **Сегментация пользователей:**
   - **Power Users (5.91%)** - предлагать годовую подписку с максимальной скидкой
   - **Active Users (17.63%)** - основной фокус на месячную подписку
   - **Casual Users (38.86%)** - стимулировать конверсию через ограничения бесплатной версии

3. **Удержание:**
   - Retention падает резко после первого дня (с 80-90% до 27-65%)
   - Необходимо улучшить онбординг и удержание в первые дни
   - Предлагать подписку в момент, когда пользователь "застрял" на задаче (после 2-3 неудачных попыток)

### 5. Ожидаемые результаты

**Преимущества новой модели:**

- **Предсказуемый доход**: Подписки дают стабильный ежемесячный доход
- **Лучшая монетизация**: Текущая модель слишком щедрая (начисления 265 кодкоинов vs траты 27)
- **Упрощение**: Не нужно управлять валютой, пакетами кодкоинов
- **Маркетинг**: Легче делать акции и промо-кампании на подписки

**Риски и митигация:**

- **Потеря части пользователей**: Некоторые Casual Users могут уйти
  - *Митигация*: Оставить базовый функционал бесплатным, ограничения должны быть разумными
- **Снижение конверсии**: Переход с "микроплатежей" на подписку
  - *Митигация*: Предлагать недельную подписку как промежуточный вариант, агрессивное предложение при регистрации

### 6. Финальные рекомендации

**Приоритет 1 - Внедрить немедленно:**
- Месячная подписка (299-499 руб) с полным функционалом
- Годовая подписка (2499-2999 руб) со скидкой 30-40%
- Ограничения для бесплатной версии (2-3 попытки на задачу)

**Приоритет 2 - Внедрить в течение месяца:**
- Недельная подписка (99-149 руб) для новых пользователей
- Улучшение онбординга с предложением подписки
- A/B тестирование цен и предложений

**Приоритет 3 - Долгосрочная стратегия:**
- Сегментация пользователей и персонализированные предложения
- Программы лояльности для годовых подписчиков
- Эксклюзивный контент для премиум-подписчиков

**Итог**: Переход на модель подписки обоснован данными и должен принести более стабильный и предсказуемый доход, при этом сохранив доступность платформы для новых пользователей через бесплатный тариф с разумными ограничениями.


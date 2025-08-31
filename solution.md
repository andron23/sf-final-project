# Задание 1

```sql

-- Расчет rolling retention с разбивкой по когортам

WITH base AS (
    SELECT
        to_char(u.date_joined, 'YYYY-MM') AS yw,
        count(DISTINCT u.id) AS cohort_size
    FROM users u 
    GROUP BY yw
),
user_activity AS (
    SELECT
        u.id,
        to_char(u.date_joined, 'YYYY-MM') AS yw,
        extract(DAY FROM (ue.entry_at - u.date_joined)) AS days_diff
    FROM users u 
    JOIN userentry ue ON u.id = ue.user_id
    WHERE ue.entry_at >= u.date_joined
)
SELECT
    ua.yw,
    round((100.00 * count(DISTINCT CASE WHEN days_diff >= 0 THEN id ELSE NULL END) / b.cohort_size), 2) AS "day0",
    round((100.00 * count(DISTINCT CASE WHEN days_diff >= 1 THEN id ELSE NULL END) / b.cohort_size), 2) AS "day1",
    round((100.00 * count(DISTINCT CASE WHEN days_diff >= 3 THEN id ELSE NULL END) / b.cohort_size), 2) AS "day3",
    round((100.00 * count(DISTINCT CASE WHEN days_diff >= 7 THEN id ELSE NULL END) / b.cohort_size), 2) AS "day7",
    round((100.00 * count(DISTINCT CASE WHEN days_diff >= 14 THEN id ELSE NULL END) / b.cohort_size), 2) AS "day14",
    round((100.00 * count(DISTINCT CASE WHEN days_diff >= 30 THEN id ELSE NULL END) / b.cohort_size), 2) AS "day30",
    round((100.00 * count(DISTINCT CASE WHEN days_diff >= 60 THEN id ELSE NULL END) / b.cohort_size), 2) AS "day60",
    round((100.00 * count(DISTINCT CASE WHEN days_diff >= 90 THEN id ELSE NULL END) / b.cohort_size), 2) AS "day90"
FROM user_activity ua
JOIN base b ON ua.yw = b.yw 
GROUP BY ua.yw, b.cohort_size
ORDER BY ua.yw ASC ;
```

Выводы:

В результате запроса можно наблюдать достаточно низкую долю долгосрочно удерживаемых пользователей. Для большинства когорт отток составляет более 90% к 90-му дню.

# Задание 2

```sql

-- Расчет метрик относительно баланса пользователя

WITH user_balance_stats AS (
    SELECT
        user_id,
        sum(CASE WHEN type_id IN (1, 23, 24, 25, 26, 27, 28, 30) THEN value ELSE 0 END) AS total_debit,
        sum(CASE WHEN type_id NOT IN (1, 23, 24, 25, 26, 27, 28, 30) THEN value ELSE 0 END) AS total_credit,
        sum(value) AS current_balance
    FROM "transaction" t
    GROUP BY user_id
)
SELECT 
    count(DISTINCT user_id) AS total_users,
    round(avg(total_debit), 2) AS avg_coins_debited_per_user,
    round(avg(total_credit), 2) AS avg_coins_credited_per_user,
    round(avg(current_balance), 2) AS avg_user_balance,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY current_balance) AS median_user_balance
FROM user_balance_stats ubs ;
```

Выводы: 

Данные демонстрируют, что пользователи привыкли совершать достаточно дорогие покупки, списания гораздо более существенные, чем начисления, а поэтому можно предлагать достаточно высокий прайс для подписки.

# Задание 3

```sql

-- Расчет метрик активности пользователей на платформе

WITH
-- Общее количество пользователей
total_users AS (
    SELECT count(*) AS cnt FROM users
),
-- Пользователи, решавшие задачи
task_users AS (
    SELECT DISTINCT user_id FROM codesubmit
),
-- Пользователи, проходившие тесты
test_users AS (
    SELECT DISTINCT user_id FROM teststart
),
-- Активные пользователи (решали задачи или тесты)
active_users AS (
    SELECT DISTINCT user_id FROM task_users
    UNION
    SELECT DISTINCT user_id FROM test_users
),
-- Статистика по задачам
task_stats AS (
    SELECT
        user_id,
        count(DISTINCT problem_id) AS tasks_attempted,
        count(*) AS total_task_attempts
    FROM codesubmit
    GROUP BY user_id
),
-- Статистика по тестам
test_stats AS (
    SELECT
        user_id,
        count(DISTINCT test_id) AS tests_attempted,
        count(*) AS total_test_attempts
    FROM teststart
    GROUP BY user_id 
),
-- Статистика покупок за кодкоины
purchase_stats AS (
    SELECT
        count(DISTINCT CASE WHEN tt."type" = 23 THEN t.user_id END) AS users_bought_tasks,
        count(DISTINCT CASE WHEN tt."type" = 27 THEN t.user_id END) users_bought_tests,
        count(DISTINCT CASE WHEN tt."type" = 24 THEN t.user_id END) users_bought_hints,
        count(DISTINCT CASE WHEN tt."type" = 25 THEN t.user_id END) AS users_bought_solutions,
        count(CASE WHEN tt."type" = 23 THEN t.id END) AS tasks_bought,
        count(CASE WHEN tt."type" = 27 THEN t.id END) AS tests_bought,
        count(CASE WHEN tt."type" = 24 THEN t.id END) AS hints_bought,
        count(CASE WHEN tt."type" = 25 THEN t.id END) AS solutions_bought,
        count(DISTINCT CASE WHEN tt."type" IN (1, 23, 24, 25, 26, 27, 28, 30) THEN t.user_id END) AS users_purchased_anything,
        count(DISTINCT t.user_id) AS users_with_any_transaction
    FROM "transaction" t 
    JOIN transactiontype tt ON t.type_id = tt."type"
),
aggregated_stats AS (
    SELECT 
        count(DISTINCT tks.user_id) AS task_users_count,
        coalesce(avg(tks.tasks_attempted), 0) AS avg_tasks_per_user,
        coalesce(avg(tks.total_task_attempts), 0) AS avg_task_attempts_per_user,
        coalesce(avg(tks.total_task_attempts * 1.0 / NULLIF(tks.tasks_attempted, 0)), 0) AS avg_attempts_per_task,
        count(DISTINCT tts.user_id) AS test_users_count,
        coalesce(avg(tts.tests_attempted), 0) AS avg_tests_per_user,
        coalesce(avg(tts.total_test_attempts), 0) AS avg_test_attempts_per_user,
        coalesce(avg(tts.total_test_attempts * 1.0 / NULLIF(tts.tests_attempted, 0)), 0) AS avg_attempts_per_test
    FROM task_stats tks
    FULL OUTER JOIN test_stats tts ON tks.user_id = tts.user_id 
)
SELECT
    -- Метрики активности
    (SELECT count(*) FROM active_users au) AS active_users_count,
    round((SELECT count(*) FROM active_users) * 100.00 / nullif((SELECT cnt FROM total_users), 0), 2) AS active_users_percent,
    -- Средние показатели по задачам
    round(ags.avg_tasks_per_user, 2) AS avg_tasks_per_user,
    round(ags.avg_task_attempts_per_user, 2) AS avg_task_attempts_per_user,
    round(ags.avg_attempts_per_task, 2) AS avg_attempts_per_task,
    ags.task_users_count,
    -- Средние показатели по тестам
    round(ags.avg_tests_per_user, 2) AS avg_tests_per_user,
    round(ags.avg_test_attempts_per_user, 2) AS avg_test_attempts_per_user,
    round(ags.avg_attempts_per_test, 2) AS avg_attempts_per_test,
    ags.test_users_count,
    -- Статистика покупок
    ps.users_bought_tasks,
    ps.users_bought_tests,
    ps.users_bought_hints,
    ps.users_bought_solutions,
    ps.tasks_bought,
    ps.tests_bought,
    ps.hints_bought,
    ps.solutions_bought,
    ps.tasks_bought + ps.tests_bought + ps.hints_bought + ps.solutions_bought AS total_items_purchased,
    ps.users_purchased_anything,
    ps.users_with_any_transaction,
    round(ps.users_purchased_anything * 100.00 / NULLIF((SELECT cnt FROM total_users), 0), 2) AS percent_users_purchased_anything
FROM aggregated_stats ags
CROSS JOIN purchase_stats ps
CROSS JOIN total_users tu ;
```

Выводы:

Платформа демонстрирует высокую вовлеченность (62% активных пользователей) и исключительно успешную монетизацию (41% пользователей совершали покупки). Основной рост видится в стимулировании неактивных пользователей и повышении вовлеченности в тестах, которые проходят массово, но поверхностно.
Касаемо функционала подписки, имеет смысл разделить её на базовый и премиальный пакет. В базовом пакете можно предоставить неограниченный доступ к тестам и 1-2 сложным задачам, что покроет потребности большинства пользователей, которые активно покупают тесты, но мало их решают.
В премиум-подписку же можно ввести неограниченные подсказки и решения к задачам. Это позволит монетизировать потребности тех пользователей, которые точечно покупают данные опции, и увеличить средний чек покупки.

# Дополнительное задание

### Эффективность бесплатных монет / Free Coins Efficiency

Метрика позволяет понять, является ли раздача бесплатных монет целесообразным инструментом для мотивации пользователей к покупке контента на платформе.
Например, бесплатные монеты можно использовать в качестве ежемесячного бонуса для знакомства пользователя с премиум-контентом: начислить на аккаунт 50 монет, которых хватит на 1-2 платные задачи.
Понравилось, тогда покупай подписку для неограниченного доступа.
Если же модель не очень эффективна, можно оптимизировать количество бесплатных бонусов, начисляемых на аккаунт. В этой ситуации выгоднее раздавать маленькие бонусы, экономя при этом ресурсы платформы.

SQL-запрос для расчета:

```sql
WITH free_coins_events AS (
    SELECT
        t.user_id,
        t.created_at AS free_coins_date,
        t.value AS free_coins_amount
    FROM "transaction" t 
    WHERE t.type_id NOT IN (1, 23, 24, 25, 26, 27, 28, 30)
    AND t.value > 0
),
conversions_after_free_coins_granted AS (
    SELECT
        fce.user_id,
        fce.free_coins_date,
        fce.free_coins_amount,
        CASE WHEN EXISTS (
            SELECT 1 FROM "transaction" t 
            WHERE t.user_id = fce.user_id
            AND t.type_id IN (1, 23, 24, 25, 26, 27, 28, 30)
            AND t.value > 0
            AND t.created_at BETWEEN fce.free_coins_date AND fce.free_coins_date + INTERVAL '14 days'
        ) THEN 1 ELSE 0 END AS converted_in_14_days
    FROM free_coins_events fce
)
SELECT
    CASE 
        WHEN free_coins_amount <= 50 THEN 'Small Bonus (<=50)'
        WHEN free_coins_amount <= 100 THEN 'Medium Bonus (51-100)'
        ELSE 'Large Bonus (>100)'
    END AS bonus_size,
    count(DISTINCT user_id) AS total_users_got_bonus,
    sum(converted_in_14_days) AS converted_users,
    round(CAST(sum(converted_in_14_days) AS NUMERIC) / count(DISTINCT user_id) * 100, 2) AS concersion_rate
FROM conversions_after_free_coins_granted cafcg
GROUP BY CASE 
    WHEN free_coins_amount <= 50 THEN 'Small Bonus (<=50)'
    WHEN free_coins_amount <= 100 THEN 'Medium Bonus (51-100)'
    ELSE 'Large Bonus (>100)'
END ;
```

### Сезонность покупок / Purchase Seasonability

Метрика для анализа поведения клиента. Отображает, в какие дни, недели, месяцы и годы пользователи наиболее склонны к совершению покупок.
С точки зрения создания подписки на платформе важным будет как раз учесть, когда именно вводить сезонные промо-тарифы, планировать рекламные кампании и промо-акции, чтобы добиться наибольшего охвата, и на какие периоды закладывать наибольший бюджет.

SQL-запрос для расчета:

```sql
WITH daily_purchases AS (
	SELECT
		created_at::date AS purchase_date,
	    EXTRACT(MONTH FROM created_at) AS purchase_month,
	    count(DISTINCT id) AS transactions_count,
	    count(DISTINCT user_id) AS unique_buyers,
	    sum(value) AS total_revenue
	FROM "transaction"
	WHERE type_id IN (1, 23, 24, 25, 26, 27, 28, 30)
		AND value > 0
	GROUP BY created_at::date, EXTRACT(MONTH FROM created_at)
)
SELECT
	purchase_month,
	round(avg(transactions_count), 2) AS avg_daily_transactions,
	round(avg(unique_buyers), 2) AS avg_daily_buyers,
	round(avg(total_revenue), 2) AS avg_daily_revenue,
	sum(transactions_count) AS total_month_transactions,
	sum(total_revenue) AS total_month_revenue
FROM daily_purchases
GROUP BY purchase_month
ORDER BY purchase_month ASC ;
```
### Глубина погружения перед покупкой / Time to First Purchase

Данная метрика позволяет проанализировать, сколько времени и какое количество активностей нужно пользователю, чтобы созреть для первого платежа.
Она будет полезна для определения момента для предложения подписки. Так, если пользователи совершают покупку после решения десяти задач, то оптимальным вариантом будет предложить им оформить подписку после решения восьмой задачи, не навязывая продукт заранее.
Также данная метрика может помочь понять, какой оптимальный период для триала можно назначить.

SQL-запрос для расчета:

```sql
WITH first_purchases AS (
	SELECT
		t.user_id,
		min(t.created_at) AS first_purchase_date
	FROM "transaction" t
	WHERE t.type_id IN (1, 23, 24, 25, 26, 27, 28, 30)
	AND t.value > 0
	GROUP BY t.user_id
),
user_initial_activity AS (
	SELECT
		u.id AS user_id,
		u.date_joined,
		fp.first_purchase_date,
		-- Количество активностей до первой покупки
		count(DISTINCT cr.id) AS runs_before_purchase,
		count(DISTINCT cs.id) AS submits_before_purchase,
		count(DISTINCT ts.id) AS tests_started_before_purchase,
		-- Время до первой покупки
		EXTRACT(EPOCH FROM (fp.first_purchase_date - u.date_joined)) / 3600 AS time_to_purchase
	FROM users u 
	JOIN first_purchases fp ON u.id = fp.user_id
	LEFT JOIN coderun cr ON u.id = cr.user_id
		AND cr.created_at BETWEEN u.date_joined AND fp.first_purchase_date
	LEFT JOIN codesubmit cs ON u.id = cs.user_id
		AND cs.created_at BETWEEN u.date_joined AND fp.first_purchase_date
	LEFT JOIN teststart ts ON u.id = ts.user_id
		AND ts.created_at BETWEEN u.date_joined AND fp.first_purchase_date
	GROUP BY u.id, u.date_joined, fp.first_purchase_date
)
SELECT
	round(CAST(avg(time_to_purchase) AS NUMERIC), 2) AS avg_hours_to_first_purchase,
	round(CAST(avg(runs_before_purchase) AS NUMERIC), 2) AS avg_runs_before_purchase,
	round(CAST(avg(submits_before_purchase) AS NUMERIC), 2) AS avg_submits_before_purchase,
	round(CAST(avg(tests_started_before_purchase) AS NUMERIC), 2) AS avg_tests_started_before_purchase
FROM user_initial_activity ;
```

# Дополнительное задание 2

```sql

-- Активность пользователей
WITH combined_activity AS (
	SELECT
		user_id,
		created_at,
		'run' AS activity_type,
		EXTRACT(ISODOW FROM created_at) AS day_of_week,
		EXTRACT(HOUR FROM created_at) AS hour_of_day
	FROM coderun
	UNION ALL 
	SELECT
		user_id,
		created_at,
		'submit' AS activity_type,
		EXTRACT(ISODOW FROM created_at) AS day_of_week,
		EXTRACT(HOUR FROM created_at) AS hour_of_day
	FROM codesubmit
	UNION ALL 
	SELECT
		user_id,
		created_at,
		'test' AS activity_type,
		EXTRACT(ISODOW FROM created_at) AS day_of_week,
		EXTRACT(HOUR FROM created_at) AS hour_of_day
	FROM teststart
	UNION ALL 
	SELECT
		user_id,
		entry_at AS created_at,
		'login' AS activity_type,
		EXTRACT(ISODOW FROM entry_at) AS day_of_week,
		EXTRACT(HOUR FROM entry_at) AS hour_of_day
		FROM userentry
)
SELECT 
	date(created_at) AS activity_date,
	day_of_week,
	hour_of_day,
	activity_type,
	count(*) AS activity_count,
	count(DISTINCT user_id) AS unique_users,
	CASE
		day_of_week
		WHEN 1 THEN 'Понедельник'
		WHEN 2 THEN 'Вторник'
		WHEN 3 THEN 'Среда'
		WHEN 4 THEN 'Четверг'
		WHEN 5 THEN 'Пятница'
		WHEN 6 THEN 'Суббота'
		WHEN 7 THEN 'Воскресенье'
	END AS day_name,
	lpad(hour_of_day::text, 2, '0') || ':00' AS time_slot
FROM combined_activity
GROUP BY date(created_at), day_of_week, hour_of_day, activity_type
ORDER BY activity_date, hour_of_day ;
```

```python
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

data = pd.read_csv(r'C:\Users\marii\Downloads\activity_data.csv', delimiter=';', encoding='1251')

daily_activity = (
    data.groupby(['day_name', 'day_of_week'])
    .agg({'activity_count': 'sum'})
    .reset_index()
    .sort_values('day_of_week')
)
plt.figure(figsize=(12, 6))
sns.barplot(
    data=daily_activity,
    x='day_name',
    y='activity_count'
)
plt.title('Активность пользователей по дням недели')
plt.xlabel('День недели')
plt.ylabel('Количество активностей')
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()

hourly_activity = (
    data.groupby('hour_of_day')
    .agg({'activity_count': 'sum'})
    .reset_index()
    .sort_values('hour_of_day'))

plt.figure(figsize=(12, 6))
sns.lineplot(
    data=hourly_activity,
    x='hour_of_day',
    y='activity_count',
    marker='o')
plt.title('Активность пользователей по времени суток')
plt.xlabel('Час дня')
plt.ylabel('Количество активностей')
plt.xticks(range(0, 24, 2))
plt.grid(True, alpha=0.3)
plt.tight_layout()
plt.show()

heatmap_data = (
    data.groupby(['day_name', 'hour_of_day'])
    .agg({'activity_count': 'sum'})
    .reset_index()
)

day_order = [
    'Понедельник', 'Вторник', 'Среда',
    'Четверг', 'Пятница', 'Суббота', 'Воскресенье'
]

heatmap_data['day_name'] = pd.Categorical(
    heatmap_data['day_name'],
    categories=day_order,
    ordered=True
)

heatmap_data = heatmap_data.sort_values(['day_name', 'hour_of_day'])

heatmap_pivot = heatmap_data.pivot(
    index='day_name',
    columns='hour_of_day',
    values='activity_count'
)

plt.figure(figsize=(14, 8))
sns.heatmap(
    data=heatmap_pivot,
    cmap='YlOrRd',
    annot=False
)
plt.title('Тепловая карта активности: День недели × Время суток')
plt.xlabel('Час дня')
plt.ylabel('День недели')
plt.tight_layout()
plt.show()

quiet_periods = (
    data.groupby(['day_name', 'hour_of_day'])
    .agg({'activity_count': 'mean'})
    .reset_index()
    .nsmallest(5, 'activity_count')
)

print('Подходящие периоды для релизов (наименьшая активность среди пользователей)')
for idx, row in quiet_periods.iterrows():
    print(f'{row['day_name']}, {row['hour_of_day']:02d}:00 - {row['activity_count']:.0f} активностей')

busy_periods = (
    data.groupby(['day_name', 'hour_of_day'])
    .agg({'activity_count': 'mean'})
    .reset_index()
    .nlargest(5, 'activity_count')
)

print('Периоды высокой активности (релизов лучше избегать)')
for idx, row in busy_periods.iterrows():
    print(f'{row['day_name']}, {row['hour_of_day']:02d}:00 - {row['activity_count']:.0f} активностей')
```

Графики:

<img width="1190" height="590" alt="image" src="https://github.com/user-attachments/assets/f1f14df7-ab10-47ce-9a6e-2f36511de52a" />
<img width="1190" height="590" alt="image" src="https://github.com/user-attachments/assets/7f155ae2-17c9-40da-b95b-0c1d0f4b10c2" />
<img width="1271" height="790" alt="image" src="https://github.com/user-attachments/assets/bf7e9bec-5e4b-4bc6-be0b-33e612036d2a" />

Выводы:

Наиболее подходящими периодами для релизов являются ночные и ранние утренние часы, т.к. в это время активность пользователей на платформе снижена.
Однозначно следует выпускать обновления в будние дни с 10:00 до 14:00 и с 18:00 до 20:00, поскольку на эти часы приходится самый пик активности.
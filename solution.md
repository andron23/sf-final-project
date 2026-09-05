---ЗАДАНИЕ 1---
WITH cohort_sizes AS (
    SELECT 
        DATE_TRUNC('month', date_joined)::date AS cohort_month,
        COUNT(DISTINCT id) AS total_users
    FROM users
    GROUP BY DATE_TRUNC('month', date_joined)::date
),

user_activity_diff AS (
    SELECT 
        u.id AS user_id,
        DATE_TRUNC('month', u.date_joined)::date AS cohort_month,
        (ue.entry_at::date - u.date_joined::date) AS day_diff
    FROM users u
    JOIN userentry ue ON u.id = ue.user_id
)

SELECT 
    cs.cohort_month AS "Когорта",
    cs.total_users AS "Пользователей",
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 0 THEN rc.user_id END) / cs.total_users, 2) AS day0,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 1 THEN rc.user_id END) / cs.total_users, 2) AS day1,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 3 THEN rc.user_id END) / cs.total_users, 2) AS day3,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 7 THEN rc.user_id END) / cs.total_users, 2) AS day7,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 14 THEN rc.user_id END) / cs.total_users, 2) AS day14,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 30 THEN rc.user_id END) / cs.total_users, 2) AS day30,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 60 THEN rc.user_id END) / cs.total_users, 2) AS day60,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN rc.day_diff >= 90 THEN rc.user_id END) / cs.total_users, 2) AS day90
FROM cohort_sizes cs
LEFT JOIN user_activity_diff rc ON cs.cohort_month = rc.cohort_month
GROUP BY cs.cohort_month, cs.total_users
ORDER BY cs.cohort_month;

Когорта	Пользователи	day0	day1	day3	day7	day14	day30	day60	day90
01.03.2021	5	100	100	100	100	100	20	0	0
01.04.2021	15	60	60	46.67	33.33	33.33	0	0	0
01.05.2021	6	0	0	0	0	0	0	0	0
01.06.2021	6	0	0	0	0	0	0	0	0
01.07.2021	2	50	50	50	50	50	50	50	50
01.08.2021	1	100	100	100	100	100	100	100	100
01.09.2021	13	15.38	15.38	15.38	7.69	7.69	7.69	7.69	7.69
01.10.2021	8	0	0	0	0	0	0	0	0
01.11.2021	210	90	65.24	59.52	57.62	54.76	47.14	36.67	26.67
01.12.2021	132	91.67	50	40.15	38.64	33.33	28.79	21.21	12.12
01.01.2022	602	82.72	36.88	30.56	25.08	20.93	12.79	7.64	3.82
01.02.2022	1058	84.22	27.6	20.04	13.89	10.87	8.03	4.82	1.04
01.03.2022	479	86.64	30.06	22.76	16.08	12.53	7.31	1.04	0
01.04.2022	237	87.76	41.77	32.07	25.74	19.41	9.28	0	0


Выводы: у платформы резкий отток в первый месяц и стабилизация (плато) на долгосрочном периоде. 
   На основе этих данных и ваших условий сформирована стратегия монетизации:
1. Краткосрочная подписка на один месяц будет целесообразна. Между первым и 30 днем происходит самый масштабный отток 
   (например, в когорте 2021-12-01 удержание падает с 50% до 28.79%). Пользователи быстро загораются и остывают, 
   либо приходят решить конкретную задачу (подготовиться к собеседованию). Месячный тариф закроет потребность тех, «кому нужно здесь и сейчас». 
2. Подписка на 3 месяца возможна, так как  60–90 дней — это точка, где даже у мотивированных когорт (например, 2022-01-01) удержание опускается 
   до стабильного минимума (7.64% -> 3.82%). 3 месяца — стандартный цикл для прохождения комплексного курса или тщательной подготовки к смене работы.
3. Строимость подписки. 1 месяц (Базовый тариф): Должен быть относительно дорогим в пересчете на день, чтобы стимулировать покупку долгосрочных пакетов.
   3 месяца (Оптимальный): Скидка 15-20% от месячной стоимости при пересчете.
4. Состав подписки: Доступ к 70-80% стандартных задач (уровни Easy и Medium).Возможность отправлять решения без ограничений, но без расширенной аналитики тестов.
    В платную подписку (Premium) включаем: Просмотр эталонных решений: Код компилируется бесплатно, но посмотреть, как эту задачу решили авторы курса или ИИ-помощник — только по подписке.
    Подробный вывод тестов: Показ скрытых тест-кейсов (в каких входных данных упала программа). Это ценно, так как экономит часы отладки.
    Раздел «Собеседования и Кейсы».Задачи повышенной сложности (Hard): Премиальный каталог задач, которые чаще всего спрашивают на позициях Senior/Lead. 

---ЗАДАНИЕ 2---
WITH user_financials AS (
    SELECT 
        u.id AS user_id,
        COALESCE(SUM(CASE WHEN t.type_id NOT IN (1, 23, 24, 25, 26, 27, 28, 30) THEN t.value ELSE 0 END), 0) AS total_deposited,
        COALESCE(SUM(CASE WHEN t.type_id IN (1, 23, 24, 25, 26, 27, 28, 30) THEN ABS(t.value) ELSE 0 END), 0) AS total_withdrawn,
        COALESCE(SUM(CASE 
            WHEN t.type_id NOT IN (1, 23, 24, 25, 26, 27, 28, 30) THEN t.value 
            ELSE -ABS(t.value) 
        END), 0) AS current_balance
    FROM users u
    LEFT JOIN "transaction" t ON u.id = t.user_id
    GROUP BY u.id
)

SELECT 
    ROUND(AVG(CASE WHEN total_withdrawn > 0 THEN total_withdrawn END), 2) AS avg_coins_withdrawn_per_active_user,
    ROUND(AVG(total_withdrawn), 2) AS avg_coins_withdrawn_per_any_user,
    ROUND(AVG(total_deposited), 2) AS avg_coins_deposited_per_user,
    ROUND(AVG(current_balance), 2) AS avg_user_balance,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY current_balance) AS median_user_balance
FROM user_financials;

avg_coins_withdrawn_per_active_user	avg_coins_withdrawn_per_any_user	avg_coins_deposited_per_user	avg_user_balance	median_user_balance
75.78	                                27.1	                                265.41	                         238.31	                56

--Выводы:
1.В среднем пользователю начисляется 205.41 коинов, а списывает активный пользователь всего 75.41 коинов. 
   Система генерирует гораздо больше валюты, чем пользователи успевают или хотят тратить.
2. Средний баланс составляет 238.31 коинов, что даже превышает среднее начисление. На руках у пользователей скопился огромный нереализованный объем коинов.
3. Средний баланс (238.31) значительно выше медианного (56). Это классический признак того, что в системе есть небольшой процент пользователей («китов») с гигантскими балансами,
   в то время как у половины обычных пользователей на счету 56 коинов или меньше.
4. Разница между средним списанием по активным (75.41) и по вообще всем пользователям (27.1) показывает, что значительная часть зарегистрированных пользователей вообще ничего не тратит.

Эффективным будет переход на подписку:
- Переход от разовых покупок к ежемесячной оплате позволит стабильно планировать выручку.
- Вместо накопления коинов пользователи будут получать ценность в рамках расчетного периода (месяца), после чего неиспользованные лимиты могут сгорать.
- одписка психологически подталкивает пользователя заходить чаще («я же оплатил этот месяц, надо пользоваться»).
Оптимальный вариант — Гибридная модель (Paywall + Пакет коинов).Подписка дает полный безлимит на базовые действия + ежемесячный пакет из 100 коинов на премиум-функции.

---ЗАДАНИЕ 3---

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
    WHERE t.type_id IN (23, 24, 25, 27)
      AND t.user_id IS NOT NULL
),
all_metrics AS (
    SELECT 
        (SELECT ROUND(AVG(tasks_solved), 2) FROM task_metrics) AS avg_tasks_solved_per_user,
        (SELECT ROUND(AVG(tests_taken), 2) FROM test_metrics) AS avg_tests_taken_per_user,
        
        (SELECT ROUND(SUM(total_submits)::numeric / NULLIF(SUM(tasks_solved), 0), 2) FROM task_metrics) AS avg_attempts_per_task,
        (SELECT ROUND(SUM(total_test_attempts)::numeric / NULLIF(SUM(tests_taken), 0), 2) FROM test_metrics) AS avg_attempts_per_test,
        
        ROUND(100.0 * (SELECT COUNT(DISTINCT user_id) FROM users_who_were_active) / 
              (SELECT COUNT(*) FROM users), 2) AS pct_active_users,
              
        (SELECT COUNT(DISTINCT user_id) FROM purchase_stats WHERE purchase_type = 'task') AS users_opened_tasks,
        (SELECT COUNT(DISTINCT user_id) FROM purchase_stats WHERE purchase_type = 'test') AS users_opened_tests,
        (SELECT COUNT(DISTINCT user_id) FROM purchase_stats WHERE purchase_type = 'hint') AS users_opened_hints,
        (SELECT COUNT(DISTINCT user_id) FROM purchase_stats WHERE purchase_type = 'solution') AS users_opened_solutions,
        
        (SELECT COUNT(*) FROM purchase_stats) AS total_items_opened,
        
        (SELECT COUNT(DISTINCT user_id) FROM purchase_stats) AS users_bought_anything,
        
        (SELECT COUNT(DISTINCT user_id) FROM transaction WHERE user_id IS NOT NULL) AS users_with_any_transaction
)
SELECT * FROM all_metrics;

|avg_tasks_solved_per_user|avg_tests_taken_per_user|avg_attempts_per_task|avg_attempts_per_test|pct_active_users|users_opened_tasks|users_opened_tests|users_opened_hints|users_opened_solutions|total_items_opened|users_bought_anything|users_with_any_transaction|
|-------------------------|------------------------|---------------------|---------------------|----------------|------------------|------------------|------------------|----------------------|------------------|---------------------|--------------------------|
|9,52                     |1,68                    |2,9                  |1,26                 |61,97           |522               |676               |53                |151                   |3 205             |1 139                |2 402                     |


Выводы:
1. Почти 62% от всех зарегистрированных пользователей не просто «висят» в базе, а проявляют целевую активность (решают задачи или проходят тесты).
   В среднем активный пользователь доводит до успешного решения почти 10 задач.Тесты проходят значительно реже, чем решают задачи (в ~5.6 раз меньше).
   Низкое число попыток (1.26) указывает на то, что тесты воспринимаются пользователями как «финальная точка контроля» (прошёл один раз и пошёл дальше), либо база тестов на платформе сейчас слишком мала.
2. Задачи - это самый популярный платный контент среди изолированных сущностей. Пользователям важнее всего получать доступ к новым практическим кейсам.
   Несмотря на то, что в среднем тестов проходят меньше, уникальных покупателей у тестов больше всего. Это говорит о высокой коммерческой ценности тестовых материалов. Пользователи готовы платить за проверку своих знаний.
   Напрямую подсказки покупают крайне неохотно. Это логично: платить за разовое текстовое наведение на мысль психологически сложнее, чем за доступ к целой задаче или тесту.
   Продаются почти в 3 раза лучше подсказок. Если пользователь застрял, ему гораздо ценнее купить чистый рабочий код/ответ, чем просто намёк.
3.  Тариф "Базовый". Безлимитный или расширенный доступ к платным задачам, а также автоматический доступ к подсказкам.Задачи привлекают аудиторию. 
    Включение подсказок «бесплатно» внутрь подписки решит проблему их плохой продаваемости по отдельности. Пользователь будет активнее пользоваться подсказками, не испытывая микроплатежного барьера, что улучшит метрику
    Тариф «Продвинутый / Pro».Всё из базового тарифа + доступ к платным тестам (test) + доступ к разборам и готовым решениям (solution).Обоснование: Тесты имеют самый высокий спрос (675 покупателей), а готовые решения — высокую ценность для тех, кто ценит время.
    Объединение их в Pro-тариф позволит существенно поднять средний чек (ARPU). Пользователь платит за комплексный результат: "Попрактиковался -> Проверил себя тестом -> Посмотрел эталонное решение от авторов"

1. Доля «сгорающих» пользователей.
Процент пользователей, которые проявили целевую активность 
(решили хотя бы одну задачу или запустили тест), но ушли с платформы, так и не совершив ни одной платной транзакции.
Эта метрика покажет, насколько эффективно работает текущий бесплатный onboarding и бесплатный контент.

Код для расчета:

WITH active_users AS (
    SELECT user_id FROM codesubmit
    UNION
    SELECT user_id FROM teststart
),
paying_users AS (
    SELECT DISTINCT user_id 
    FROM "transaction" 
    WHERE type_id IN (23, 24, 25, 27) AND user_id IS NOT NULL
)
SELECT 
    COUNT(DISTINCT au.user_id) AS total_active_users,
    COUNT(DISTINCT pu.user_id) AS total_paying_users,
    ROUND(100.0 * (COUNT(DISTINCT au.user_id) - COUNT(DISTINCT pu.user_id)) / COUNT(DISTINCT au.user_id), 2) AS churn_before_purchase_pct
FROM active_users au
LEFT JOIN paying_users pu ON au.user_id = pu.user_id;

total_active_users	total_paying_users	churn_before_purchase_pct
1719	                 1052	                 38.8

ВЫВОДЫ:
1. Из 1719 пользователей, которые проявили целевую активность (решали задачи или проходили тесты), 
   61.2% сконвертировались в платящих (1052 пользователя). Это говорит о том, что ценность контента для пользователей очевидна.
2.  Почти 39% пользователей (667 человек) совершают целевые действия на платформе, но уходят, так и не потратив ни одного коина на платные фичи (подсказки, решения, тесты). 
    Скорее всего, им полностью хватает бесплатного лимита задач/возможностей, либо они не сталкиваются с достаточно сложными задачами.
3.  Поскольку конверсия в покупку коинов сейчас огромная (61.2%), пользователи привыкли получать ценность «внутри» платформы перед тем, как заплатить. 
    Если вы резко закроете всю платформу жесткой подпиской с первого дня, рискуете срезать этот поток активных пользователей.
4.  Чтобы монетизировать оставшихся 38,8%, в бесплатной версии нужно: Ограничить доступ к Medium/Hard задачам,Внедрить рекламу или ограничения по времени,
     Это подтолкнет сомневающихся к покупке подписки.


2. Коэффициент утилизации валюты.
Отношение потраченных коинов к начисленным за определенный период (или за все время) по каждому пользователю.
Из анализапервого задания виден колоссальный разрыв: средний баланс (238.31) практически равен среднему начислению (265.41). 
Это значит, что коины мертвым грузом лежат на аккаунтах. Метрика поможет сегментировать базу: какая доля пользователей активно «сжигает» коины,
а какая копит их безцельно.Для будущей модели подписки это покажет, какой ежемесячный лимит коинов будет оптимальным

Код для расчета:

WITH user_coin_stats AS (
    SELECT 
        user_id,
        COALESCE(SUM(CASE WHEN type_id NOT IN (1, 23, 24, 25, 26, 27, 28, 30) THEN value ELSE 0 END), 0) AS deposited,
        COALESCE(SUM(CASE WHEN type_id IN (1, 23, 24, 25, 26, 27, 28, 30) THEN ABS(value) ELSE 0 END), 0) AS withdrawn
    FROM "transaction"
    WHERE user_id IS NOT NULL
    GROUP BY user_id
)
SELECT 
    ROUND(100.0 * COUNT(CASE WHEN deposited > 0 AND (withdrawn::numeric / deposited) >= 0.7 THEN 1 END) / COUNT(*), 2) AS high_burn_users_pct,
    ROUND(100.0 * COUNT(CASE WHEN deposited > 0 AND (withdrawn::numeric / deposited) < 0.2 THEN 1 END) / COUNT(*), 2) AS hoarders_users_pct,
    ROUND(100.0 * SUM(withdrawn) / NULLIF(SUM(deposited), 0), 2) AS total_system_burn_rate_pct
FROM user_coin_stats;

high_burn_users_pct	hoarders_users_pct	total_system_burn_rate_pct
 5	                72.06	                10.21

ВЫВОДЫ:
1. Показатели 5% активных тратильщиков, 72.06% «копилок» и общий Burn Rate системы в 10.21% говорят о жестком системном кризисе монетизации через коины.
2. Результаты этой метрики —  обоснование для ликвидации чистой модели коинов и перехода на подписку. Внедрить жесткое сгорание лимитов.
   72% пользователей копят коины, потому что платформа слишком щедра на бесплатные начисления. Необходимо резко сократить или полностью убрать начисление коинов за простые действия.
   Те 5% пользователей, которые сейчас «сжигают» коины под ноль, — это идеальная целевая аудитория для вашего самого дорогого тарифа.
   Поскольку обычные пользователи (72%) привыкли тратить мало, базовый тариф подписки должен быть психологически доступным, но закрывать базовую потребность.


3.Индекс «застревания» на задачах.
Среднее количество неудачных попыток до момента, когда пользователь решает купить подсказку или готовое решение.
В среднем на задачу уходит 2.9 попыток, а подсказки покупают неохотно. Данная метрика покажет критическую точку «боли» пользователя. 
Например, если пользователь покупает решение только после 5-й неудачной попытки, значит, 5 попыток — это порог его терпения.

Код для расчета:

WITH first_help_purchase AS (
    SELECT 
        user_id,
        MIN(created_at) AS first_purchase_time  
    FROM "transaction"
    WHERE type_id IN (24, 25) AND user_id IS NOT NULL
    GROUP BY user_id
),
submits_before_purchase AS (
    SELECT 
        cs.user_id,
        COUNT(cs.id) AS attempts_count
    FROM codesubmit cs
    JOIN first_help_purchase fhp ON cs.user_id = fhp.user_id
    WHERE cs.created_at < fhp.first_purchase_time 
    GROUP BY cs.user_id
)
SELECT 
    ROUND(AVG(attempts_count), 2) AS avg_attempts_before_buying_help,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY attempts_count) AS median_attempts_before_buying_help
FROM submits_before_purchase;

avg_attempts_before_buying_help	  median_attempts_before_buying_help
19.23	                           10

ВЫВОДЫ:

1. Экстремальный уровень стресса и терпения (Медиана = 10, Среднее = 19.23). 
   Половина пользователей делает 10 и более неудачных попыток, прежде чем сдаться и нажать кнопку «Купить подсказку/решение».
2. На основе медианы, идеальная точка коммерческого контакта — это 4-я или 5-я неудачная попытка подряд.
3. «Базовый тариф» избавит пользователя от необходимости платить за каждую подсказку отдельно и уберет этот стресс.
4. В бесплатной версии можно ввести ограничение: например, не более 5 попыток на задачу в час.

Дополнительное задание 2.
--Для выгрузки данных используем SQL-запрос:

WITH user_activities AS (
    SELECT 
        id AS event_id,
        user_id,
        created_at AS activity_time, 
        'code_submit' AS activity_type
    FROM codesubmit
    
    UNION ALL
    SELECT 
        id AS event_id,
        user_id,
        created_at AS activity_time, 
        'test_start' AS activity_type
    FROM teststart
)
SELECT 
    activity_time,
    EXTRACT(ISODOW FROM activity_time) AS day_of_week,
    -- Название дня недели для удобства
    TO_CHAR(activity_time, 'Day') AS day_name,
    -- Экстракция часа суток (0-23)
    EXTRACT(HOUR FROM activity_time) AS activity_hour,
    activity_type
FROM user_activities
WHERE activity_time IS NOT NULL;

--Для загрузки данных, построения графиков и выводов используем Python:

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime

df = pd.read_csv('user_activity.csv', sep=None, engine='python')
df.rename(columns={df.columns[0]: 'activity_time'}, inplace=True)
df = df[df['activity_time'].astype(str).str.contains(r'\d', na=False)].copy()

df['activity_time'] = pd.to_datetime(df['activity_time'], errors='coerce')

# Удаляем пустые строки
df = df.dropna(subset=['activity_time'])

# Извлечение дня недели 
# ТЕПЕРЬ .dt ДЛЯ ДАТ СРАБОТАЕТ БЕЗ ОШИБОК
days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
df['weekday'] = df['activity_time'].dt.weekday  # 0-6
df['hour'] = df['activity_time'].dt.hour
df['weekday_name'] = df['weekday'].map(lambda x: days[x])

# Базовая статистика по дням недели
weekday_counts = df.groupby('weekday_name').size().reindex(days)
print("Количество активностей по дням недели:")
print(weekday_counts)

# Построение тепловой карты (день недели × час)
pivot = df.pivot_table(
    index='weekday_name',
    columns='hour',
    values='activity_time',
    aggfunc='count',
    fill_value=0
)
pivot = pivot.reindex(days)

# Визуализация: тепловая карта и общая активность по дням
fig, axes = plt.subplots(1, 2, figsize=(16, 6))

# Левый график: Тепловая карта
sns.heatmap(pivot, cmap='YlOrRd', annot=False, ax=axes[0], cbar_kws={'label': 'Количество активностей'})
axes[0].set_title('Тепловая карта активностей\n(день недели × час)', fontsize=12, fontweight='bold')
axes[0].set_xlabel('Час суток')
axes[0].set_ylabel('День недели')

# Правый график: Распределение по дням недели
weekday_counts.plot(kind='bar', ax=axes[1], color='skyblue', edgecolor='black')
axes[1].set_title('Активность по дням недели', fontsize=12, fontweight='bold')
axes[1].set_xlabel('День недели')
axes[1].set_ylabel('Количество активностей')
axes[1].set_xticklabels(days, rotation=0)

plt.tight_layout()
plt.savefig('activity_analysis.png', dpi=150)
plt.show()

# Дополнительно: гистограмма активности по часам суток
plt.figure(figsize=(12, 5))
hour_counts = df.groupby('hour').size()
hour_counts.plot(kind='bar', color='lightgreen', edgecolor='black')
plt.title('Активность по часам суток (все дни)', fontsize=12, fontweight='bold')
plt.xlabel('Час')
plt.ylabel('Количество активностей')
plt.xticks(range(0, 24))
plt.tight_layout()
plt.savefig('activity_by_hour.png', dpi=150)
plt.show()

# расчет периодов минимальной нагрузки
min_day = weekday_counts.idxmin()
min_day_count = weekday_counts.min()

min_hour = hour_counts.idxmin()
min_hour_count = hour_counts.min()

print(f"\nНаименьшая активность по дням недели: {min_day} ({min_day_count} событий)")
print(f"Наименьшая активность по часам: {min_hour}:00 ({min_hour_count} событий)")
print("\nРекомендуемое время для технического обслуживания/релиза: {} в {}:00".format(
    'ночь с воскресенья на понедельник' if min_day == 'Вс' else min_day,
    min_hour
))

ВЫВОДЫ:
1. Пиковая активность (Чаще всего): Вторник, Среда и Четверг. Пользователи максимально мотивированы, решают задачи в рамках учебы. 
   На эти 3 дня приходится основной объем трафика.Суббота — абсолютный минимум активности на платформе. Люди предпочитают отдыхать от компьютера. 
   В Пятницу вечер активность также резко падает. В Воскресенье начинается плавный подъем (пользователи «вспоминают» про долги по учебе перед новой неделей),
   но он все еще значительно ниже будних дней.
2. Пиковые часы (Больше всего): Дневной пик (11:00 — 14:00). Вечерний пик (18:00 — 21:00). Часы затишья (Меньше всего):Глубокая ночь и утро (02:00 — 05:00).
3. Релизы и технические работы (требуют кратковременного отключения серверов или могут вызвать баги) нельзя проводить в пиковые часы, чтобы не портить пользовательский опыт.
4. Идеальные окна для релизов: 
   - Ночь с субботы на воскресенье (с 03:00 до 05:00 утра).Суббота — день минимальной активности за всю неделю. К 3 часам ночи трафик падает и сбои затронут наименьшее число активных пользователей.  
   - Пятница (поздний вечер/ночь) (с 02:00 до 04:00 утра). Пятничный трафик быстро угасает к вечеру. Ночной релиз оставляет субботу на исправление критических багов до прихода новой волны пользователей. 

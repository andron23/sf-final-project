#### Задание 1
```sql
WITH cohort_users AS (
    -- 1. Определяем месяц регистрации (когорту) для каждого пользователя и размер когорт
    SELECT 
        id AS user_id,
        DATE_TRUNC('month', date_joined)::date AS cohort_month,
        COUNT(*) OVER(PARTITION BY DATE_TRUNC('month', date_joined)) AS cohort_size
    FROM users
),
user_max_activity AS (
    -- 2. Для каждого пользователя находим МАКСИМАЛЬНЫЙ интервал в днях между регистрацией и входом.
    -- Это ключевой шаг для Rolling Retention: если максимальный интервал >= N, 
    -- значит пользователь заходил в день N или позже.
    SELECT 
        cu.user_id,
        cu.cohort_month,
        cu.cohort_size,
        MAX(ue.entry_at::date - u.date_joined::date) AS max_days_passed
    FROM cohort_users cu
    JOIN users u ON cu.user_id = u.id
    -- Используем LEFT JOIN на случай, если кто-то зарегистрировался, но вообще не имеет записей в userentry
    LEFT JOIN userentry ue ON cu.user_id = ue.user_id
    GROUP BY cu.user_id, cu.cohort_month, cu.cohort_size
)
-- 3. Агрегируем данные по когортам и рассчитываем Rolling Retention в %
SELECT 
    cohort_month,
    -- День 0 — это всегда 100%, так как мы смотрим активность в день регистрации или позже
    100.00 AS "0",
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN max_days_passed >= 1 THEN user_id END) / cohort_size, 2) AS "1",
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN max_days_passed >= 3 THEN user_id END) / cohort_size, 2) AS "3",
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN max_days_passed >= 7 THEN user_id END) / cohort_size, 2) AS "7",
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN max_days_passed >= 14 THEN user_id END) / cohort_size, 2) AS "14",
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN max_days_passed >= 30 THEN user_id END) / cohort_size, 2) AS "30",
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN max_days_passed >= 60 THEN user_id END) / cohort_size, 2) AS "60",
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN max_days_passed >= 90 THEN user_id END) / cohort_size, 2) AS "90"
FROM user_max_activity
GROUP BY cohort_month, cohort_size
ORDER BY cohort_month;
```
Выводы: Анализ метрики Rolling Retention показывает классическую картину для образовательных IT-платформ. 
В первые 1–3 дня после регистрации наблюдается резкий отток пользователей (активная стадия кастдева и «первого знакомства» с интерфейсом).
Однако к 30-му и 60-му дням метрика стабилизируется на определенном плато — это ядро нашей лояльной аудитории,
которая регулярно возвращается решать задачи для долгосрочного саморазвития.
Рекомендации по тарифам подписки:
•	Недельная подписка (микро-тариф) нецелесообразна: Rolling Retention сильно падает уже к 7-му дню. 
Люди, покупающие такой тариф, скорее всего, закроют краткосрочную потребность (например, подготовка к конкретному собеседованию завтра) 
и больше не вернутся. Продавать её невыгодно из-за высоких затрат на привлечение.
•	Месячная и Годовая подписки — оптимальный выбор: Наличие стабильного плато удержания на 30-й и 90-й дни доказывает, 
что на платформе есть пользователи с долгосрочным циклом обучения. Годовой тариф с большой скидкой позволит зафиксировать прибыль
с «ядра» аудитории, а месячный тариф станет отличной точкой входа для сомневающихся.

#### Задание 2
```sql
WITH user_balances_raw AS (
    SELECT 
        user_id,
        SUM(CASE WHEN type_id NOT IN (1, 23, 24, 25, 26, 27, 28, 30) THEN value ELSE 0 END) AS total_earned,
        SUM(CASE WHEN type_id IN (1, 23, 24, 25, 26, 27, 28, 30) THEN ABS(value) ELSE 0 END) AS total_spent,
        SUM(CASE WHEN type_id IN (1, 23, 24, 25, 26, 27, 28, 30) THEN -ABS(value) ELSE ABS(value) END) AS current_balance
    FROM transaction
    GROUP BY user_id
),
all_users_financials AS (
    SELECT 
        u.id AS user_id,
        COALESCE(b.total_earned, 0) AS total_earned,
        COALESCE(b.total_spent, 0) AS total_spent,
        COALESCE(b.current_balance, 0) AS current_balance
    FROM users u
    LEFT JOIN user_balances_raw b ON u.id = b.user_id
),
ordered_balances AS (
    SELECT 
        current_balance,
        ROW_NUMBER() OVER (ORDER BY current_balance) AS row_num,
        COUNT(*) OVER () AS total_count
    FROM all_users_financials
)
SELECT
    (SELECT ROUND(AVG(total_earned) FILTER (WHERE total_earned > 0), 2) FROM all_users_financials) AS avg_coins_earned_per_user,
    (SELECT ROUND(AVG(total_spent) FILTER (WHERE total_spent > 0), 2) FROM all_users_financials) AS avg_coins_spent_per_user,
    (SELECT ROUND(AVG(current_balance), 2) FROM all_users_financials) AS average_balance,
    ROUND(AVG(current_balance), 2) AS median_balance
FROM ordered_balances
WHERE row_num IN ((total_count + 1) / 2, (total_count + 2) / 2);
```
Выводы:
•	Дисбаланс экономики коинов: Средний баланс пользователей (238.31) значительно превышает медианный (56).
Это подтверждает, что на платформе есть небольшой сегмент пользователей («киты») с огромными неизрасходованными запасами монет,
в то время как у большинства балансы минимальны.
•	Низкая оборачиваемость валюты: В среднем пользователь зарабатывает за всё время 306.52 коинов, а тратит всего 75.78.
Пользователи копят монеты и неохотно расстаются с ними, что тормозит повторные продажи пакетов валюты. 
Переход на подписку решит эту проблему, обеспечив стабильный ежемесячный доход (MRR) независимо от накоплений.
#### Задание 3
```sql
SELECT
    a.avg_problems_per_user,
    a.avg_tests_per_user,
    a.avg_submits_per_problem,
    a.avg_starts_per_test,
    a.active_users_share_percent,
    p.users_opened_tasks_for_coins,
    p.users_opened_tests_for_coins,
    p.users_opened_hints_for_coins,
    p.users_opened_solutions_for_coins,
    p.total_items_opened_for_coins,
    p.users_bought_at_least_something,
    p.users_with_at_least_one_transaction
FROM (
    -- Блок 1. Вычисляем среднюю активность по пользователям, задачам и тестам
    SELECT
        ROUND(AVG(t.unique_solved_problems), 2) AS avg_problems_per_user,
        ROUND(AVG(tst.unique_passed_tests), 2) AS avg_tests_per_user,
        ROUND(SUM(t.total_task_submits)::numeric / NULLIF(SUM(t.unique_solved_problems), 0), 2) AS avg_submits_per_problem,
        ROUND(SUM(tst.total_test_starts)::numeric / NULLIF(SUM(tst.unique_passed_tests), 0), 2) AS avg_starts_per_test,
        ROUND(100.0 * COUNT(DISTINCT COALESCE(t.user_id, tst.user_id)) / COUNT(DISTINCT u.id), 2) AS active_users_share_percent
    FROM users u
    LEFT JOIN (
        SELECT 
            user_id,
            COUNT(DISTINCT problem_id) AS unique_solved_problems,
            COUNT(*) AS total_task_submits
        FROM codesubmit
        GROUP BY user_id
    ) t ON u.id = t.user_id
    LEFT JOIN (
        SELECT 
            user_id,
            COUNT(DISTINCT test_id) AS unique_passed_tests,
            COUNT(*) AS total_test_starts
        FROM teststart
        GROUP BY user_id
    ) tst ON u.id = tst.user_id
) a
CROSS JOIN (
    -- Блок 2. Вычисляем точную агрегированную статистику покупок за коины
    SELECT
        COUNT(DISTINCT CASE WHEN type_id = 23 THEN user_id END) AS users_opened_tasks_for_coins,
        COUNT(DISTINCT CASE WHEN type_id = 27 THEN user_id END) AS users_opened_tests_for_coins,
        COUNT(DISTINCT CASE WHEN type_id = 24 THEN user_id END) AS users_opened_hints_for_coins,
        COUNT(DISTINCT CASE WHEN type_id = 25 THEN user_id END) AS users_opened_solutions_for_coins,
        COUNT(CASE WHEN type_id IN (1, 23, 24, 25, 26, 27, 28, 30) THEN 1 END) AS total_items_opened_for_coins,
        COUNT(DISTINCT CASE WHEN type_id IN (23, 24, 25, 27) THEN user_id END) AS users_bought_at_least_something,
        COUNT(DISTINCT user_id) AS users_with_at_least_one_transaction
    FROM transaction
) p;
```
Выводы:
1.	Высокая базовая вовлеченность: Доля активных пользователей составляет 61.97%, что является отличным показателем
2.	 для образовательной платформы. Пользователи не просто регистрируются, а реально переходят к контенту.
3.	Сложность контента: На одну задачу пользователь в среднем делает почти 3 попытки (2.90). Это говорит о том,
4.	 что задачи имеют оптимальный уровень сложности (не решаются с первого раза), что создаёт потенциал для продажи подсказок и решений.
5.	Поведение при покупках за коины: Пользователи чаще тратят коины на открытие полноценных тестов (676)
6.	 и задач (522), чем на микро-контент внутри задач (всего 53 покупки подсказок и 151 покупка решений).
7.	 Это показывает, что пользователи видят больше ценности в доступе к крупным единицам контента.
Рекомендации по наполнению пакетов подписки:
•	Подсказки и решения задач слабо монетизируются отдельно, так как пользователи неохотно тратят на них валюту поэлементно.
 Их нужно упаковать в единый Premium-пакет. Безлимитный доступ к подсказкам и готовым разборам внутри подписки
уберёт психологический барьер «поштучной оплаты» и резко повысит её ценность для студентов.

#### Дополнительное задание

Для детальной оценки текущей токеномики и обоснования перехода на подписочную модель я предлагаю внедрить три новые продуктовые метрики. Выбор обусловлен тремя ключевыми причинами:
1. **Необходимость оценки реального коммерческого потенциала базы:** Нам важно знать не просто число регистраций, а долю людей, готовых платить за контент (*Conversion to Buyer*).
2. **Определение финансовой емкости одного пользователя:** Нужно понять, сколько коинов готов утилизировать вовлеченный студент (*Average Spent per Buyer*), чтобы правильно рассчитать стоимость будущих тарифных планов подписки.
3. **Выявление скрытых инфраструктурных убытков платформы:** Требуется измерить объем «зависшего виртуального долга» сервиса перед пользователями (*Dead Coins Share*), который блокирует повторные продажи.

Код для расчета:
```sql
SELECT
    ROUND(100.0 * p.buyers_count / u.total_users, 2) AS conversion_to_buyer_percent,
    ROUND(p.total_spent::numeric / NULLIF(p.buyers_count, 0), 2) AS avg_spent_per_buyer,
    ROUND(100.0 * (p.total_earned - p.total_spent) / NULLIF(p.total_earned, 0), 2) AS dead_coins_share_percent
FROM (
    SELECT COUNT(*) AS total_users FROM users
) u
CROSS JOIN (
    SELECT
        COUNT(DISTINCT CASE WHEN type_id IN (23, 24, 25, 27) THEN user_id END) AS buyers_count,
        SUM(CASE WHEN type_id NOT IN (1, 23, 24, 25, 26, 27, 28, 30) THEN value ELSE 0 END) AS total_earned,
        SUM(CASE WHEN type_id IN (1, 23, 24, 25, 26, 27, 28, 30) THEN ABS(value) ELSE 0 END) AS total_spent
    FROM transaction
) p;
```
Выводы:
* **Conversion to Buyer:** **41.06%** зарегистрированных пользователей совершают хотя бы одну покупку за коины.
*  Это подтверждает хорошую базовую вовлеченность аудитории.
* **Average Spent per Buyer:** **66.00** коинов в среднем тратит один платящий пользователь на открытие закрытых материалов.
* **Dead Coins Share (Доля зависшей валюты):** **89.79%** — критический показатель.
* Почти 90% всех начисленных коинов лежат мёртвым грузом на балансах.
* Текущая экономика коинов неэффективна, так как платформа раздает слишком много бесплатной валюты
* за сопутствующие действия (входы, регистрации), которую пользователи просто складируют.
*  Изъятие коинов и замена их на классическую подписку позволит сжечь неиспользуемые
*  балансы и превратит этот виртуальный баланс в предсказуемый регулярный денежный поток (MRR).


#### Дополнительное задание 2

Для оптимизации технической инфраструктуры и выбора безопасного релизного окна был выполнен SQL-запрос к таблице входов (`userentry`). Группировка произведена по дням недели (где 0 — воскресенье, 1 — понедельник, ..., 6 — суббота).

Для выгрузки данных используем SQL-запрос:
```sql
SELECT 
    EXTRACT(DOW FROM entry_at) AS day_of_week,
    COUNT(*) AS total_visits
FROM userentry
GROUP BY EXTRACT(DOW FROM entry_at)
ORDER BY day_of_week;
```

## Результат выполнения в СУБД:
* **Понедельник** (day_of_week = 1): **1 193** визита
* **Вторник** (day_of_week = 2): **1 252** визита
* **Среда** (day_of_week = 3): **1 205** визитов
* **Четверг** (day_of_week = 4): **1 278** визитов *(Пик активности)*
* **Пятница** (day_of_week = 5): **1 216** визитов
* **Суббота** (day_of_week = 6): **900** визитов *(Минимум нагрузки)*
* **Воскресенье** (day_of_week = 0): **951** визит

Выводы:
1. Рекомендую проводить релизы и технические работы в Субботу**, потому что в этот день зафиксирован абсолютный минимум пользовательской активности на платформе за всю неделю (всего **900 визитов**).
Нагрузка падает почти на 30% по сравнению с пиковыми днями, что делает этот день самым безопасным для инфраструктуры.
3. Рекомендую выбирать время для деплоя и миграций в ночь с пятницы на субботу (с 01:00 до 05:00)**,
потому что это позволяет провести все потенциально опасные работы в момент минимального присутствия людей на сайте.
Даже если возникнет непредвиденный сбой (Downtime), у технической команды будет целый день субботы на исправление ошибок до наступления рабочих будней.
3. Рекомендую запускать маркетинговые триггеры и рассылки в Четверг в первой половине дня**, потому что этот день является абсолютным пиком активности пользователей на платформе (**1 278 визитов**). В этот период вовлеченность аудитории максимальна, и пуш-уведомления получат наибольший отклик.

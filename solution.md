**Задание 1**
```sql
WITH cohort_users AS (
  select
	  u.id AS user_id,--уникальный индефикатор пользователя
	  DATE(u.date_joined) AS reg_date,-- дата регистрации
	  TO_CHAR(u.date_joined, 'YYYY-MM') AS cohort_month -- месяц регистрации
  FROM users u
),
user_activity AS (
  SELECT DISTINCT--получаю все даты активности пользователей без дубликатов
	  ue.user_id,
	  DATE(ue.entry_at) AS activity_date
  FROM userentry ue
),
daily_retention AS (
  SELECT--соединяю когорты с активностью и вычисляю разницу в днях
	  c.cohort_month,
	  c.user_id,
	  a.activity_date,
	  (a.activity_date - c.reg_date) AS day_diff
  FROM cohort_users c
  LEFT JOIN user_activity a ON c.user_id = a.user_id
),
cohort_size AS (
  SELECT--считаю общее число пользователей в каждой когорте
    cohort_month,
    COUNT(DISTINCT user_id) AS total_users
  FROM cohort_users
  GROUP BY cohort_month
),
retention_calc AS (
  SELECT--для каждого фиксированного дня
    dr.cohort_month,
    COUNT(DISTINCT CASE WHEN dr.day_diff >= 0 THEN dr.user_id END) AS day0,
    COUNT(DISTINCT CASE WHEN dr.day_diff >= 1 THEN dr.user_id END) AS day1,
    COUNT(DISTINCT CASE WHEN dr.day_diff >= 3 THEN dr.user_id END) AS day3,
    COUNT(DISTINCT CASE WHEN dr.day_diff >= 7 THEN dr.user_id END) AS day7,
    COUNT(DISTINCT CASE WHEN dr.day_diff >= 14 THEN dr.user_id END) AS day14,
    COUNT(DISTINCT CASE WHEN dr.day_diff >= 30 THEN dr.user_id END) AS day30,
    COUNT(DISTINCT CASE WHEN dr.day_diff >= 60 THEN dr.user_id END) AS day60,
    COUNT(DISTINCT CASE WHEN dr.day_diff >= 90 THEN dr.user_id END) AS day90
  FROM daily_retention dr
  GROUP BY dr.cohort_month
)
SELECT--перевожу в проценты и округляю
  rc.cohort_month,
  ROUND(100.0 * rc.day0 / cs.total_users, 2) AS day0,
  ROUND(100.0 * rc.day1 / cs.total_users, 2) AS day1,
  ROUND(100.0 * rc.day3 / cs.total_users, 2) AS day3,
  ROUND(100.0 * rc.day7 / cs.total_users, 2) AS day7,
  ROUND(100.0 * rc.day14 / cs.total_users, 2) AS day14,
  ROUND(100.0 * rc.day30 / cs.total_users, 2) AS day30,
  ROUND(100.0 * rc.day60 / cs.total_users, 2) AS day60,
  ROUND(100.0 * rc.day90 / cs.total_users, 2) AS day90
FROM retention_calc rc
JOIN cohort_size cs ON rc.cohort_month = cs.cohort_month
ORDER BY rc.cohort_month;
```
**Выводы:**
1.Высокий retention в первые дни (day0-day7) наблюдается у всех когорт. Это говорит о том, что пользователи активно пробуют платформу сразу после регистрации.
2.Сильное падение к 30-90 дням. Большинство когорт теряют 70-90% пользователей уже к 30 дню

**Задание 2**

```sql
WITH user_totals AS (
  SELECT
    u.id,
    COALESCE(SUM(CASE WHEN tt.type IN (1,23,24,25,26,27,28,30) THEN t.value ELSE 0 END), 0) AS total_debit,--списания
    COALESCE(SUM(CASE WHEN tt.type NOT IN (1,23,24,25,26,27,28,30) THEN t.value ELSE 0 END), 0) AS total_credit--начисления
  FROM users u
  LEFT JOIN transaction t ON u.id = t.user_id
  LEFT JOIN transactiontype tt ON t.type_id = tt.type--связываю с типом транзакции
  GROUP BY u.id
)
SELECT--финальный расчет по всем пользователям
  ROUND(AVG(total_debit), 2) AS avg_debit_per_user,
  ROUND(AVG(total_credit), 2) AS avg_credit_per_user,
  ROUND(AVG(total_credit - total_debit), 2) AS avg_balance,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY (total_credit - total_debit)) AS median_balance
FROM user_totals;
```
**Выводы:**
1. Средний баланс значительно выше медианного. Это говорит о сильном перекосе распределения: небольшая группа пользователей имеет крупные остатки,
    тогда как у большинства пользователей баланс скромный.
2. Средние начисления намного превышают средние списания. Это подтверждает главную проблему текущей модели монетизации.
3. Соотношение списаний к начислениям составляет примерно 1:12,5. То есть на каждую потраченную монету пользователь получает более 12 монет бесплатно.
   Это означает, что внутренняя валюта не выполняет свою функцию средства обмена-
   ее слишком легко заработать и слишком сложно потратить.

**Задание 3**

```sql
with -- задание 3 часть 1 решенные задачи и попытки
  task_stats AS (
    SELECT
      user_id,
      COUNT(DISTINCT CASE WHEN is_false = 0 THEN problem_id END) AS solved_tasks,
      COUNT(*) AS total_attempts
    FROM codesubmit
    GROUP BY user_id
),
test_stats AS (
  SELECT--уникальные тесты и общее число попыток
    user_id,
    COUNT(DISTINCT test_id) AS started_tests,
    COUNT(*) AS total_test_attempts
  FROM teststart
  GROUP BY user_id
),
active_users AS (
  SELECT user_id FROM task_stats--активные пользователи
  UNION
  SELECT user_id FROM test_stats
)
SELECT--финальные показатели
-- 1. Среднее решённых задач (только решавшие)
  (SELECT ROUND(AVG(solved_tasks), 2) FROM task_stats WHERE solved_tasks > 0) AS avg_solved_tasks,
-- 2. Среднее начатых тестов (только начинавшие)
  (SELECT ROUND(AVG(started_tests), 2) FROM test_stats WHERE started_tests > 0) AS avg_tests_started,
-- 3. Среднее попыток на задачу (только решавшие)
  (SELECT ROUND(AVG(total_attempts * 1.0 / solved_tasks), 2) FROM task_stats WHERE solved_tasks > 0) AS avg_attempts_per_solved_task,
-- 4. Среднее попыток на тест (только начинавшие)
  (SELECT ROUND(AVG(total_test_attempts * 1.0 / started_tests), 2) FROM test_stats WHERE started_tests > 0) AS avg_attempts_per_test,
-- 5. Доля активных от всех пользователей
  (SELECT ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM users), 2) FROM active_users) AS pct_active_users;
```
```sql
WITH purchases AS (
  select -- задание 3 часть 2 метрики покупок
    t.user_id,
    tt.type AS operation_type,
    COUNT(*) AS purchase_cnt
  FROM transaction t
  JOIN transactiontype tt ON t.type_id = tt.type--связь по типу транзакции
  WHERE tt.type IN (1,23,24,25,26,27,28,30) -- все списания
  GROUP BY t.user_id, tt.type
)
SELECT
-- 1. Сколько человек открывало задачи (type = 23)
  COUNT(DISTINCT CASE WHEN operation_type = 23 THEN user_id END) AS users_opened_tasks,
-- 2. Сколько человек открывало тесты (type = 24)
  COUNT(DISTINCT CASE WHEN operation_type = 24 THEN user_id END) AS users_opened_tests,
-- 3. Сколько человек открывало подсказки (type = 25)
  COUNT(DISTINCT CASE WHEN operation_type = 25 THEN user_id END) AS users_opened_hints,
-- 4. Сколько человек открывало решения (type = 26)
  COUNT(DISTINCT CASE WHEN operation_type = 26 THEN user_id END) AS users_opened_solutions,
-- 5. Сколько всего фактов открытий (сумма покупок по этим типам)
  COALESCE(SUM(CASE WHEN operation_type IN (23,24,25,26) THEN purchase_cnt ELSE 0 END), 0) AS total_openings,
-- 6. Сколько человек купило хотя бы что-то из перечисленного (23-26)
  COUNT(DISTINCT CASE WHEN operation_type IN (23,24,25,26) THEN user_id END) AS users_bought_anything,
-- 7. Сколько человек имеют хотя бы одну транзакцию (любую, включая начисления)
  (SELECT COUNT(DISTINCT user_id) FROM transaction) AS users_with_any_transaction
FROM purchases;
```
**Выводы:**
1. Задачи- основной вид контента. Пользователи активно их решают, но делают много попыток.
Внедрение платных подсказок или решений может быть востребовано и приносить доход.
2. Тесты менее популярны, но проходятся легко - их можно оставить бесплатными.
3. Высокая доля активных  пользователей - хорошая база для монетизации через подписку.
4. Важно, что решения не покупал никто, возможно они бесплатные или очень дорогие.
5. Задачи покупают чаще всего.Но при этом видно что только каждый 5-й что-то покупает.
6. Подсказки купили 151 человек - значительно меньше, чем задачи.
   Возможно, они плохо заметны в интерфейсе, либо пользователи предпочитают тратить попытки, а не монеты.
7. Тесты за монеты открывают редко. Возможно их мало или они не представляют ценности.
8. Всего факторов открытий - 2216. В среднем на одного покупателя приходится около 3,7 покупки.
   Это говорит о том, что те, кто начинает покупать, делают это неоднократно.
   Но основная масса пользователей имеет только начисления и никогда не тратят.

**Дополнительное задание**
Мне кажется важно понять, как быстро пользователи начинают тратить монеты и какой процент доходит до первой покупки, 
также без понимания того, сколько реально приносит один пользователь сейчас, невозможно обоснованно назначиить цену подписки,
а также нужно точно знать, какие именно материалы пользователи готовы покупать.
Для этого я предлагаю посчитать конверсию из регистрации в покупку, средний доход на пользователя, сравнение популярности платных материалов, потому что:

причина 1: Оценка эффективности вовлечения, прогнозирование дохода при переходе на подписку
причина 2: средний доход на пользователя полезна для определения базового значения для цены подписки
причина 3: сравнение популярности платных материалов полезна для оптимизации наполнения подписки, ценового позиционирования, анализа неиспользуемого потенциала

Код для расчета:
```sql
SELECT --доп метрика 1 задание 3 средний баланс пользователей, которые что-либо купили
    ROUND(AVG(balance), 2) AS avg_balance_of_buyers
FROM (
    SELECT 
        u.id,
        COALESCE(SUM(CASE WHEN tt.type IN (1,23,24,25,26,27,28,30) THEN t.value ELSE 0 END), 0) AS debit,
        COALESCE(SUM(CASE WHEN tt.type NOT IN (1,23,24,25,26,27,28,30) THEN t.value ELSE 0 END), 0) AS credit,
        COALESCE(SUM(CASE WHEN tt.type NOT IN (1,23,24,25,26,27,28,30) THEN t.value ELSE 0 END), 0) 
        - COALESCE(SUM(CASE WHEN tt.type IN (1,23,24,25,26,27,28,30) THEN t.value ELSE 0 END), 0) AS balance
    FROM users u
    LEFT JOIN transaction t ON u.id = t.user_id
    LEFT JOIN transactiontype tt ON t.type_id = tt.type
    GROUP BY u.id
) AS balances
WHERE debit > 0;
```
```sql
WITH user_solved AS (
    SELECT -- метрика 2 распределение пользователей по числу решенных задач
--видно что большинство решают мало задач - для них подписка может быть невыгодна, если она дорогая.
        user_id,
        COUNT(DISTINCT problem_id) AS solved_count
    FROM codesubmit
    WHERE is_false = 0   -- 0 = верное решение
    GROUP BY user_id
)
SELECT 
    CASE 
        WHEN solved_count = 0 THEN '0'
        WHEN solved_count BETWEEN 1 AND 5 THEN '1-5'
        WHEN solved_count BETWEEN 6 AND 20 THEN '6-20'
        WHEN solved_count BETWEEN 21 AND 50 THEN '21-50'
        ELSE '50+'
    END AS tasks_range,
    COUNT(*) AS users
FROM user_solved
GROUP BY tasks_range
ORDER BY MIN(solved_count);
```
```sql
WITH active_users AS (
    SELECT DISTINCT user_id FROM codesubmit--метрика 3 процент активных пользователей, которые хотя бы раз купили материал
    UNION
    SELECT DISTINCT user_id FROM teststart
),
buyers AS (
    SELECT DISTINCT t.user_id
    FROM transaction t
    JOIN transactiontype tt ON t.type_id = tt.type
    WHERE tt.type IN (23,24,25,26)   -- коды покупки задач/тестов/подсказок/решений
)
SELECT 
    ROUND(100.0 * (SELECT COUNT(*) FROM buyers) / NULLIF((SELECT COUNT(*) 
FROM active_users), 0), 2) AS conversion_active_to_buyer;
```
**Выводы:**
Приложенные  три метрики показывают, что большинство пользователей решают мало задач, конверсия активных покупателей 35% невысокая, значит, многие не видят смысла тратить монеты. Огромный средний баланс 431 на фоне низкой медианы говорит о сильном расслоении. Переход на подписку выровняет доход и сделает его более предсказуемым.

**Итоговые выводы по смене модели монетизации**
Я считаю, что вам нужно внедритьподписку с пробным периодом,
потому что текущая модель не позволяет масштабировать доход, не стимулирует регулярные траты, 
ключевые проблемы, подтвердились цифрами - это низкая конверсия в покупку, огромный разрыв между средним и медианным балансом, пользователи не покупают решения и мало покупают тесты, Rolling retention показывает, что уже к 30 дню остается лишь 7-20% пользователей. 
А подписка позволит монетизировать активных пользователей, которые сейчас ничего не покупают, улучшит удержание за счет психологии "я плачу, значит надо использовать"
А еще, беря во внимание, что все таки по полученным данным пользователи не активны в покупке решений и тестов, нужно сделать двухуровневую подписку(бесплатный тариф + месячная\годовая):
Бесплатная подписка включает в себя
-решение неограниченного числа базовых задач(без решений и подсказок)
-прохождение базовых тестов(без расширенных)
-Ежедневное начисление небольшого количества монет(для поддержания геймификации)
Месячная подписка включает в себя
-неограниченный доступ ко всем решениям(сейчас их не покупают - делаем бесплатными для подписчиков)
-неограниченные подсказки (позволят снизить число попыток)
-доступ к премиум-задачам и расширенным тестам
-снятие лимита на количество задач/тестов в день ( если он есть)
Годовая подписка включает все тоже самое, что месячная, но дешевле в расчете за месяц.

**Дополнительное задание 2**

Для выгрузки данных используем SQL-запрос:
```sql
SELECT 'code_submit' AS event_type, user_id, created_at FROM codesubmit
UNION ALL
SELECT 'test_start', user_id, created_at FROM teststart order by created_at;
```
Для загрузки данных, построения графика, столбцов по дням и тепловой карты, используем такой код:
```python
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime

# ------------------------------
# 1. Загрузка данных
# ------------------------------

df = pd.read_csv('C:/Users/mzayn/_SELECT_code_submit_AS_event_type_user_id_created_at_FROM_codesu_202605201610.csv', parse_dates=['created_at'])

# Посмотрим на первые строки для проверки
print(df.head())
print(f"Всего записей: {len(df)}")

# ------------------------------
# 2. Извлечение признаков времени
# ------------------------------
# Часы от 0 до 23
df['hour'] = df['created_at'].dt.hour
# День недели: 0 = понедельник, 6 = воскресенье
df['weekday'] = df['created_at'].dt.dayofweek
# Названия дней для подписей на графиках
weekday_names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']

# ------------------------------
# 3. Построение графиков
# ------------------------------
# Устанавливаем стиль seaborn для более приятного вида
sns.set_style('whitegrid')
plt.rcParams['figure.figsize'] = (12, 6)

# ----- График 1: Распределение активности по часам суток -----
plt.figure()
# Гистограмма с ядерной оценкой плотности (kde)
sns.histplot(df['hour'], bins=24, kde=True, color='skyblue', edgecolor='black')
plt.title('Активность пользователей по часам суток (все события)', fontsize=14)
plt.xlabel('Час (0–23)', fontsize=12)
plt.ylabel('Количество событий', fontsize=12)
plt.xticks(range(0, 24, 2)) # подписи через каждые 2 часа
plt.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig('activity_by_hour.png', dpi=150)
plt.show()

# ----- График 2: Активность по дням недели (столбчатая диаграмма) -----
plt.figure()
# Подсчитываем количество событий по дням недели и строим столбцы в правильном порядке
order = range(7)
sns.countplot(x='weekday', data=df, order=order, palette='viridis', edgecolor='black')
plt.title('Активность пользователей по дням недели', fontsize=14)
plt.xlabel('День недели', fontsize=12)
plt.ylabel('Количество событий', fontsize=12)
plt.xticks(ticks=order, labels=weekday_names)
plt.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig('activity_by_weekday.png', dpi=150)
plt.show()

# ----- График 3: Тепловая карта (день недели × час) -----
plt.figure(figsize=(14, 7))
# Строим сводную таблицу: строки - дни недели, столбцы - часы
pivot = pd.crosstab(df['weekday'], df['hour'])
sns.heatmap(pivot, cmap='YlOrRd', annot=False, cbar_kws={'label': 'Число событий'})
plt.title('Тепловая карта активности: день недели vs час', fontsize=14)
plt.xlabel('Час суток', fontsize=12)
plt.ylabel('День недели', fontsize=12)
# Подписываем строки названиями дней
plt.yticks(ticks=range(7), labels=weekday_names, rotation=0)
plt.tight_layout()
plt.savefig('heatmap_activity.png', dpi=150)
plt.show()

# ------------------------------
# 4. Дополнительная аналитика для выводов
# ------------------------------
# Находим час с максимальной активностью
peak_hour = df['hour'].mode()[0]
# День с максимальной активностью
peak_weekday = df['weekday'].mode()[0]
# Час с минимальной активностью
low_hour = df['hour'].value_counts().idxmin()
# День с минимальной активностью
low_weekday = df['weekday'].value_counts().idxmin()

print(f"\n=== Статистика ===")
print(f"Пик активности: {weekday_names[peak_weekday]}, {peak_hour}:00")
print(f"Минимум активности: {weekday_names[low_weekday]}, {low_hour}:00")
print(f"Среднее число событий в час: {df['hour'].value_counts().mean():.1f}")
print(f"Среднее число событий в день недели: {df['weekday'].value_counts().mean():.1f}")
```
**Выводы:** Рекомендую проводить релизы в субботу  в 2:00, потому что наблюдается абсолютный минимум активности, резервное окно можно использовать в воскресенье с 3:00 до 5:00 - низкая активность. Категорически не рекомендую использовать время проведения релизов вторник-четверг с 10:00 до 17:00 - высокая активность.

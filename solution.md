#### Задание 1

```sql
with activity_counts as (
	select
		to_char(u.date_joined, 'YYYY-MM') as yw,
		count(distinct case when ue.entry_at >= date(u.date_joined) then ue.user_id end) as day0_count,
		count(distinct case when ue.entry_at >= date(u.date_joined) + interval '1 DAY' then ue.user_id end) as day1_count,
		count(distinct case when ue.entry_at >= date(u.date_joined) + interval '3 DAY' then ue.user_id end) as day3_count,
		count(distinct case when ue.entry_at >= date(u.date_joined) + interval '7 DAY' then ue.user_id end) as day7_count,
		count(distinct case when ue.entry_at >= date(u.date_joined) + interval '14 DAY' then ue.user_id end) as day14_count,
		count(distinct case when ue.entry_at >= date(u.date_joined) + interval '30 DAY' then ue.user_id end) as day30_count,
		count(distinct case when ue.entry_at >= date(u.date_joined) + interval '60 DAY' then ue.user_id end) as day60_count,
		count(distinct case when ue.entry_at >= date(u.date_joined) + interval '90 DAY' then ue.user_id end) as day90_count
	from userentry ue
	join users u on ue.user_id = u.id
	where u.date_joined >= date('2022-01-01')
	group by to_char(u.date_joined, 'YYYY-MM')
)
select
	yw,
	case when day0_count > 0 then 100.00 else 0.00 end as day0,
	round((day1_count  ::numeric / nullif(day0_count, 0)) * 100, 2) as day1,
	round((day3_count  ::numeric / nullif(day0_count, 0)) * 100, 2) as day3,
	round((day7_count  ::numeric / nullif(day0_count, 0)) * 100, 2) as day7,
	round((day14_count ::numeric / nullif(day0_count, 0)) * 100, 2) as day14,
	round((day30_count ::numeric / nullif(day0_count, 0)) * 100, 2) as day30,
	round((day60_count ::numeric / nullif(day0_count, 0)) * 100, 2) as day60,
	round((day90_count ::numeric / nullif(day0_count, 0)) * 100, 2) as day90
from activity_counts
order by yw;
```

Выводы: В зависимости от когорты, на седьмой день количество посетителей снижается до 30% - 16% от числа зарегистрированных. На 30 день количество посетителей снижается в зависимости от кагорты до 15% - 8%. На 60 день число посетителей не превышает 10%, а в одной из кагорт достигает 0. Оптимальнымм будут тарифы с небольшим сроком (неделя).


#### Задание 2

```sql
with user_balances as (
	select 
		t.user_id,
		sum(case when tt.type in (1, 23, 24, 25, 26, 27, 28, 30) then t.value else 0 end) as total_spent,	
		sum(case when tt.type not in (1, 23, 24, 25, 26, 27, 28, 30) then t.value else 0 end) as total_earned,		
		sum(case 
			when tt.type in (1, 23, 24, 25, 26, 27, 28, 30) then -t.value 
			else t.value 
		end) as current_balance
	from transaction t
	join transactiontype tt on t.type_id = tt.type
	group by t.user_id
)
select
	round(avg(case when total_spent > 0 then total_spent else null end), 2) as avg_coins_spent,
	round(avg(total_earned), 2) as avg_coins_earned,
	round(avg(current_balance), 2) as avg_user_balance,
	mode() within group (order by current_balance) as median_user_balance
from user_balances;
```

Выводы: В среднем один пользователь списывает 75,78 коинов. Одному пользователю в среднем начисляется 306,52 коина. Средний баланс одного пользователя составляет 275,22 коина. Медианный баланс пользователя - 53 коина.


#### Задание 3

```sql
with total_users_count as (
	select count(distinct id) as all_users from users
),
-- Активность по задачам: считаем уникальные задачи и общее число попыток на юзера
user_problems as (
	select 
		user_id,
		-- Сколько уникальных задач юзер пытался решать (из coderun + codesubmit)
		count(distinct problem_id) as unique_problems_solved,
		-- Общее число всех его попыток (запуски + отправки кода)
		sum(attempts) as total_problem_attempts
	from (
		select user_id, problem_id, count(*) as attempts from coderun group by user_id, problem_id
		union all
		select user_id, problem_id, count(*) as attempts from codesubmit group by user_id, problem_id
	) sub
	group by user_id
),
user_tests as (
	select 
		user_id,
		count(distinct test_id) as unique_tests_passed,
		count(*) as total_test_attempts
	from teststart
	group by user_id
),
-- Расчет средних метрик активности
activity_metrics as (
	select
		-- Сколько в среднем пользователь решает задач (только среди тех, кто их решал)
		round(avg(p.unique_problems_solved), 2) as avg_problems_solved,
		-- Сколько в среднем пользователь проходит тестов (только среди тех, кто проходил)
		round(avg(t.unique_tests_passed), 2) as avg_tests_passed,
		-- Сколько в среднем пользователь делает попыток для решения 1 задачи
		round(sum(p.total_problem_attempts)::numeric / nullif(sum(p.unique_problems_solved), 0), 2) as avg_attempts_per_problem,
		-- Сколько в среднем пользователь делает попыток для прохождения 1 теста
		round(sum(t.total_test_attempts)::numeric / nullif(sum(t.unique_tests_passed), 0), 2) as avg_attempts_per_test,
		-- Доля пользователей, решавших хотя бы 1 задачу или начавших хотя бы 1 тест от общего числа пользователей
		round((count(distinct coalesce(p.user_id, t.user_id))::numeric / nullif((select all_users from total_users_count), 0)) * 100, 2) as active_users_share_pct
	from user_problems p
	full join user_tests t on p.user_id = t.user_id
),
-- Статистика по покупкам за кодкоины и транзакциям
purchase_metrics as (
	select
		-- Сколько человек открывало за кодкоины разные материалы
		count(distinct case when tt.type in (1, 23, 24, 25, 26, 27, 28, 30) and lower(tt.description) like '%задач%' then t.user_id end) as users_bought_tasks,
		count(distinct case when tt.type in (1, 23, 24, 25, 26, 27, 28, 30) and lower(tt.description) like '%тест%' then t.user_id end) as users_bought_tests,
		count(distinct case when tt.type in (1, 23, 24, 25, 26, 27, 28, 30) and lower(tt.description) like '%подсказ%' then t.user_id end) as users_bought_hints,
		count(distinct case when tt.type in (1, 23, 24, 25, 26, 27, 28, 30) and lower(tt.description) like '%решен%' then t.user_id end) as users_bought_solutions,
		-- Сколько подсказок/тестов/задач/решений БЫЛО ОТКРЫТО за кодкоины (всего фактов открытия)
		count(case when tt.type in (1, 23, 24, 25, 26, 27, 28, 30) then t.id end) as total_materials_bought,
		-- Сколько человек покупало хотя бы что-то из вышеперечисленного
		count(distinct case when tt.type in (1, 23, 24, 25, 26, 27, 28, 30) then t.user_id end) as users_with_any_purchase,
		-- Сколько человек всего имеют хотя бы 1 транзакцию (включая начисления)
		count(distinct t.user_id) as users_with_any_transaction
	from transaction t
	join transactiontype tt on t.type_id = tt.type
)
-- Финальный вывод всех полученных чисел в 1 строку
select 
	am.avg_problems_solved,
	am.avg_tests_passed,
	am.avg_attempts_per_problem,
	am.avg_attempts_per_test,
	am.active_users_share_pct as "active_users_share, %",
	pm.users_bought_tasks,
	pm.users_bought_tests,
	pm.users_bought_hints,
	pm.users_bought_solutions,
	pm.total_materials_bought,
	pm.users_with_any_purchase,
	pm.users_with_any_transaction
from activity_metrics am
cross join purchase_metrics pm;
```

Выводы: 
* Сколько в среднем пользователь решает задач - 9,18
* Сколько в среднем пользователь проходит тестов - 1,68
* Сколько в среднем пользователь делает попыток для решения 1 задачи - 9,35
* Сколько в среднем пользователь делает попыток для прохождения 1 теста - 1,26

* Какая доля от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест - 63,48%

* Сколько человек открывало задачи за кодкоины - 604
* Сколько человек открывало тесты за кодкоины - 676
* Сколько человек открывало подсказки за кодкоины - 53
* Сколько человек открывало решения за кодкоины - 151
* Сколько подсказок/тестов/задач/решений было открыто за кодкоины (если задача/... открыта разными людьми, то это считаем разными фактами открытия) - 3210
* Сколько человек покупало хотя бы что-то из вышеперечисленного - 1140
* Сколько человек всего имеют хотя бы 1 транзакцию, пусть даже только начисление -2402


#### Дополнительное задание

Мне кажется, следует понимать, какая доля от всех пользователей, совершивших хотя бы одно учебное действие (решение задачи или тест), в итоге купила хотя бы один платный материал за кодкоины. Для этого я предлагаю посчитать корверсию в первую покупку.

Это может быть полезно, т.к. метрика показывает, насколько эффективно работает внутренняя экономика. Если активных пользователей много, а конверсия в покупку низкая — значит, цены слишком высокие, кодкоинов не хватает (или их некуда тратить), либо бесплатного контента и так достаточно, и у юзеров нет мотивации платить.

Код для расчета:

```sql
with active_study_users as (
	select user_id from coderun
	union
	select user_id from codesubmit
	union
	select user_id from teststart
),
paying_users as (
	select distinct t.user_id
	from transaction t
	join transactiontype tt on t.type_id = tt.type
	where tt.type in (1, 23, 24, 25, 26, 27, 28, 30)
)
select 
	count(a.user_id) as total_active_studying,
	count(p.user_id) as total_paying,
	round((count(p.user_id)::numeric / nullif(count(a.user_id), 0)) * 100, 2) as "conversion_to_payment, %"
from active_study_users a
left join paying_users p on a.user_id = p.user_id;
```

Выводы: Рассчитанная конверсия составила 60,7%, показатель достатоточно высокий. Пользователи готовы покупать.


Еще может быть полезным рассчитать среднее количество неудачных попыток (is_false = true) в таблице codesubmit, которое делает пользователь перед тем, как окончательно забросить задачу или всё-таки решить её. Метрику можно назвать Индекс "упрямства.

Это может быть полезным, пскольку, это метрика "токсичности" контента или UX. Если индекс упрямства слишком высокий (например, люди делают по 15 неудачных попыток на задачу), это сигнал для контент-продюсеров: задачи либо слишком сложные, либо условия описаны непонятно. Это провоцирует выгорание пользователей и отток с платформы.

Код для расчета:

```sql
with false_attempts_per_problem as (
	select 
		user_id,
		problem_id,
		count(*) as false_count
	from codesubmit
	where is_false = 1 
	group by user_id, problem_id
)
select 
	round(avg(false_count), 2) as avg_failed_attempts_per_problem
from false_attempts_per_problem;
```

Вывод: рассчитанный индекс составил 3,22 неудачные попытки в среднем по паре пользователь-задача. Что на мой взгляд достаточно низкий показатель.


Кроме того, может оказаться полезным посчитать соотношение открытых подсказок к открытым готовым решениям задач (hints_bought / solutions_bought).

Метрика подсвечивает паттерны поведения студентов. Если показатель > 1 (подсказки покупают чаще): пользователи пытаются думать самостоятельно, им нужен лишь намек. Это здоровая, вовлеченная аудитория. Если показатель < 1 (решения покупают чаще): пользователи не хотят думать и просто «гуглят» ответы за кодкоины, чтобы быстрее проскочить тему. Это повод задуматься над геймификацией или ограничением на покупку ответов без прошлых попыток.

Код для расчета:

```sql
with purchases as (
	select
		count(case when lower(tt.description) like '%подсказ%' then t.id end) as hints_count,
		count(case when lower(tt.description) like '%решен%' then t.id end) as solutions_count
	from transaction t
	join transactiontype tt on t.type_id = tt.type
	where tt.type in (1, 23, 24, 25, 26, 27, 28, 30)
)
select 
	hints_count as total_hints_opened,
	solutions_count as total_solutions_opened,
	round(hints_count::numeric / nullif(solutions_count, 0), 2) as hint_to_solution_ratio
from purchases;
```

Вывод: составил 0,28, что свидетельствует о том, что решения покупают гораздо чаще (почти в 4 раза), чем подсказки.


#### Итоговые выводы по смене модели монетизации

Я считаю, рассчитанные метрики показывают достаточно высокую конверсию среди активрных пользователей к покупкам. В частности, для уменьшения разрыва между покупаками готовых решений и подсказок, можно сделать платными именно решения, а подсказки сделать условно бесплатными. Что должно дополнительно стимулировать пользователей дойти до решения "своей головой".


#### Дополнительное задание 2

Решил разбить задачу на два SQL-запроса.

1. Распределение активности по дням недели

Этот запрос покажет, в какие дни недели пользователи платформы наиболее и наименее активны. Дни отсортированы от самых разгруженных к самым пиковым.

```sql
with all_actions as (
	select created_at from coderun
	union all
	select created_at from codesubmit
	union all
	select created_at from teststart
)
select 
	extract(isodow from created_at) as day_of_week_num,	
	case extract(isodow from created_at)
		when 1 then '1. Понедельник'
		when 2 then '2. Вторник'
		when 3 then '3. Среда'
		when 4 then '4. Четверг'
		when 5 then '5. Пятница'
		when 6 then '6. Суббота'
		when 7 then '7. Воскресенье'
	end as day_of_week,
	count(*) as total_actions,	
	round((count(*)::numeric / sum(count(*)) over ()) * 100, 2) as "traffic_share, %"
from all_actions
group by extract(isodow from created_at)
order by total_actions asc;
```

Рекомендации для CTO: Ищите день в самом верху списка. В нашем случае - суббота и воскресенье, когда люди реже всего садятся за учебу. Это лучшие дни для крупных релизов.

2. Распределение активности по часам суток

Этот запрос детализирует нагрузку до конкретного часа (от 0 до 23). Он поможет определить точные часы для ночных или утренних технических работ.

```sql
with all_actions as (
	select created_at from coderun
	union all
	select created_at from codesubmit
	union all
	select created_at from teststart
)
select 
	extract(hour from created_at) as hour_of_day,
	count(*) as total_actions,
	round((count(*)::numeric / sum(count(*)) over ()) * 100, 2) as "traffic_share, %"
from all_actions
group by extract(hour from created_at)
order by total_actions asc;
```

Рекомендации для CTO: Первые 3–4 строчки результата покажут идеальное «релизное окно» (минимальный процент трафика). В нашем случае это интервал с 00:00 до 03:00 утра по серверному времени платформы.
Чтобы получить максимальную безопасность, СТО стоит совместить оба отчета. Идеальная точка для релиза — самый верхний (свободный) день недели из первого отчета, запущенный в самый верхний (тихий) час из второго отчета (например, в субботу в 04:00 утра).

3. А вот для для визуализации данных я посчитал нужным выгрузить всего один сырой CSV-файл со всеми фактами активности, а уже средствами Python разложить его на нужные графики. Так мы не рискуем потерять важную аналитическую глубину.

Для выгрузки данных используем SQL-запрос:

```sql
select created_at 
from coderun
union all
select created_at from codesubmit
union all
select created_at from teststart;
```

Для загрузки данных и построения графиков используем такой код:

```python
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# 1. Загружаем данные из одного CSV-файла
# Предполагаем, что колонка называется 'created_at'
df = pd.read_csv('platform_activity.csv', parse_dates=['created_at'])

# 2. Вытаскиваем день недели и час средствами Python
df['day_of_week'] = df['created_at'].dt.day_name()
df['day_of_week_num'] = df['created_at'].dt.dayofweek # 0=Понедельник, 6=Воскресенье
df['hour'] = df['created_at'].dt.hour

# Сортируем дни недели по порядку для графиков
days_order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']

# График 1: Распределение по дням недели
plt.figure(figsize=(10, 5))
sns.countplot(data=df, x='day_of_week', order=days_order, hue='day_of_week', palette='viridis', legend=False)
plt.title('Активность на платформе по дням недели')
plt.xlabel('День недели')
plt.ylabel('Количество действий')
plt.grid(axis='y', linestyle='--', alpha=0.7)
plt.show()

# График 2: Распределение по часам суток
plt.figure(figsize=(12, 5))
sns.countplot(data=df, x='hour', hue='hour', palette='magma', legend=False)
plt.title('Активность на платформе по часам суток')
plt.xlabel('Час суток (0-23)')
plt.ylabel('Количество действий')
plt.grid(axis='y', linestyle='--', alpha=0.7)
plt.show()

# График 3: Тепловая карта нагрузки
# Группируем данные в матрицу День x Час
pivot_table = df.groupby(['day_of_week', 'hour']).size().unstack(fill_value=0)
pivot_table = pivot_table.reindex(days_order)

plt.figure(figsize=(14, 7))
sns.heatmap(pivot_table, cmap='YlOrRd', annot=False)
plt.title('Тепловая карта активности: идеальное время для релизов (ищите самые светлые зоны)')
plt.xlabel('Час суток')
plt.ylabel('День недели')
plt.show()
```

Выводы: В ходе анализа результатов SQL-запросов и построенных визуализаций, могу рекомендовать проводить релизы в период с 00 до 03 часов в любой день, независимо от дня недели (предпочтительно - суббота и воскресенье), потому что в указанные периоды времени и дни недели наблюдается наименьшая активность пользователей.


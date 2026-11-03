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


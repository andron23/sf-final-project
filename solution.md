Задание 1
with a as (
	select 
		u2.id as user_id,
		to_char(u2.date_joined, 'YYYY-MM') as cohort,
		extract(days from entry_at - date_joined)as diff
	from userentry u 
	join users u2 
	on u.user_id = u2.id
	where to_char(u2.date_joined, 'YYYY-MM' )>='2022-01' 
)
select 
	cohort,
	round(count(distinct case when diff >= 0 then user_id end)*100.0/count(distinct case when diff >= 0 then user_id end), 2) as "0 day",
	round(count(distinct case when diff >= 1 then user_id end)*100.0/count(distinct case when diff >= 0 then user_id end), 2) as "1 day",
	round(count(distinct case when diff >= 3 then user_id end)*100.0/count(distinct case when diff >= 0 then user_id end), 2) as "3 day",
	round(count(distinct case when diff >= 7 then user_id end)*100.0/count(distinct case when diff >= 0 then user_id end), 2) as "7 day",
	round(count(distinct case when diff >= 14 then user_id end)*100.0/count(distinct case when diff >= 0 then user_id end), 2) as "14 day",
	round(count(distinct case when diff >= 30 then user_id end)*100.0/count(distinct case when diff >= 0 then user_id end), 2) as "30 day",
	round(count(distinct case when diff >= 60 then user_id end)*100.0/count(distinct case when diff >= 0 then user_id end), 2) as "60 day",
	round(count(distinct case when diff >= 90 then user_id end)*100.0/count(distinct case when diff >= 0 then user_id end), 2) as "90 day"
from a
group by cohort
Выводы:

Задание 2
with balances as(
	select 
		user_id,
		sum(
			case 
			when type_id in (1, 23, 24, 25, 26, 27, 28, 30) 
			then -value 
			else value 
			end
		) as balance,
		sum(
			case 
			when type_id in (1, 23, 24, 25, 26, 27, 28, 30) 
			then -value 
			else 0 
			end
		) as down,
		sum(
			case 
			when type_id in (1, 23, 24, 25, 26, 27, 28, 30) 
			then 0 
			else value 
			end
		) as up
	from transaction t 
	where value < 500
	group by user_id 
)
select 
	avg(down)as avg_down,
	avg(up) as avg_up,
	percentile_disc(0.5) within group(order by balance) as median_balance,
	avg(balance) as avg_balance
from balances
Выводы:

Задание 3
with a as(
	select  
		user_id,
		problem_id,
		is_false as att
	from 
	codesubmit c 
	union
	select 
		user_id, 
		problem_id,
		0 
	from
	coderun c1
),
task as(
	select 
		user_id,
		problem_id,
		sum(att)+1 as attempts
	from a
	group by
		user_id,
		problem_id
),
test as(
	select
		user_id,
		test_id,
		count(distinct id) as attempts_test
	from
	teststart t3 
	group by 
	user_id,
	test_id
),
result as (
select 
	u.id,
	count(distinct t.problem_id) as avg_task,
	count(distinct t2.test_id)as avg_test,
	avg(attempts) as avg_att_task,
	avg(attempts_test) as avg_att_test
from
	users u 
left join
	task t
on
	u.id = t.user_id
left join
	test t2
on
	u.id = t2.user_id 
group by
	u.id
)
select
	round(avg(case when avg_task>0 then avg_task end), 2) as "Решает задач в среднем",
	round(avg(case when avg_test>0 then avg_test end), 2) as "Решает тестов в среднем",
	round(avg(avg_att_task), 2) as "Среднее кол-во попыток решить задачу",
	round(avg(avg_att_test), 2) as "Среднее кол-во попыток решить тест",
	round(count(distinct case when avg_task>0 or avg_test>0 then id end)*100/count(distinct id), 2) as "Доля активных пользователей, %"
from 
	result
Выводы:

Задание 3 +
with 
user_transactions  
as (
	select 
	u.id,
	t.type_id
from 
	users u 
left join 
	"transaction" t 
on
	u.id = t.user_id 
)
select 
	count(distinct case when type_id=23 then id end) as "купили задачу, чел",
	count(distinct case when type_id in (26, 27) then id end) as "купили тест, чел",
	count(distinct case when type_id=24 then id end) as "купили подсказку к задаче, чел",
	count(distinct case when type_id=25 then id end) as "купили решение к задаче, чел",
	count(case when type_id in (23, 24, 25, 26, 27) then id end) as "подсказок/тестов/задач/решений было открыто за кодкоины",
	count(distinct case when type_id in (23, 24, 25, 26, 27) then id end) as "купили хотя бы что-то, чел",
	count(distinct case when type_id >0 then id end) as "имеют хотя бы 1 транзакцию, чел"
from user_transactions
Выводы:



Дополнительное задание 2
Для выгрузки данных используем SQL-запрос:
with activity_base
as (
	select 
		extract(dow from t.created_at) as day_of_week,
		to_char(t.created_at, 'Day') AS day_name,
		extract(hour from t.created_at) as hour_act,
		t.test_id as ex_id,
		t.user_id,
		'test' as type
	from
		teststart t 
	union 
	select
		extract(dow from c.created_at) as day_of_week,
		to_char(c.created_at, 'Day') AS day_name,
		extract(hour from c.created_at) as hour_act,
		c.problem_id,
		c.user_id,
		'problem' as type
	from
		coderun c
	union 
	select
		extract(dow from s.created_at) as day_of_week,
		to_char(s.created_at, 'Day') AS day_name,
		extract(hour from s.created_at) as hour_act,
		s.problem_id,
		s.user_id,
		'problem' as type
	from
		codesubmit s
)
select *
from 
	activity_base a
Для загрузки данных, построения графика, ..., используем такой код:

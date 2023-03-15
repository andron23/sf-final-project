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
Выводы: Самый высокий показатель Rolling retention у пользователей, зарегистрироваашихся в январе 2022 года. 

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
сколько в среднем коинов списывает 1 человек = 31,2
сколько в среднем коинов начисляется 1 человеку = 120
какой средний баланс среди всех пользователей = 59
какой медианный баланс среди всех пользователей = 89

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
Сколько в среднем пользователь решает задач = 9,18
Сколько в среднем пользователь проходит тестов = 1,68
Сколько в среднем пользователь делает попыток для решения 1 задачи = 1,61
Сколько в среднем пользователь делает попыток для прохождения 1 теста = 1,15
Какая доля от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест = 63%

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
Сколько человек открывало задачи за кодкоины = 522
Сколько человек открывало тесты за кодкоины = 676
Сколько человек открывало подсказки за кодкоины = 53
Сколько человек открывало решения за кодкоины = 151
Сколько подсказок/тестов/задач/решений было открыто за кодкоины (если задача/... открыта разными людьми, то это считаем разными фактами открытия) = 3 205
Сколько человек покупало хотя бы что-то из вышеперечисленного = 1 139
Сколько человек всего имеют хотя бы 1 транзакцию, пусть даже только начисление = 2 402

Дополнительное задание
Мне кажется на платформе уже выбран вариант монетизации "подписка", при этом в подписке пользователей могут привлекать разные возможности, например возможность получить подсказки, разборы задач и ответы. Для этого я предлагаю посчитать в какие моменты нужно предгалать пользователю оплатить подписку потому что:
на принятие решения о покупке подписки может влиять сложность задач и тестов, а также время суток когда человек решает задачи.

Код для расчета:
--1. какие задачи самые сложные
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
result as (
select 
	problem_id,
	user_id,
	avg(attempts) as att 
from 
	task
group by
	problem_id,
	user_id
order by
	problem_id
)
select 
	problem_id,
	sum(att)/count(distinct user_id) as att_aver
from 
	result
group by
	problem_id
having
	sum(att)/count(distinct user_id) > 1.5
order by
	att_aver desc 
select ...

--2. Какие тесты самые сложные
with test as(
	select
		user_id,
		test_id,
		count(distinct id) as attempts
	from
		teststart t3 
	group by 
		user_id,
		test_id
),
result as (
select 
	test_id,
	user_id,
	avg(attempts) as att 
from 
	test
group by
	test_id,
	user_id
order by
	test_id
)
select 
	test_id,
	sum(att)/count(distinct user_id) as att_aver
from 
	result
group by
	test_id
having
	sum(att)/count(distinct user_id) > 1.5
order by
	att_aver desc 

--3.когда сложнее всего решать задачи
with a as(
	select  
		extract(hour from c.created_at) as hour_act,
		user_id,
		problem_id,
		is_false as att
	from 
	codesubmit c 
	union
	select 
		extract(hour from c1.created_at) as hour_act,
		user_id, 
		problem_id,
		0 
	from
	coderun c1
),
task as(
	select 
		hour_act,
		user_id,
		problem_id,
		sum(att)+1 as attempts
	from a
	group by
		hour_act,
		user_id,
		problem_id
),
result as (
select 
	problem_id,
	user_id,
	avg(attempts) as att 
from 
	task
group by
	problem_id,
	user_id
order by
	problem_id
)
select 
	hour_act,
	avg(attempts) as avg_att
from task
group by
	hour_act 
having 
	avg(attempts) > 1.5
order by 
	hour_act, 
	avg_att 


Выводы:
1. получен список задач, на которые тратится в среднем больше 1,5 попыток
2. получен список тестов, на которые тратится в среднем больше 1,5 попыток
3. опеределен временной промежуток, когда сложнее всего решить задачу

Итоговые выводы по смене модели монетизации
Я считаю, что нужно продвигать подписку на платформе делая акцент на подсказках, разборах задач и просмотре ответов активнее всего с 5.00 до 7.00 утра и с 21.00 до 23.00, потому что решение задач в эти часы требует больше всего попыток. А еще, беря во внимание, что на сложные задачи и тесты тратиться больше попыток нужно предлагать пользователю подписку при решении этих заданий.

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
	
Для загрузки данных, построения графиков, используем такой код:
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
primer = pd.read_csv('activity_base_202303101505.csv', sep=',')
week_day_gr = primer.groupby(['day_of_week'])['ex_id'].count()
hour_gr = primer.groupby(['hour_act'])['ex_id'].count()
week_day_gr.plot(kind="bar", fontsize=10)
hour_gr.plot(kind="bar", fontsize=10)

Выводы: Рекомендую проводить релизы в четверг, с 10.00 до 16.00, потому что в это время самая высокая активность пользователей на платформе.


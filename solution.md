1. Расчет Rolling Retention с разбивкой по когортам. В качестве когорт берем месяц регистрации пользователя на платформе. 
В качестве n-дней: 0, 1, 3, 7, 14, 30, 60, 90 дней.

with base as 
	(select user_id, 
	   to_char(date_joined, 'YYYY-MM') as ym,
	   date(entry_at)-date(date_joined) as n_of_visit_days
  from users u, userentry u2 
  where u.id = u2.user_id)
select ym,		
	round(count(distinct case when n_of_visit_days >= 0 then user_id end) / count(distinct case when n_of_visit_days >= 0 then user_id end), 2) as day0,
	round(100.0 * count(distinct case when n_of_visit_days >= 1 then user_id end) / count(distinct case when n_of_visit_days >= 0 then user_id end), 2) as day1,
	round(100.0 * count(distinct case when n_of_visit_days >= 3 then user_id end) / count(distinct case when n_of_visit_days >= 0 then user_id end), 2) as day3,
	round(100.0 * count(distinct case when n_of_visit_days >= 7 then user_id end) / count(distinct case when n_of_visit_days >= 0 then user_id end), 2) as day7,
	round(100.0 * count(distinct case when n_of_visit_days >= 14 then user_id end) / count(distinct case when n_of_visit_days >= 0 then user_id end), 2) as day14,
	round(100.0 * count(distinct case when n_of_visit_days >= 30 then user_id end) / count(distinct case when n_of_visit_days >= 0 then user_id end), 2) as day30,
	round(100.0 * count(distinct case when n_of_visit_days >= 60 then user_id end) / count(distinct case when n_of_visit_days >= 0 then user_id end), 2) as day60,
	round(100.0 * count(distinct case when n_of_visit_days >= 90 then user_id end) / count(distinct case when n_of_visit_days >= 0 then user_id end), 2) as day90
from base
group by ym
order by ym

ВЫВОД: 
Наивысшая активность пользователей - в течение первых двух недель после регистрации на платформе (в среднем заходит на платформу треть от зарегистрировавшихся пользователей). 
По истечении месяца после регистрации на платформу возвращается порядка 20% пользователей, двух месяцев - порядка 15% пользователей, трех месяцев - 8% пользователей. 
Также можно отметить, что наиболее высокая активность сохранялась у пользователей, зарегистировавшихся на платформе в ноябре 2021 - треть пользователей проявляла активность даже по истечении 30 месяцев после регистрации.


2. Расчет метрик относительно баланса пользователя.

2.1. Сколько в среднем коинов списывает 1 человек:
with base as
	(select user_id, round(avg(value),1) as user_spend
	from "transaction" t 
	where type_id in (1, 23, 24, 25, 26, 27, 28, 30) and value > 0
	group by user_id
	order by user_id)
select round(avg(user_spend),1) as spend
from base

2.2. Сколько в среднем коинов начисляется 1 человеку:
with base as
	(select user_id, round(avg(value),1) as user_gett
	from "transaction" t 
	where type_id not in (1, 23, 24, 25, 26, 27, 28, 30) and value > 0
	group by user_id)
select round(avg(user_gett),1) as gett
from base

2.3. Какой средний баланс среди всех пользователей:
with base as	
	(select sum(a.val) as balance, user_id 
	from 
		(select user_id,
				case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then -value else value end val
				from "transaction" t) a
	   group by user_id)
select round(avg(balance),1) as avg_balance
from base

2.4. Какой медианный баланс среди всех пользователей:
with base as	
	(select sum(a.val) as balance, user_id 
	from 
		(select user_id,
				case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then -value else value end val
				from "transaction" t) a
	   group by user_id)
select percentile_cont(0.5) within group (order by balance) as med_balance
from base

ВЫВОД:
-- в среднем 1 человек списывает 26 коинов
-- в среднем 1 человеку начисляется 53 коина
-- средний баланс коинов среди всех пользователей - 275 
-- медианный баланс коинов среди всех пользователй - 62 (значительно меньше среднего баланса ввиду наличия топ-активных пользователей, имеющих на балансе тысячи коинов и подтягивающих наверх средний показатель)


3. Расчет метрик активности пользователей на платформе:

3.1. Сколько в среднем пользователь решает задач:
with base as
	(select user_id, count(distinct c.problem_id) as summ_tasks
		from coderun c 
		group by user_id
		order by user_id )	
select round(avg(summ_tasks),1) as avg_tasks
from base

3.2. Сколько в среднем пользователь проходит тестов:	
with base as
	(select user_id, count(distinct test_id) as summ_tests
	from teststart t   
	group by user_id
	order by user_id)
select round(avg(summ_tests),0) as avg_tests
from base
		
3.3. Сколько в среднем пользователь делает попыток для решения 1 задачи:
with base as 
	(select user_id, problem_id, count (problem_id) as tries
		from codesubmit 
		group by user_id, problem_id
		order by user_id)
select round(avg(tries),0) as avg_task_tries
from base
			
3.4. Сколько в среднем пользователь делает попыток для прохождения 1 теста:
with base as 
	(select user_id, test_id, count (created_at) as tries
		from teststart
		group by user_id, test_id
		order by user_id)
select round(avg(tries),0) as avg_test_tries
from base

ВЫВОД:
-- в среднем 1 пользователь решает 8 задач
-- в среднем 1 пользователь проходит 2 теста
-- в среднем 1 пользователь делает 3 попытки для прохождения задачи 
-- в среднем 1 пользователь делает 1 попытку для прохождения теста


4. Дополнительная оценка:

4.1. Какая доля от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест: 63,48 процента
with base as 
		(select distinct user_id from codesubmit
		union
		select distinct user_id from coderun
		union
		select distinct user_id from teststart)
select round(count (distinct user_id) / (select count(*) from users)::numeric * 100, 2) as active_part   
from base	

4.2. Сколько человек открывало задачи / тесты / подсказки / решения за кодкоины:
with base as
	(select user_id, type_id
	from "transaction" t)
select  
count (distinct case when type_id = 23 then user_id end) as us_open_tasks,
count (distinct case when type_id = 26 or type_id = 27 then user_id end) as us_open_tests,
count (distinct case when type_id = 24 then user_id end) as us_open_helps,
count (distinct case when type_id = 25 or type_id = 28 then user_id end) as us_open_decision,
count (case when type_id in (23, 24, 25, 26, 27, 28) then user_id end) as us_open_smth
from base

Открывали задачи за кодкоины (человек) - 522, тесты - 676, подсказки - 53, решения - 151. Открывали хотя бы что-то из перечисленного за кодкоины - 3205 раз.
 
4.3. Сколько человек покупало хотя бы что-то из перечисленного: 1139 человек (порядка 40% активных пользователей)
with base as
	(select user_id, type_id
	from "transaction" t)
select 
count (distinct case when type_id in (23, 24, 25, 26, 27, 28) then user_id end) as us_open_smth
from base

4.4. Сколько человек имеют хотя бы одну транзакцию, пусть даже только начисление: 2402 человека.
select count(distinct user_id) as us_active
from "transaction" t


ДОПОЛНИТЕЛЬНОЕ ЗАДАНИЕ:

Оценка оптимального времени для проведения релизов (публикации нового функционала на платформе).

1. В какие дни люди чаще / реже проявляют активность на платформе:

with base 
as
	(select created_at::date as activity_days, user_id as active_users
	from coderun c
	union 
	select created_at::date as activity_days, user_id as active_users
	from codesubmit
	union 
	select created_at::date as activity_days, user_id as active_users
	from teststart t) 
select count (active_users), extract (dow from activity_days) as weekday
from base
group by weekday
order by weekday

2. В какое время люди больше / меньше всего решают задачи / тесты на платформе.

with base as 
	(select created_at::time as activity_time, user_id as active_users
	from coderun
	union
	select created_at::time as activity_time, user_id as active_users
	from codesubmit
	union 
	select created_at::time as activity_time, user_id as active_users
	from teststart)		
select 
count (distinct case when activity_time between '00:00:01' and '05:00:00' then active_users end) as night_activity,
count (distinct case when activity_time between '05:00:01' and '11:00:00' then active_users end) as morning_activity,
count (distinct case when activity_time between '11:00:01' and '17:00:00' then active_users end) as daily_activity,
count (distinct case when activity_time between '17:00:01' and '23:59:59' then active_users end) as evening_activity
from base



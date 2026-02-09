Задание 1
-----
with r_retention as (
	select 
	u2.id as user_id, 
	to_char(u2.date_joined, 'YYYY-MM') as cohort,
	extract (days from entry_at - date_joined) as diff
from userentry u 
join users u2 
on u.user_id = u2.id
where to_char(u2.date_joined, 'YYYY-MM') >= '2022-01'
)
select cohort,
	round(count (distinct case when diff >= 0 then user_id end)*100.0/count (distinct case when diff >= 0 then user_id end), 2) as "0 day",
	round(count (distinct case when diff >= 1 then user_id end)*100.0/count (distinct case when diff >= 0 then user_id end),2) as "1 day",
	round(count (distinct case when diff >= 3 then user_id end)*100.0/count (distinct case when diff >= 0 then user_id end),2) as "3 day",
	round(count (distinct case when diff >= 7 then user_id end)*100.0/count (distinct case when diff >= 0 then user_id end),2) as "7 day", 
	round(count (distinct case when diff >= 14 then user_id end)*100.0/count (distinct case when diff >= 0 then user_id end),2) as "14 day",
	round(count (distinct case when diff >= 30 then user_id end)*100.0/count (distinct case when diff >= 0 then user_id end),2) as "30 day",
	round(count (distinct case when diff >= 60 then user_id end)*100.0/count (distinct case when diff >= 0 then user_id end),2) as "60 day",
	round(count (distinct case when diff >= 90 then user_id end)*100.0/count (distinct case when diff >= 0 then user_id end),2) as "90 day"
from r_retention 
group by cohort 
------
Выводы: В рассчете учитывала 2022 год, поскольку 2021 (как я поняла, год запуска платформы) в данном случае не является показательным. На основе данных за 2022 год наблюдается заметное падение числа пользователей, начиная с 7 дня. Причем поскольку rolling retention включает и тех пользователей, кто возвращается через время, то вероятнее всего часть пользователей января вернулась в апреле (февраль и март - слабые месяцы, в которые пользователи фокусируются на других внешних вопросах). Моей идеей было бы сделать следующие варианты подписки: 
единоразовая подписка (на месяц/год, где "на год" значительно дешевле). Недельную подписку не считаю релевантной, поскольку пользователи вряд ли будут ее продлевать - опять же по показателям rolling retention). С базовым тарифом, в который помимо входит базового функционал входит бессрочный доступ к пройденным урокам и премиум с возможностью смотреть разборы/решения, возможность обратной связи.
В базовую подписку я бы добавила PPU (если, конечно, предусмотрена такая опция на платформе), где пользователи могли бы покупать модули, уроки и т.д. - это позволит убрать некий триггер для пользователей, которые не хотят покупать премиум.
Задание 2
------

with coins as (
	select 
	sum(case when t.type_id in (1, 23, 24, 25, 26, 27, 28, 30) then value else 0 end) as losses,
	sum (case when t.type_id not in (1, 23, 24, 25, 26, 27, 28, 30) then value else 0 end) as profit 
from transaction t
where user_id is not null 
group by user_id
)
	select 
	round(avg(profit),2) as avg_profit, 
	round(avg (losses), 2) as avg_losses,
	round(avg(profit-losses), 2) as avg_balance,
	percentile_cont(0.5) within group (order by(profit-losses)) as median_balance
from coins 
------
Выводы:
1) в среднем пользователь списывает 31 коин.
2) в среднем пользователю начисляется 307 коинов.
3) Средний баланс среди всех пользователей - 275 коинов.
4) Медианный баланс среди всех пользователей - 62 коина.
Из результатов запроса видно, что пользователи не сильно заинтересованы в трате коинов. Средний показатель, на мой взгляд, подходит для расчета стоимости базового тарифа (+PPU, описанный ранее), то есть тот самый минимум, который нужен пользователю. Разница (более чем в 3 раза) медианного и среднего баланса показывает, что есть и пользователи, готовые тратить коины. Исходя из приведенной разницы думаю, что премиум подписка может стоить в 3 раза дороже базовой, при условии оплаты за месяц. 

Задание 3
with avg_tasks as (
	select 
	user_id, 
	problem_id as cnt
from coderun c 
union select 
	user_id, 
	problem_id as cnt
from codesubmit
), 
avg_tasks_2 as (
	select 
	count(*) as cnt
from avg_tasks 
group by user_id
)
select round(avg(cnt),2) as avg_tasks_done
from avg_tasks_2
------
Выводы: в среднем пользователь решает 9 задач.
------
with avg_tests as (
	select 
	count(distinct test_id) as cnt
from teststart
group by user_id
)
select round(avg(cnt), 2) as avg_test_done from avg_tests
------
Выводы: в среднем пользователь выполняет 2 теста.
-----
with avg_tasks_att as (
	select 
	user_id, 
	problem_id, 
	count(problem_id) as cnt 
from codesubmit
group by user_id, problem_id
)
select round(avg(cnt) ,2) as avg_tasks_attempts from avg_tasks_att
------
Выводы: в среднем один пользователь затрачивает 3 попытки для решения одной задачи.
------
with avg_tests_att as (
	select 
	user_id, 
	count(test_id) as cnt 
from teststart
group by user_id, test_id
)
select round(avg(cnt), 2) as avg_test_attempts 
from avg_tests_att
------
Выводы: в среднем пользователь затрачивает 1 попытку для прохождения теста.
-----
with a as (
	select 
	distinct user_id
from codesubmit 
union select 
	distinct user_id
from coderun
union select 
	distinct user_id
from teststart)
select round(count(*)/(select count(*) from users)::numeric*100, 2) as user_percent 
from a
------
Выводы: 64% пользователей решали хотя бы одну задачу или начинали проходить хотя бы один тест.
-----
with a as (
	select 
	count(distinct user_id) as users_op_tasks
from transaction t 
where t.type_id=23
),
b as (
	select 
	count(distinct user_id) as users_op_tests
from transaction t 
where t.type_id=26 or t.type_id=27
),
c as (
	select 
	count(distinct user_id) as users_op_tips
from transaction t 
where t.type_id = 24 
),
d as (
	select 
	count(distinct user_id) as users_op_solutions
from transaction t 
where t.type_id=25 
or t.type_id = 28
),
e as (
	select 
	count(*) as all_op, count (distinct t.user_id) as user_coins
from transaction t 
where t.type_id between 23 and 28
),
f as (
	select 
	count(distinct t.user_id) as users_buyers
from "transaction" t 
)
	select 
	a.users_op_tasks, 
	b.users_op_tests, 
	c.users_op_tips, 
	d.users_op_solutions, 
	e.all_op, 
	e.user_coins,
	f.users_buyers
from a, b, c, d, e, f
-----
Выводы: 
1) 522 пользователя открывали задачи за кодкоины
2) 676 пользователей открывали тесты за кодкоины
3) 53 пользователя открывали подсказки за кодкоины
4) 151 пользователь открывал решения за кодкоины
5) 3205 подсказок/тестов/решений и т.д. были открыты пользователями за кодкоины
Чаще всего пользователи тратят коины на задачи и тесты, что подтверждает теорию о том, что базовых уроков и модулей недостаточно для многих пользователей. Поэтому представляется целесообразным премиум формат подписки, который бы включал расширенное изучение тем с дополнительной практикой/задачами повышенной сложности/решениями задач и тестов.


Предложение новых метрик
-----
Помимо количества пользователей, которые приобретают продукты платформы за кодкоины, стоит рассчитать количество купленного по продуктам.
with tips as (
	select 
	count(*) as paid_tips
from transaction t
where t.type_id = 24
),
tests as (
	select 
	count(*) as paid_tests
from transaction t
where t.type_id between 26 and 27
),
tasks as (
	select 
	count(*) as paid_tasks
from transaction t
where t.type_id = 23
), 
solutions as (
	select 
	count(*) as paid_solutions 
from transaction t
where t.type_id = 25 or t.type_id=28
)
	select 
	tips.paid_tips, 
	tests.paid_tests, 
	tasks.paid_tasks, 
	solutions.paid_solutions
from tips, tests, tasks, solutions 
Выводы: всего пользователями были куплены за кодкоины 118 подсказок, 989 тестов, 1675 задач, 423 решения.
Данные данной метрики показывают, что пользователи чаще всего готовы платить за задачи, именно поэтому целесообразно включить дополнительные задачи/задачи повышенной сложности в тариф премиум.


Дополнительное задание
with work_table  as (
	select 
	user_id, 
	created_at
from codesubmit
union all
	select 
	user_id, 
	created_at
from teststart
),
date_time_table as (
	select *, 
	extract (isodow from created_at::date) as nd, 
	to_char(created_at::date, 'Day') as week_day,
	date_part('hour', created_at) as hour
from work_table
)
	select 
	nd, 
	week_day, 
	hour, 
	count(user_id) as activities,
	count(distinct user_id) as users 
from date_time_table
group by nd, week_day, hour
order by users asc
-----
Выводы: наибольшая активность пользователей (>50) приходится на рабочие дни в послеобеденное время. Релиз точно не стоит делать на выходных, поскольку там низкая активность пользователей.

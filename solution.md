--Задание 1--------------------------
with cohort_table as(
	select
		--u.entry_at, 
		u2.id as user_id,
		to_char(u2.date_joined, 'YYYY-MM') as cohort,
		extract (days from u.entry_at - u2.date_joined) as diff
	from userentry u 
	join users u2 
	on u.user_id = u2.id 
	where to_char(u2.date_joined, 'YYYY-MM') >= '2022-01' 
)
select
	cohort as "month",
	round(count(distinct case when diff >= 0 then user_id end)*100.0 / count(distinct case when diff >= 0 then user_id end),2) as "0 day",
	round(count(distinct case when diff >= 1 then user_id end)*100.0 / count(distinct case when diff >= 0 then user_id end),2) as "1 day",
	--round(count(distinct case when diff >= 2 then user_id end)*100.0 / count(distinct case when diff >= 0 then user_id end),2) as "2 day",
	round(count(distinct case when diff >= 3 then user_id end)*100.0 / count(distinct case when diff >= 0 then user_id end),2) as "3 day",
	--round(count(distinct case when diff >= 5 then user_id end)*100.0 / count(distinct case when diff >= 0 then user_id end),2) as "5 day",
	round(count(distinct case when diff >= 7 then user_id end)*100.0 / count(distinct case when diff >= 0 then user_id end),2) as "7 day",
	round(count(distinct case when diff >= 14 then user_id end)*100.0 / count(distinct case when diff >= 0 then user_id end),2) as "14 day",
	round(count(distinct case when diff >= 30 then user_id end)*100.0 / count(distinct case when diff >= 0 then user_id end),2) as "30 day",
	round(count(distinct case when diff >= 60 then user_id end)*100.0 / count(distinct case when diff >= 0 then user_id end),2) as "60 day",
	round(count(distinct case when diff >= 90 then user_id end)*100.0 / count(distinct case when diff >= 0 then user_id end),2) as "90 day"
from cohort_table
group by cohort
--Выводы: Предлагаю использовать тариф типа "Неделька", по данным видно что активность в среднем по месяцам резко спадает к 3 дню и не значительно меняеться в промежутке между 3 и 7 днем, а уже далее уходит на спад.
--Т.е. пользователи активны в течении первых 3-х дней, следовательно на недельку, скорей всего точно оплатят подписку, если больше - уже призадумаются.
--И тариф "На один день" - поскольку основная активность в течении первого дня, возможно на выходных пользователи любят посидеть по решать задачи и тесты

--Задание 2--------------------------
with Data_table as (
	select
		user_id,
		sum(
			case
				when type_id in (1, 23, 24, 25, 26, 27, 28, 30)
				then -value
				else null
			end
			) as U_Off,
		sum(
			case
				when type_id not in (1, 23, 24, 25, 26, 27, 28, 30)
				then value
				else null
			end
			) as U_On,
		sum(
			case
				when type_id in (1, 23, 24, 25, 26, 27, 28, 30)
				then -value
				else value
			end
			) as U_balance
	from "transaction" t
	group by user_id)
select
	round(avg(U_Off),2) as "Списывает 1 человек в среднем",
	round(avg(U_On),2) as "Начисляется 1 человеку в среднем",
	round(avg(U_balance),2) as "средний баланс",
	mode () within group (order by U_balance) as "медианный баланс"
from Data_table
--Выводы: Учитывая начисления и медианный баланс, получается что в среднем пользователь делает порядка 5 списаний по стоимости в районе 70 коде-коинов,
--что бы полностью переводить на подписку, имеет смысл указать стоимость в районе 40-50 коде-коинов, для тарифа на день и примерно 100-110 коинов для тарифа на неделю,
--что бы было пользователю было более комфортно относительно текущей ситуации 

--Задание 3--------------------------
-- Первая метрика
with table_tasks as(
	select
		user_id,
		count(*) as tasks
	from 
		(select
			c.user_id,
			c.problem_id
		from coderun c 
		union
		select
			c2.user_id,
			c2.problem_id
		from codesubmit c2) as summ
	group by user_id)
select 
	round(avg(t1.tasks), 2) as "Ко-во задач на 1 чел. в среднем"
from table_tasks t1
	------ в среднем на одного человека приходится ~9 задач

-- Вторая метрика
with table_test as (
	select
		user_id,
		count(test_id) as test
	from teststart
	group by user_id)
select
	round(avg(t2.test), 2) as "Ко-во тестов на 1 чел. в среднем"
from table_test t2
	------ в среднем на одного человека приходится ~2 теста

--Третья метрика
with table_try_tasks as (
	select
		c.user_id,
		c.problem_id,
		count(c.problem_id) as cnt
	from coderun c
	group by c.user_id, c.problem_id
	union
	select
		c2.user_id,
		c2.problem_id,
		count(c2.problem_id) as cnt
	from codesubmit c2
	group by c2.user_id, c2.problem_id)
select
	round(avg(t3.cnt), 2) as "Ко-во попыток на 1 чел. в среднем"
from table_try_tasks t3
 	------ в среднем один пользователь делает ~6 попыток для решения одной задачи

--Четвертая метрика
with try_test as (
	select
		user_id,
		test_id,
		count(test_id) as cnt
	from teststart t 
	group by user_id, test_id)
select
	round(avg(t4.cnt), 2) as "Ко-во попыток на 1 чел. в среднем"
from try_test t4
 	------ в среднем один пользователь делает чуть больше 1 попытки для решения одного теста

--Допоолнительно важно оценить
with t_users as (
	select
		count(distinct user_id) as cnt_users
	from (
		select
			user_id
		from codesubmit
		union
		select
			user_id
		from coderun
		union
		select
			user_id
		from teststart) as table_users), 
all_users as (
	select 
		count(*) as cnt_all_users
	from users)
select 
	round(cnt_users*1.0/cnt_all_users*100.0, 2) as "Доля"
from 
	t_users, all_users
	------ Общая доля числа пользователей, которые которая решала хотя бы одну задачу или тест ~63,5%

--Информация по покупкам
with cnt_transaction as (
	select
		count(distinct user_id) as cnt_trns
	from "transaction" t),
transaction_kk as (
	select
		user_id,
		type_id,
		count(value) as cnt_value
	from "transaction" t
	where value > 0 and type_id in (23, 24, 25, 26, 27)
	group by user_id, type_id),
People_kk as (
	select
		count(case when type_id = 23 then 'OK' end) as p_task,
		count(case when type_id in (26, 27) then 'OK' end) as p_test,
		count(case when type_id = 24 then 'OK' end) as p_hint,
		count(case when type_id = 25 then 'OK' end) as p_solution,
		count(distinct user_id) as p_all,
		sum(cnt_value) as sum_open,
		sum(case when type_id = 23 then cnt_value end) as sum_open_task,
		sum(case when type_id in (26, 27) then cnt_value end) as sum_open_test,
		sum(case when type_id = 24 then cnt_value end) as sum_open_hint,
		sum(case when type_id = 25 then cnt_value end) as sum_open_solution
	from transaction_kk)
select
	p_task as "Кол-во чел. откр.задачи за КК",
	p_test as "Кол-во чел. откр.тесты за КК",
	p_hint as "Кол-во чел. отк.подсказки за КК", 
	p_solution as "Кол-во чел. отк.решение за КК",
	sum_open as "Общее кол-во за КК",
	--sum_open_task as "Из них задача за КК",
	--sum_open_test as "Из них тестов за КК",
	--sum_open_hint as "Из них подсказок за КК",
	--sum_open_solution as "Из них решений за КК",
	p_all as "Кол-во чел. купило",
	cnt_trns as "Кол-во чел. с транзакциями"
from People_kk, cnt_transaction
	------  человек открывало задачи за кодкоины - 450
	------  человек открывало тесты за кодкоины - 588
	------  человек открывало подсказки за кодкоины - 52
	------  человек открывало решения за кодкоины - 151
	------  подсказок/тестов/задач/решений было открыто за кодкоины - 2 973
		----- задач - 1 589
		----- тестов - 844
		----- подсказок - 117
		----- решений 423
	------  человек покупало хотя бы что-то из вышеперечисленного - 991 
	------  человек всего имеют хотя бы 1 транзакцию - 2 402

--Выводы: В бесплатном виде оставить несколько попыток для решения, для задач 3 (так как в среднем пытаются пройти по 6 раз), для тестов - 1 (так же руководствуясь данными по попыткам)
--Задачи по количеству занимают большую долю среди всего предложенного за кодкоины (1589 при общем в 2973), но по данным сколько человек открывали (588 простив 450), то тесты популярнее
--По этому тесты можно включать в платную подписку и увеличивать количество тестов.
--А задачи - нужно видимо сегментировать, к примеру по степени трудности и простые включать в платную подписку, а сложные оставлть бесплатными (там все равно еще и решение и подсказки приобретут)


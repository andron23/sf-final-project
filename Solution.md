```sql
Задание 1
--Расчет rolling retention с разбивкой по когортам--
with a as (
	select user_id, 
		   to_char(date_joined, 'YYYY-MM') as dat,
		   date(entry_at) - date(date_joined) as n_days
		from users u 
		join userentry ue 
			on (u.id = ue.user_id)
	    where to_char(date_joined, 'YYYY') = '2022'
), b as (
select dat, count(distinct case when n_days >= 0 then user_id end) as day0
	      from a
	      group by dat
)
select c.dat as yw,
	   round(100.0 * count(distinct case when n_days >= 1 then user_id end) / day0, 2) as day1,
	   round(100.0 * count(distinct case when n_days >= 3 then user_id end) / day0, 2) as day3,
	   round(100.0 * count(distinct case when n_days >= 7 then user_id end) / day0, 2) as day7,
	   round(100.0 * count(distinct case when n_days >= 14 then user_id end) / day0, 2) as day14,
	   round(100.0 * count(distinct case when n_days >= 30 then user_id end) / day0, 2) as day30,
	   round(100.0 * count(distinct case when n_days >= 60 then user_id end) / day0, 2) as day60,
	   round(100.0 * count(distinct case when n_days >= 90 then user_id end) / day0, 2) as day90 
from a c
	join b
		on (c.dat = b.dat)
	group by c.dat, day0
```sql 

```sql
Задание 2
--Расчет метрик относительно баланса пользователя--
with a as (
	select user_id, 
	   	   sum(case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then value else 0 end) as debiting,
	       sum(case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then 0 else value end) as accrual,
	       sum(case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then -value else value end) as avg_balance
    from transaction t 
	group by user_id
)
select round(avg(debiting), 2) as avg_debiting, --Среднее списание-- 
       round(avg(accrual), 2) as avg_accrual, --Среднее начисление--
       round(avg(avg_balance), 2) as avg_balance, --Средний баланс всех пользователей-- 
       percentile_cont(0.5) within group (order by avg_balance) as median_balance --Медианный баланс--
from a
```sql

```sql
Задание 3. Расчет метрик активности пользователей на платформе
--Сколько в среднем пользователь решает задач--
with a as (  				  
select user_id, problem_id as cnt
	from coderun
	   union						 
select user_id, problem_id as cnt   
	from codesubmit
), b as (
select count(*) as cnt
	from a
	group by user_id
)
select round(avg(cnt), 2) as avg_problem 
	from b

--Сколько в среднем пользователь проходит тестов--
with a as (
	select distinct test_id, count(*) as cnt 
		from teststart
	    group by user_id, test_id
)
select round(avg(cnt), 2) as avg_test
	from a

--Сколько в среднем пользователь делает попыток для решения 1 задачи--
with a as (
	select count(*) - sum(is_false) as cnt_attemps_user
		from codesubmit
	    group by user_id, problem_id 
)
select round(avg(cnt_attemps_user), 2) as avg_cnt_attemps
	from a

--Сколько в среднем пользователь делает попыток для прохождения 1 теста--
with a as (
	select count(test_id) as cnt
		from teststart t 
	    group by user_id 
)
select round(avg(cnt), 2) as avg_attemps_one_test 
	from a

--Какая доля от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест--
with a as (
    select distinct user_id
	    from codesubmit
	    	union
	select distinct user_id                   
	    from coderun
	    	union
	select distinct user_id 
	    from teststart
)
select round(count(*) / (select count(*) from users)::numeric * 100, 2) as percent_users   
	from a

--Сколько человек открывало задачи за кодкоины--
--Сколько человек открывало тесты за кодкоины--
--Сколько человек открывало подсказки за кодкоины--
--Сколько человек открывало решения за кодкоины--
--Сколько человек покупало хотя бы что-то из вышеперечисленного--
with a as (
	select distinct user_id, type_id 
		from transaction t
)
select count(case when type = 23 then 1 end) as tasks,
	   count(case when type in (26, 27) then 1 end) as tests,
	   count(case when type = 24 then 1 end) as hints,
	   count(case when type = 25 then 1 end) as solutions,
	   count(case when type in (23, 24, 25, 26, 27) then 1 end) as cnt_users
	from a t                                                               
	join transactiontype t2 
		on (t.type_id = t2."type")

--Сколько подсказок/тестов/задач/решений было открыто за кодкоины (если задача/... открыта разными людьми, то это считаем разными фактами открытия)--
select count(case when type = 24 then 1 end) as hints,
	   count(case when type in (26, 27) then 1 end) as tests,
	   count(case when type = 23 then 1 end) as tasks,
	   count(case when type = 25 then 1 end) as solutions,
	   count(case when type in (23, 24, 25, 26, 27) then 1 end) as total_result
	from transaction t 
	join transactiontype t2 
		on (t.type_id = t2."type")

--Сколько человек всего имеют хотя бы 1 транзакцию, пусть даже только начисление--
select count(distinct user_id) as cnt_users
	from transaction t 
    where type_id is not null
```sql
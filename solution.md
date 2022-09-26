# ЗАДАНИЕ 1 
Расчет rolling retention с разбивкой по когортам
with SumRegUserPerMonth as (
      select 
          to_char(users.date_joined, 'YYYY-MM') as yw,
          count(distinct users.id) as RegUser
      from 
            users 
      group by 
            yw /*тут мы смотрим сколько зарегестировалось в каждом месяце*/
),
LastEnterAfterRegistration as ( 
      select 
          to_char(u.date_joined, 'YYYY-MM') as yw,
          u.id,
          max(case
	              when date (u2.entry_at) - date(u.date_joined) < 0 
	              or date (u2.entry_at) is null 
	              then 
	              0 /*не было входа вообще*/
	              else 
	              date (u2.entry_at) - date(u.date_joined) 
	              end)
	              as n_days  /*сколько дней прошло со входа*/ 
       from 
          users u
       left join 
          userentry u2 
        on 
	  u.id = u2.user_id 
        group by 
	  yw, u.id
), 
EnterByDaysAndYM as (
       select 
             yw,
             sum(case when n_days >=0 then 1 else 0 end) as day0,
             sum(case when n_days >=1 then 1 else 0 end) as day1,
             sum(case when n_days >=3 then 1 else 0 end) as day3,
             sum(case when n_days >=7 then 1 else 0 end) as day7,
             sum(case when n_days >=14 then 1 else 0 end) as day14,
             sum(case when n_days >=30 then 1 else 0 end) as day30,
             sum(case when n_days >=60 then 1 else 0 end) as day60,
             sum(case when n_days >=90 then 1 else 0 end) as day90
        from 
             LastEnterAfterRegistration
         group by 
              yw
)
select 
       l.yw, 
       round(day0::numeric/RegUser*100, 2) as day0,
       round(day1::numeric/RegUser*100, 2) as day1,
       round(day3::numeric/RegUser*100, 2) as day3,
       round(day7::numeric/RegUser*100, 2) as day7,
       round(day14::numeric/RegUser*100, 2) as day14,
       round(day30::numeric/RegUser*100, 2) as day30,
       round(day60::numeric/RegUser*100, 2) as day60,
       round(day90::numeric/RegUser*100, 2) as day90 /*Тут мы считаем проценты и округляем до двух знаков после запятой*/
from 
      EnterByDaysAndYM l
inner join 
      SumRegUserPerMonth r 
on 
      l.yw = r.yw
order by 
      yw
# ЗАДАНИЕ 2
Расчет метрик относительно баланса пользователя:

-сколько в среднем коинов списывает 1 человек

-сколько в среднем коинов начисляется 1 человеку

-какой средний баланс среди всех пользователей

-какой медианный баланс среди всех пользователей

with balance_table as  (
    select 
       user_id,
       sum
       (case when type_id in (1,23,24,25,26,27,28,30) then value else 0 end) as write_off,
       sum
       (case when type_id in (2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,29) then value else 0 end) as charges,
       sum
       (case when type_id in (1,23,24,25,26,27,28,30) then -value else value end ) as balance
     from
        "transaction" t
     group
        by user_id
     )
select 
     avg(write_off), avg(charges), avg(balance), mode() within group (order by balance) as median_balance
from 
     balance_table

**Выводы:** очень маленький процент спиcания коинов по сравнению со средним балансом и средним начислением, не хватаем интересных идей на что можно использовать полученные коины.

# ЗАДАНИЕ 3
**Задание 3.1**

•	Сколько в среднем пользователь решает задач

with a as (
      select 
         user_id,
         problem_id 
         from codesubmit c 
      union 
      select 
          user_id,
          problem_id 
          from coderun c2 ),
b as (
select
user_id,
count(distinct problem_id) as cnt
from a
group by user_id
)
select 
round(avg(cnt),2) as AvgProblemSolved
from b

ОТВЕТ 9.18

**Задание 3.2**

•	Сколько в среднем пользователь проходит тестов

  with a as (
	select 
		user_id, 
		count(distinct test_id) as cnt
	from teststart t 
	group by user_id
    )
    select 
        round(avg(cnt),2) as avgTestSolved
    from a

ОТВЕТ 1,68

**Задание 3.3**

Сколько в среднем пользователь делает попыток для решения 1 задачи

with a as (
         select
              user_id,
              problem_id,
              count (*)  as cnt  
              from codesubmit c
              group by user_id, problem_id)
select 
avg (cnt) as avg_problemeffort
from a 

**Задание 3.4**

. Сколько в среднем пользователь делает попыток для прохождения 1 теста

with a as (
        select 	
            user_id,
            test_id,
            count(test_id) as cnt
        from 
            teststart
        group by 
            user_id, test_id
    )
    select 
        round(avg(cnt),2) as avg_testeffort
    from 
        a
ОТВЕТ 1.26

**Задача 3.5**

Какая доля от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест
a  -  считаем всех пользователей 
b – пользователи, решающие хотя бы одну задачу
с – пользователи, начинающие проходить хоть 1 тест

        with countAllUsers as (
	select
		count(distinct id) as cnt
	from users
),
countUsersTryTask as (
	select
		count(distinct user_id) as cnt
	from codesubmit
),
countUsersTryTest as (
	select
		count(distinct user_id) as cnt
	from teststart
)
select
	B.cnt::numeric/A.cnt as ratio_task,
	E.cnt::numeric/A.cnt as ratio_test
from countAllUsers A,countUsersTryTask  B, countUsersTryTest E


**Выводы:**  Доля пользователей, которая решала хотя бы одну задачу, составила 0,31, тестов - 0,44

Плюс еще информация по покупкам материалов на платформе за кодкоины - эти 6 чисел нужно вывести 1 запросом, чтобы было наглядно:
•	Сколько человек открывало задачи за кодкоины
•	Сколько человек открывало тесты за кодкоины
•	Сколько человек открывало подсказки за кодкоины
•	Сколько человек открывало решения за кодкоины
•	Сколько подсказок/тестов/задач/решений было открыто за кодкоины (если задача/... открыта разными людьми, то это считаем разными фактами открытия)
•	Сколько человек покупало хотя бы что-то из вышеперечисленного
•	Сколько человек всего имеют хотя бы 1 транзакцию, пусть даже только начисление

with users_with_transactions as (
        select 
            count(distinct user_id) as users_with_transactions
        from "transaction" t ),
    user_and_type as (
        select 
            user_id, 
            type_id,
            count(value) as cnt
        from 
            "transaction" t 
        where 
            value > 0   
            and type_id in (23,27,24,25)
        group by 
            user_id, 
            type_id
    ),
    users_buying_with_coins as (
        select 
            sum(case when type_id = 23
                    then  1 
                    else 0 end) 
                as users_open_problems_with_coins_23,
            sum(case when type_id = 27
                    then 1 
                    else 0 end)
                as users_open_tests_with_coins_27,
            sum(case when type_id = 24
                    then 1 
                    else 0 end) 
                as users_open_clue_with_coins_24,
            sum(case when type_id = 25
                    then 1 
                    else 0 end) 
                as users_open_solutions_with_coins_25,
            count(distinct user_id) as users_open_with_coins_23_27_24_25
        from 
            user_and_type),
    all_openings_for_coins as (
        select 
            sum(case when type_id = 23
                    then cnt
                    else 0 end) as openings_for_coins_23,
            sum(case when type_id = 27
                    then cnt
                    else 0 end) as openings_for_coins_27,
            sum(case when type_id = 24
                    then cnt
                    else 0 end) as openings_for_coins_24,
            sum(case when type_id = 25
                    then cnt
                    else 0 end) as openings_for_coins_25
        from 
            user_and_type)
    select 
        A.users_open_problems_with_coins_23,
        A.users_open_tests_with_coins_27,
        A.users_open_clue_with_coins_24,
        A.users_open_solutions_with_coins_25,
        B.openings_for_coins_23,
        B.openings_for_coins_27,
        B.openings_for_coins_24,
        B.openings_for_coins_25,
        A.users_open_with_coins_23_27_24_25,
        C.users_with_transactions
    from 
        users_buying_with_coins A, 
        all_openings_for_coins B, 
        users_with_transactions C
	
# Дополнительное задание 2

select table_coderun.weekday as weekday,
	table_coderun.dayhour as dayhour,
	table_coderun.cnt_of_activity+table_test_start.cnt_of_activity+table_codesubmit.cnt_of_activity as cnt_of_activity
from
	(select
		count(user_id) as cnt_of_activity, 
		weekday,
		dayhour 
	from
			(select
				user_id, 
				to_char(created_at, 'HH24:00') as dayhour,
				to_char( created_at, 'day') as weekday
			from 
				coderun) as t1
	group by weekday, dayhour) as table_coderun
full outer join 
	(select
		count(user_id) as cnt_of_activity, 
		weekday,
		dayhour
	from
			(select
				user_id, 
				to_char(created_at, 'HH24:00') as dayhour,
				to_char(created_at, 'day') as weekday
			from 
				teststart) as t1
	group by weekday, dayhour) as table_test_start
on 
	table_coderun.weekday=table_test_start.weekday
	and table_test_start.dayhour=table_coderun.dayhour
full outer join
	(select
		count(user_id) as cnt_of_activity, 
		weekday,
		dayhour
	from
			(select
				user_id, 
				 to_char(created_at, 'HH24:00') as dayhour,
				to_char(created_at, 'day') as weekday
			from 
				codesubmit) as t1
	group by weekday, dayhour) as table_codesubmit
on table_coderun.weekday=table_codesubmit.weekday
	and table_codesubmit.dayhour=table_coderun.dayhour




# Задание 1
select 
	date_joined,
	day0,
	round(day1::numeric,2) as day1 ,
	round(day3::numeric,2) as day3,
	round(day7::numeric,2) as day7,
	round(day14::numeric,2) as day14,
	round(day30::numeric,2) as day30,
	round(day60::numeric,2) as day60,
	round(day90::numeric,2) as day90
from
	(select
		date_joined,
		cast(count(
			case 
			when day0 in (0,1,3,7,14,30,60,90) then +day0
			end) as float)/cast(count(date_joined) as float) as day0,
		cast(count(
			case 
			when day0 in (1,3,7,14,30,60,90) then +day0
			end) as float)/cast(count(date_joined) as float)*100 as day1,
		cast(count(
			case 
			when day0 in (3,7,14,30,60,90) then +day0
			end) as float)/cast(count(date_joined) as float)*100 as day3,
		cast(count(
			case 
			when day0 in (7,14,30,60,90) then +day0
			end) as float)/cast(count(date_joined) as float)*100 as day7,
		cast(count(
			case 
			when day0 in (14,30,60,90) then +day0
			end) as float)/cast(count(date_joined) as float)*100 as day14,
		cast(count(
			case 
			when day0 in (30,60,90) then +day0
			end) as float)/cast(count(date_joined) as float)*100 as day30,
		cast(count(
			case 
			when day0 in (60,90) then +day0
			end) as float)/cast(count(date_joined) as float)*100 as day60,
		cast(count(
			case day0
			when  90 then +day0
			end) as float)/cast(count(date_joined) as float)*100 as day90
	from
		(select 
			case 
			when data_diff>=90 then 90
			when data_diff>=60 then 60
			when data_diff>=30 then 30
			when data_diff>=14 then 14
			when data_diff>=7 then 7
			when data_diff>=3 then 3
			when data_diff>=1 then 1
			else 0
			end as day0,
			user_id,
			data_diff,
			date_joined
		from
			(select
				u.user_id,
				left(cast(date(u.entry_at) as varchar), 7) as entry_at , 
				left(cast(date(u2.date_joined) as varchar), 7) as date_joined, 
				abs(date_part('day', u.entry_at-u2.date_joined)) as data_diff
			from 
				userentry u 
			inner join users u2 
			on u2.id=u.user_id) as t_1) as t_1
	group by 
		date_joined) as t3

Выводы: исходя из данных видно, что со временем активность пользователей падает. Но есть интересная тенденция, что пользователи, которые зарегистрировались весной, через 3 месяца перестают пользоваться платформой вообще. Следовательно можно предположить, что летом активность пользователей падает, и наоборот, пользователи, зарегистрировавшиеся осенью, проявляют очень высокую активность в течении 90 дней.  
# Задание №2
 select 
	sum(sum_spisanii)/count(user_id) as ср_знач_списание_коинов, 
	sum(sum_nachislenii)/count(user_id) as ср_знач_начисление_коинов,
	avg(budget) as ср_знач_баланса,
	percentile_cont(0.5) within group (order by budget) as медианный_баланс
from
	(select 
		user_id, 
		sum(spisanii) as sum_spisanii, 
		sum(nachislenii) as sum_nachislenii, 
		sum(nachislenii)-sum(spisanii) as budget 
	from 
		(select 
			t_nachislenii.user_id, 
			coalesce(t_spisan.spisanii, 0) as spisanii, 
			t_nachislenii.nachislenii  
		from  
			(select 
				user_id,  
				sum(coalesce(value,0)) as spisanii 
			from 
				"transaction" t
			where 
				type_id in (1,23,24,25,26,27,28,30)
			group by 
				user_id) as t_spisan 
			full outer join 
			(select 
				user_id, 
				sum(coalesce(value, 0)) as nachislenii 
			from 
				"transaction" t
			where type_id not in (1,23,24,25,26,27,28,30)
			group by 
				user_id)  as t_nachislenii
			on t_spisan.user_id=t_nachislenii.user_id) as t_ready
	group by user_id) as table_ready


Выводы: Судя по показателям, на платформе очень большой объем бесплатной информации, но при этом бонусные код-коины начисляются. 

# Задание №3
в среднем пользователь решает задач 8. КОД:

select 
	round(avg(count_task), 0) as avd_task
from
	(select 
		user_id, count(count_task) as count_task
	from 
		(select 
			user_id, count(problem_id) as count_task
		from 
			coderun c 
		group by user_id, problem_id) as table_count_id
	group by 
		user_id) as count_count_task
    
    
в среднем пользователь решает 2 теста. Код:

select 
	round(avg(count_test), 0) as avg_count_test
from
	(select 
		user_id, count(test_id ) as count_test
	from
		(select 
			user_id, test_id 
		from 
			teststart t 
		group by user_id, test_id) as table_group_test 
	group by user_id) as table_count_test


Сколько попыток делает в среднем пользователь для решения 1 задачи. Код:


select 
	round(sum(cnt)/count(cnt), 2) as avg_attempt_task,
	round(sum(correct)/count(correct), 2) as avg_attempt_task_correсt,
	round(sum(incorrect)/count(incorrect), 2) as avg_attempt_task_incorreсt
	from
		(select 
			user_id, 
			problem_id,
			count(*) as cnt,
			sum(is_false) as incorrect,
			count(*) - sum(is_false) as correct
		from 
			codesubmit c
		group by user_id, problem_id) as table_1
    
    
сколько в средней пользователей делает попыток решить тест. КОД:


select
	round(sum(cnt)/count(cnt),1) as avg_test
from
	(select 
		user_id,
		test_id,
		count(test_id) as cnt
	from 
		teststart t 
	group by test_id, user_id) as t_1


Какая доля от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест

select
	cast(count(teststart.test_id) as float)/cast(count(users.id) as float) as share_test,
	cast(count(coderun.problem_id) as float)/cast(count(users.id) as float) as share_task,
	count(users.id)  as cnt_users,
	count(teststart.test_id)  as cnt_test,
	count(coderun.problem_id) as cnt_task
from users 
full outer join teststart
	on teststart.user_id = users.id 
full outer join coderun
	on coderun .user_id = users.id 
  
  
  Код по покупкам материалов на платформе за кодкоины
  
  select 
	count(
		case type_id
			when 23 then +user_id
			end) as cnt_task,
		count(
		case
			when type_id in (26, 27) then +user_id
			end) as cnt_test,
		count(
		case type_id
			when 24 then +user_id
			end) as cnt_prompt,
		count(
		case type_id
			when 25 then +user_id
			end) as cnt_decision,
		count(
		case 
			when type_id in (23, 24, 26, 27, 25) then +user_id
			end) as sum_people_buy_something,
		count(distinct user_id) as count_of_peоple_have_transaction,
		sum(case 
			when type_id in (23, 24, 26, 27, 25) then +cnt
			end) as count_opened_task_test_prompt_decision
from
	(SELECT 
		transaction.type_id,
		transactiontype.description,
		transaction.user_id, 
		count(transaction.type_id) as cnt
	from 
		transaction
	left join 
		transactiontype
	on transaction.type_id = transactiontype.type
	group by 
		transaction.type_id,
		transactiontype.description,
		transaction.user_id) as t_1
    
Выводы: исходя из данных можно сделать вывод, что задачи пользуются большей популярностью среди пользователей, но при этом код-коинов больше потрачено на тесты (цены на открытие тестов и задач одинаковые), что опять подтверждает предположение, что очень много бесплатных задач. Так же исходя из данных можно сделать вывод, что 40% пользователей пользуются подсказками и открывают решения.



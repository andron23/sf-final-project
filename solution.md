#**Задание 1** - посчитать rolling retantion
```sql
with cohort_table as(

	select
		u.id as user_id,
		to_char(u.date_joined, 'YYYY-MM') as cohort,
		extract(days from ue.entry_at - u.date_joined) as diff
	from userentry ue
	join users u
	on ue.user_id = u.id
	where to_char(u.date_joined, 'YYYY') >= '2022'	
)
select
	cohort,
  	round(count(distinct case when diff >=0 then user_id end)*100.0 /count(distinct case when diff >=0 then user_id end), 2) as "day0",
  	round(count(distinct case when diff >=1 then user_id end)*100.0 /count(distinct case when diff >=0 then user_id end), 2) as "day1",
  	round(count(distinct case when diff >=3 then user_id end)*100.0 /count(distinct case when diff >=0 then user_id end), 2) as "day3",
  	round(count(distinct case when diff >=7 then user_id end)*100.0 /count(distinct case when diff >=0 then user_id end), 2) as "day7",
  	round(count(distinct case when diff >=14 then user_id end)*100.0 /count(distinct case when diff >=0 then user_id end), 2) as "day14",
  	round(count(distinct case when diff >=30 then user_id end)*100.0 /count(distinct case when diff >=0 then user_id end), 2) as "day30",
  	round(count(distinct case when diff >=60 then user_id end)*100.0 /count(distinct case when diff >=0 then user_id end), 2) as "day60",
  	round(count(distinct case when diff >=90 then user_id end)*100.0 /count(distinct case when diff >=0 then user_id end), 2) as "day90"
from cohort_table
group by cohort
```
***Результат***:

![image](https://github.com/FatPodobed/sf-final-project/assets/101504000/76ca8dbc-dbb9-410a-ac52-ece96c501caa)

***Выводы***: 

Большая часть клиентов ограничивает проявляют активность в течении дня регистрации

(от ~60% до ~70% клиентов отваливаются через день после регистрации)

При этом 8%-15% клиентов проявляют активность на горизонте больше 30 дней

Исходя из этого считаю, что сервису необходимо два вариант подписки: на 1 день и на 1 месяц.

Также можно рассмотреть промежуточные варианты (подписка на 3 дня и 2 недели)

#**Задание 2**
```SQL
with balance_table as (
	select
		user_id, 
		sum(
			case 
				when type_id in (1, 23, 24, 25, 26, 27, 28, 30) 
				    then -value 
				    else null 
				end
			) as write_off,
		sum(
			case 
				when type_id not in (1, 23, 24, 25, 26, 27, 28, 30) 
					then value 
					else null 
				end
			) as accrual,
		sum(
			case 
				when type_id not in (1, 23, 24, 25, 26, 27, 28, 30) 
					then value 
					else -value 
				end
			) as balance
	from "transaction" t 
	group by user_id 
)

select
	round(avg(write_off), 2) as write_off_per_user,
	round(avg(accrual), 2) as accrual_per_user,
	round(avg(balance), 2) as avg_balance,
	mode () within group (order by balance) as median_balance
from balance_table
```
***Результат***:

![image](https://github.com/FatPodobed/sf-final-project/assets/101504000/c97641ac-4707-44eb-9196-c39ab671fced)

***Выводы***: 

В среднем пользователи тратят ~70 coin-ов. 

Принимая во внимание, что медианный баланс пользователей = 53 coin-а, 
можно установить стоимость подписки в районе 120 coin-ов в рублёвом эквиваленте 

#**Задание 3**

*Решение задач*
```SQL
with problem_table as(
	select
		user_id,
		problem_id,
		count(*) as cnt,
		sum (is_false) as incorrect,
		count(*) - sum (is_false) as correct
	from codesubmit
	group by user_id, problem_id
)
select
	round(avg(cnt), 2) as avg_problem_attempt,
	round( avg(correct), 2) as avg_correct_problem
from problem_table 
```
![image](https://github.com/FatPodobed/sf-final-project/assets/101504000/4ee2442b-b8b2-46f0-85dd-a7a65a2091cb)


*Решение тестов*
```SQL
with test_table as(
	select
		user_id,
		count(distinct test_id) as test_per_user,
		count(test_id) as attempt_per_user
	from teststart t
	group by user_id 	
)
select
	round(AVG(test_per_user),2) as test_per_user,
	round(sum(attempt_per_user)/sum(test_per_user), 2) as attempt_per_test
from test_table
```
![image](https://github.com/FatPodobed/sf-final-project/assets/101504000/c2dcaf97-c8f3-41d1-a673-13608338c0ec)

*Какая доля от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест?*
```SQL
with target_users as (
	select 
		count( distinct u.id) as cnt_target 
	from 
		users u
	join 
		codesubmit c
	on 
		u.id = c.user_id
	join 
		teststart t
	on 
		t.user_id = u.id
	where 
		c.is_false = 0
	or 
		t.id notnull 
), 
total_users as (
	select 
		count(distinct id) as cnt_total
	from 
		users u2 
)
select 
	round(cnt_target*1.0/cnt_total*100, 2) as res
from 
	target_users, total_users 
```
![image](https://github.com/FatPodobed/sf-final-project/assets/101504000/41163835-55b1-4057-b624-98876cbac68c)

*Информация по покупкам материалов на платформе за кодкоины*
```SQL
with db as(
	select  
		t.user_id,
		tt.type,
		tt.description 
	from transaction t
	left join transactiontype tt
	on t.type_id = tt.type
) 
select
	count(distinct case when type = 23 then user_id else null end) as open_task_for_coins,
	count(distinct case when type = 27 then user_id else null end) as open_test_for_coins,
	count(distinct case when type = 24 then user_id else null end) as open_help_for_coins,
	count(distinct case when type = 25 then user_id else null end) as open_solution_for_coins,
	sum(case when type in (23, 24, 25, 27) then 1 else null end) as total_thngs_for_coin,
	count(distinct case when type in (23, 24, 25, 27) then user_id else null end) as open_smthng_for_coins,
	count(disti
```
![image](https://github.com/FatPodobed/sf-final-project/assets/101504000/92558dcb-5301-4534-b4df-40b07b3c8983)

***Выводы***: 
Самым популярным функционалом из платного является открытие тестов и задач, а также открытия решений к задачам
Этим функционалом пользовались ~22%, ~28% и ~6% активной базы соответсвенно
При этом открытием подсказок пользовалось меньше ~2%, поэтому его можно оставить бесплатным 


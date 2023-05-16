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

Большая часть клиентов проявляют активность в течении дня регистрации

(от ~60% до ~70% клиентов отваливаются через день после регистрации).

При этом 8%-15% клиентов проявляют активность на горизонте больше 30 дней

Исходя из этого считаю, что сервису необходимо два вариант подписки: на 1 день и на 1 месяц.

Также можно рассмотреть промежуточные варианты (подписка на 3 дня и 2 недели).

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

В среднем за период анализа (11 месяцев) пользователи тратят ~70 coin-ов.

При этом 1 пользователю (за 11 месяцев ) в среднем начисленно ~307 coin-ов, 

а медианный баланс пользователей = 53 coin-а.

Данных для расчёта стоимости подписки недостаточно. Дальнейший анализ представлен в блоке доп. заданий.  

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
Самым популярным функционалом из платного является открытие тестов и задач, а также открытия решений к задачам.
Этим функционалом пользовались ~22%, ~28% и ~6% активной базы соответсвенно.
При этом открытием подсказок пользовалось меньше ~2%, поэтому его можно оставить бесплатным.

#**Дополнительное задание**

Мне кажется, что для принятия решения о стоимости и длительности подписки нехватает данных

Поэтому я сделал доп. расчёты

*Среднемесячные списания*

```SQL
with transactions_base as(
	select
		t.id as t_id, 
		to_char(t.created_at, 'YYYY-MM') as transaction_date,
		tt.type as type_id,
		tt.description,
		t.value,
		u.id as user_id
	from 
		"transaction" t
	left join 
		transactiontype tt
	on 
		t.type_id = tt."type"
	full join 
		users u
	on u.id = t.user_id
	where to_char(t.created_at, 'YYYY') >= '2022'
)
select
	transaction_date,
	count(distinct user_id) as spending_users_number,
	sum(value) as total_spend,
	round(avg(value), 2) as avg_spend_amount
from transactions_base
where type_id in (1, 23, 24, 25, 26, 27, 28, 30)
group by transaction_date  

```
![image](https://github.com/FatPodobed/sf-final-project/assets/101504000/25d60a01-676c-488c-a515-72dd6bdceb24)


За последние 5 месяцев видно, что средние траты ползьователей находятся в диапазоне от ~22 до ~25 coin-ов

Этот диапазон можно использовать для формирования стоимости подписки на месяц.

*Среднемесячные пополнения кошелька*

```SQL
with transactions_base as(
	select
		t.id as t_id, 
		to_char(t.created_at, 'YYYY-MM') as transaction_date,
		tt.type as type_id,
		tt.description,
		t.value,
		u.id as user_id
	from 
		"transaction" t
	left join 
		transactiontype tt
	on 
		t.type_id = tt."type"
	full join 
		users u
	on u.id = t.user_id
	where to_char(t.created_at, 'YYYY') >= '2022'
)
select
	transaction_date,
	count(distinct user_id) as paying_users_number,
	sum(value) as total_payments,
	avg(value) as avg_payment_amount
from transactions_base
where type_id = 2
group by transaction_date 
```
![image](https://github.com/FatPodobed/sf-final-project/assets/101504000/e29dac7d-f414-4ae0-91d7-de1c9fbb0522)

За период с февраля по апрель 22 пользователи пополняли кошелёк на сумму в диапазоне от 250 до 400 coin-ов (296) в среднем

Учитывая, что в среднем в месяц тратится 22-25 coin-ов, то этой суммы хватит на 12 месяцев.

При этом в январе пользователи пополнели кошельки в среднем на 100 coin-ов (хватит ~ на 4 месяца).

Исходя из этого можно рассмотреть вариант добавления подписки на год и полгода(на 3 месяца).

*Популярность задач пополнения кошелька*

```SQL
with a as (
	select
		c.problem_id,
		count(distinct c.user_id) as user_per_problem	 
	from codesubmit c
	group by problem_id
	order by count(distinct user_id ) desc
)
select 
	a.problem_id,
	p.name,	
	a.user_per_problem
from a
left join problem p
on p.id = a.problem_id
order by user_per_problem desc
```

![image](https://github.com/FatPodobed/sf-final-project/assets/101504000/0ecad04b-c65e-4354-be07-3328e283e944)

Также можно рассмотреть вариант продажи отдельных задач (или продажи решений, подсказок и т.д. для них).  

Для этого я посчитал, сколько человек дедлали подход к каждой задаче.

**Итоговые выводы**

При переходя на подписочную систему, рекомендую: 

- Установить подписки на 1-3 дня, 1 месяц, полгода и год. Это обусловлено активностью ползьователей (см. кагортный анализ)
и совокупностью средннемесячных трат и пополнений (доп. задачи) 

- Установить стоимость подписки исходя из 20 - 25 codecoin-ов в месяц в рублёвом эквиваленте

- Рекомендую наполнить подписку самым востребованным функционалом (см. задачу 3), таким как платные задачи, платные тесты и решения задач.

- Также можно рассмотреть вариант продажи отдельных задач (или решений и подсказок к ним) из числа самых популярных (см. доп задачу)  


#**Дополнительное задание 2**

***Для выгрузки данных используем SQL-запрос:*** 

```SQL
with db as(
	select
		row_number() over () as act_id, 
	  	coalesce (cr.created_at, t.created_at, cs.created_at) as date_time
	from codesubmit cs
	full join coderun cr
	on cr.created_at = cs.created_at 
	full join teststart t 
	on t.created_at = cr.created_at  
), db2 as(
	select 
	act_id,
	extract(isodow from date_time) as iso_dow,
	extract(hour from date_time) as day_hour
from db
)
 select
 	iso_dow,
 	day_hour, 
 	count (act_id)
 from db2
 group by iso_dow, day_hour
 order by iso_dow, day_hour
```

***Для загрузки данных и построения графика используем такой код:*** 

```Python
import numpy as np

import pandas as pd

import matplotlib.pyplot as plt


df = pd.read_csv(
    r'C:\Users\Dibod\OneDrive\Рабочий стол\DS SF\4. Python\6. Сквозной проект\Project_SF.CSV', 
    sep = ';'
)
df


monday = df[
    df['iso_dow'] == 1
]
tuesday = df[
    df['iso_dow'] == 2
]
wednsday = df[
    df['iso_dow'] == 3
]
thursday = df[
    df['iso_dow'] == 4
]
friday = df[
    df['iso_dow'] == 5
]
saturday = df[
    df['iso_dow'] == 6
]
sunday = df[
    df['iso_dow'] == 7
]

plt.rcParams['figure.figsize'] = (18, 16)

plt.subplot(4,2,1)
plt.plot(
    monday['day_hour'], 
    monday['count'], 
    ':', 
    marker = 'o', 
    color = '#d1b26f'
)
plt.ylabel(
    'Понедельник', 
    fontsize = 14
)
plt.xticks(np.arange(0, 24, 1))

plt.subplot(4,2,2)
plt.plot(
    tuesday['day_hour'], 
    tuesday['count'], 
    ':', 
    marker = 'o', 
    color = '#6b8ba4'
)
plt.ylabel(
    'Вторник', 
    fontsize = 14
)
plt.xticks(np.arange(0, 24, 1))

plt.subplot(4,2,3)
plt.plot(
    wednsday['day_hour'], 
    wednsday['count'], 
    ':', 
    marker = 'o', 
    color = '#526525'
)
plt.ylabel(
    'Среда', 
    fontsize = 14
)
plt.xticks(np.arange(0, 24, 1))

plt.subplot(4,2,4)
plt.plot(
    thursday['day_hour'], 
    thursday['count'], 
    ':', 
    marker = 'o', 
    color = '#4e7496'
)
plt.ylabel(
    'Четверг', 
    fontsize = 14
)
plt.xticks(np.arange(0, 24, 1))

plt.subplot(4,2,5)
plt.plot(
    friday['day_hour'], 
    friday['count'], 
    ':', 
    marker = 'o', 
    color = '#25a36f'
)
plt.ylabel(
    'Пятница', 
    fontsize = 14
)
plt.xticks(np.arange(0, 24, 1))

plt.subplot(4,2,6)
plt.plot(
    saturday['day_hour'], 
    saturday['count'], 
    ':', 
    marker = 'o', 
    color = '#01386a'
)
plt.ylabel(
    'Суббота', 
    fontsize = 14
)
plt.xticks(np.arange(0, 24, 1))

plt.subplot(4,2,7)
plt.plot(
    sunday['day_hour'], 
    sunday['count'], 
    ':', 
    marker = 'o', 
    color = '#728639'
)
plt.ylabel(
    'Воскресенье', 
    fontsize = 14
)
plt.xticks(np.arange(0, 24, 1))
```

![image](https://github.com/FatPodobed/sf-final-project/assets/101504000/da4898e9-4abb-41b6-a55c-55f9c4bde347)

![image](https://github.com/FatPodobed/sf-final-project/assets/101504000/c7333afa-48cf-43aa-9138-d924c0b86045)

Рекомендую проводить релизы в воскресенье с 1 до 3 часов утра, потому что в это время наблюдается наименьшая активность пользователей.


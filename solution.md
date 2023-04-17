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
Полученная информация позволяет дать ответ на вопрос о вариантах подписки с точки зрения продолжительности обучения.
Наивысшая активность пользователей - в течение первых двух недель после регистрации на платформе (в среднем заходит на платформу более трети от зарегистрировавшихся пользователей). 
По истечении месяца после регистрации на платформу возвращается порядка 20% пользователей, двух месяцев - порядка 15% пользователей, трех месяцев - 8% пользователей. 
Подобная динамика позволяет сделать вывод о целесообразности формирования подписки на месяц, при этом годовая подписка может стать менее интересным вариантом для потенциальных клиентов.


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

Полученная информация позволяет подтвердить тезис о недостатках текущей системы монетизации: пользователи действительно списывают меньше монет, чем приобретают.


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
ВЫВОД:
Полученная информация позволяет ответить на вопрос о том, что стоит включать в состав подписки. Так, наиболее популярная покупка пользователя - задачи (ряд задач можно оставить исключительно в платной подписке). Кроме того, задачи не решаются пользователями с первой попытки (среднее количество попыток - 3), и для решения задач пользователи используют подсказки. Таким образом, возможность открытия подсказок / решений становится отличительной особенноситю платной подписки.


ДОПОЛНИТЕЛЬНОЕ ЗАДАНИЕ 1 (дополнительные метрики):

ВЫВОДЫ:

На платформе IT Resume уже отражены варианты подписки: демо, годовая и месячная. Там же указаны преимущества платных подписок - в том числе возможность решения дополнительных задач, использования подсказок и разборов (выводы о целесообразности подобных функций в составе платной подписке подтверждаются данными, анализ которых осуществляется в рамках указанной работы).

Необходимо отметить, что согласно расчетам Rolling Retention отмечается стабильное снижение активности пользователей с увеличением срока их регистрации (пик активности - первый месяц после дня регистрации на платформе, по итогам 3 месяцев на платформу возвращается менее 10% пользователей). В таком случае вопрос целесообразности включения годовой подписки требует дополнительного обоснования. 
Вместе с тем подобная динамика характерна не для всех пользователей.
Так, существует ряд пользователей, активность которых значительно выше средней (это пользователи, связанные с "компаниями" - возможно, корпоративные клиенты).
Такие пользователи-корпоративные клиенты сохраняют более высокую активность (возвращаемость) на портал с течением времени: по истечении месяца на портал возвращается почти половина клиентов (в отличие от средней активности всех пользователей, которая составляет порядка 20% по истечение месяца), по итогам 3 месяцев на платформу возвращается более 20% таких пользователей (против 8% в обобщенной выборке по всем пользователям). Кроме того, такие пользователи решают в среднем больше задач (23 задачи у пользователей-корпоративнымх клиентов, против 8 задач у всех пользователей в среднем), аналогичная динамика прослеживается в прохождении тестов.

Указанная тенденция подтверждается результатами следующих выборок:

1) активность с течением времени:
with base as 
    (select user_id, company_id,
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
where company_id is not NULL
group by ym
order by ym

2) активность в решении задач:
with base as
	(select user_id, company_id, count(distinct c.problem_id) as summ_tasks
	from coderun c
	left join users u 
	on u.id = c.user_id 
	group by user_id, company_id
	order by user_id ) 
select round(avg(summ_tasks),1) as avg_tasks
from base
where company_id is not null

3) активность в прохождении тестов:
with base as
	(select user_id, company_id, count(distinct t.test_id) as summ_tasks
	from teststart t
	left join users u 
	on u.id = t.user_id 
	group by user_id, company_id
	order by user_id ) 
select round(avg(summ_tasks),1) as avg_tasks
from base
where company_id is not null

Таким образом, годовая / полугодовая подписка может быть интересна именно корпоративным пользователям - компаниям, заинтересованным в развитии сотрудников. В свою очередь одним из факторов, способных привлечь компании на платформу, может являться вывод: пользователи, ассоциированные с компаниями, действительно активны  - отрабатывают обучение качественно, заинтересованы в решении задач, возвращаются на платформу.
Также можно отметить, что доля таких пользователей на платформе невелика (порядка 9%). Наращивание доли корпоративных клиентов может способствовать развитию платформы и формированию стабильных продолжительных денежных поступлений.


ДОПОЛНИТЕЛЬНОЕ ЗАДАНИЕ 2:

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

ВЫГРУЗКА ДАННЫХ ДЛЯ ПОСТРОЕНИЯ ГРАФИКОВ:

1) активность пользователей по дням недели:
import pandas as pd
import matplotlib.pyplot as plt
df_days = pd.read_csv("../Final_task/Activity_days.csv")
plt.plot(df_days)
plt.title('Активность пользователей в течение недели', fontsize=15, fontweight='bold')
plt.xlabel('Дни', fontsize=15, color='red')
plt.ylabel('Пользователи', fontsize=15, color='red')
plt.xticks(rotation=90)
plt.grid(True)
plt.show()

2) активность пользователей по времени суток:
df_time = pd.read_csv("../Final_task/Activity_time.csv")
df_time = df_time.T
plt.plot(df_time)
plt.title('Активность пользователей в течение cуток', fontsize=15, fontweight='bold')
plt.xlabel('Часть дня', fontsize=15, color='red')
plt.ylabel('Пользователи', fontsize=15, color='red')
plt.xticks(rotation=90)
plt.grid(True)
plt.show()

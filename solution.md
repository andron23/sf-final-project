-- ЗАДАНИЕ 1
-- Берем только 2022 год в анализ, т.к. для 2021 года данные не везде являются корректными - некоторые даты входов раньше дат регистрации
with a as (
	select 
		u2.id, 
		to_char(u2.date_joined, 'YYYY-MM') as cohort, 
		extract (days from u1.entry_at - u2.date_joined) as diff
	from userentry u1
	join users u2
	on u1.user_id = u2.id
	where to_char(u2.date_joined, 'YYYY-MM') >= '2022-01'
)
select 
	cohort,
	count (distinct case when diff >= 0 then id end)*100.0 / count (distinct case when diff >= 0 then id end) as "0 day",
	round (count (distinct case when diff >= 1 then id end)*100.0 / count (distinct case when diff >= 0 then id end),2) as "1 day",
	round (count (distinct case when diff >= 3 then id end)*100.0 / count (distinct case when diff >= 0 then id end),2) as "3 day",
	round (count (distinct case when diff >= 7 then id end)*100.0 / count (distinct case when diff >= 0 then id end),2) as "7 day",
	round (count (distinct case when diff >= 14 then id end)*100.0 / count (distinct case when diff >= 0 then id end),2) as "14 day",
	round (count (distinct case when diff >= 30 then id end)*100.0 / count (distinct case when diff >= 0 then id end),2) as "30 day",
	round (count (distinct case when diff >= 60 then id end)*100.0 / count (distinct case when diff >= 0 then id end),2) as "60 day",
	round (count (distinct case when diff >= 90 then id end)*100.0 / count (distinct case when diff >= 0 then id end),2) as "90 day"
from a
group by cohort

--Выводы: По результатам анализа rolling retention можно сделать вывод о том, что пользователи активно заходят на платформу первые несколько дней. 
--Основной интерес наблюдается в первые 3 дня. В этой связи кажется целесообразным рассмотреть краткосрочную подписку (возможно, пользователю нужны задачи 
--на определенную тему, либо он готовится к предстоящему собеседованию, либо у него есть только выходные, чтобы попрактиковаться) – допустим, на 1 или 3 дня. 
--Далее можно рассмотреть более длительный период – например, 14 и 30 дней. Пользователям, для которых в приоритете постоянное саморазвитие, можно предусмотреть 
--подписку сроком на полгода и год. В последнем случае целесообразно предложить хорошую скидку – скорее всего, многие пользователи перестанут заходить на платформу 
--к концу срока (это видно и из результатов анализа rolling retention), однако акцент на постоянном саморазвитии и скидке обычно отлично срабатывает при продаже.

-- ЗАДАНИЕ 2
with a as (
	select 
		user_id, 
		sum(case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then value else 0 end) as debit,
		sum(case when type_id not in (1, 23, 24, 25, 26, 27, 28, 30) then value else 0 end) as accrual
	from transaction t 
	group by user_id
)
select 
	avg(accrual) as accrual_avg, 
	avg(debit) as debit_avg, 
	avg(accrual-debit) as balance, 
	percentile_cont(0.5) within group (order by (accrual-debit)) as balance_median
from a

--Выводы: По результатам анализа метрик относительно баланса пользователя можно сделать вывод о том, что коинов начисляется значительно больше, чем списывается 
--(почти в 10 раз: 306,52 / 31,29). У активных пользователей много коинов, поэтому наблюдаются высокие показатели среднего начисления и среднего баланса. 
--В то же время, видим большую разницу между средним и медианным балансом – есть выбросы (активные пользователи, у которых большие начисления коинов).
--Ввиду невысокой заинтересованности пользователей в трате коинов идея о смене модели монетизации на платформе является целесообразной. 
--Если оставлять модель без изменений, то необходимо предпринять действия, направленные на повышение заинтересованности пользователей в использовании коинов. 

--Если рассматривать варианты подписок на разные сроки, то, отталкиваясь от медианного баланса (цена должна быть комфортной для большинства пользователей), 
--можно рассмотреть для краткосрочной подписки (до 3 дней) стоимость в районе 50 коинов в пересчете на рубли, в районе 150 коинов – на 14 дней, 200 коинов – на месяц и т.д. 
--Также можно рассмотреть варианты различных цен для ограниченного и полного доступа к платформе. Кроме того, не будет лишним ознакомиться с предложениями конкурентов, 
--чтобы цена была «в рынке». После установления цен необходимо наблюдать за динамикой активности пользователей платформы, чтобы отследить эффект от нововведений, 
--в зависимости от данного эффекта запланировать пересмотр цен на следующем этапе.

-- ЗАДАНИЕ 3

--Метрика 1: Сколько в среднем пользователь решает задач
with a1 as(  				  
	select 
		user_id, 
		problem_id as cnt
	from coderun
	union						 
	select 
		user_id, 
		problem_id as cnt   
	from codesubmit
),
a2 as (
	select count(*) as cnt     	
	from a1
	group by user_id
)
select round(avg(cnt), 2) as problems_avg
from a2
--Вывод: Пользователь решает в среднем примерно 9.18 задач

--Метрика 2: Сколько в среднем пользователь делает попыток для решения 1 задачи
with b as (
	select 
		user_id, 
		problem_id, 
		count(problem_id) as cnt1
	from codesubmit c
	group by user_id, problem_id
	union
	select 
		user_id, 
		problem_id, 
		count(problem_id) as cnt1
	from coderun c1
	group by user_id, problem_id
)
select round(avg(cnt1),2) as att_problem_avg
from b
--Вывод: Пользователь делает примерно 5.75 попыток для решения 1 задачи 

--Метрика 3: Сколько в среднем пользователь проходит тестов
with c as (
	select 
		user_id, 
		count(distinct test_id) as cnt3
	from teststart t 
	group by user_id
)
select round(avg(cnt3),2) as tests_avg
from c
--Вывод: Пользователь проходит в среднем 1,68 тестов

--Метрика 4: Сколько в среднем пользователь делает попыток для прохождения 1 теста
with d as (
	select 
		user_id, 
		test_id, 
		count(test_id) as cnt4
	from teststart t 
	group by user_id, test_id
)
select round(avg(cnt4),2) as att_tests_avg
from d
--Вывод: Пользователь в среднем делает 1.26 попыток для прохождения 1 теста

--Метрика 5: Какая доля от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест
with e as (
	select distinct user_id
	from codesubmit
	union
	select distinct user_id
	from coderun
	union
	select distinct user_id
	from teststart

 
)
select round(count(*) *100.0 / (select count(*) from users),2) as active_users_share
from e
--Вывод: Доля пользователей, которые решали хотя бы одну задачу или начинали проходить хотя бы один тест от общего числа пользователей - 63.48%

--ДОПОЛНИТЕЛЬНОЕ ЗАДАНИЕ
--Предлагаю рассмотреть дополнительные метрики:

--Если я правильно понимаю, то в поле referal_user в таблице users содержится информация о пользователях, которые воспользовались реферальной программой
--Проанализируем долю пользователей, которые пришли на платформу благодаря реферальной программе
with t as (
	select id, referal_user 
	from users u 
	where referal_user>0
)
select count (id)*100.0 / (select count(*) from users) as share_ref
from t
--Вывод: Видим, что доля пользователей, которые пришли на платформу благодаря реферальной программе, невысокая (менее 3%)
--Рекомендуется рассмотреть варианты улучшения реферальной программы для того, чтобы привлекать больше новых пользователей

--Если я правильно понимаю, то в поле company_id в таблице users содержится информация о пользователях, связанных с компаниями (корпоративные клиенты)
--Проанализируем активность пользователей, связанных с компаниями

--Добавим в когортный анализ возможность рассмотрения данных при условии группировки по company_id:
with a as (
	select 
		company_id,
		u2.id, 
		to_char(u2.date_joined, 'YYYY-MM') as cohort, 
		extract (days from u1.entry_at - u2.date_joined) as diff
	from userentry u1
	join users u2
	on u1.user_id = u2.id
	where to_char(u2.date_joined, 'YYYY-MM') >= '2022-01'
)
select 
	cohort,
	company_id,
	count (distinct case when diff >= 0 then id end)*100.0 / count (distinct case when diff >= 0 then id end) as "0 day",
	round (count (distinct case when diff >= 1 then id end)*100.0 / count (distinct case when diff >= 0 then id end),2) as "1 day",
	round (count (distinct case when diff >= 3 then id end)*100.0 / count (distinct case when diff >= 0 then id end),2) as "3 day",
	round (count (distinct case when diff >= 7 then id end)*100.0 / count (distinct case when diff >= 0 then id end),2) as "7 day",
	round (count (distinct case when diff >= 14 then id end)*100.0 / count (distinct case when diff >= 0 then id end),2) as "14 day",
	round (count (distinct case when diff >= 30 then id end)*100.0 / count (distinct case when diff >= 0 then id end),2) as "30 day",
	round (count (distinct case when diff >= 60 then id end)*100.0 / count (distinct case when diff >= 0 then id end),2) as "60 day",
	round (count (distinct case when diff >= 90 then id end)*100.0 / count (distinct case when diff >= 0 then id end),2) as "90 day"
from a
group by cohort, company_id
--Вывод: Видим, что retention у пользователей с ненулевым company_id выше

--Также добавим в анализ количества решаемых задач возможность рассмотрения данных при условии группировки по company_id:
with t as
	(select user_id, company_id, count(distinct c.problem_id) as cnt
	from coderun c
	left join users u 
	on u.id = c.user_id 
	group by user_id, company_id
	order by user_id 
) 
select company_id, round(avg(cnt),1) as problems_avg
from t
group by company_id
--Вывод: Видим, что в большинстве случаев среднее количество задач у пользователей с ненулевым company_id выше

with t as (
	select distinct user_id, company_id
	from userentry u 
	join users u2 
	on u.user_id = u2.id
	where company_id>0
	order by user_id
)
select count (user_id)*100.0 / (select count(*) from users) as share_company
from t
--Доля таких клиентов на текущий момент составляет менее 9%. Пользователи с ненулевым company_id проявляют себя наиболее активно на платформе, но доля таких клиентов
--не велика. В связи с этим можно сделать вывод о том, что в данном случае целесообразно развивать бизнес-отношения с корпоративными клиентами и 
--продавать им долгосрочные подписки (на полгода, год)

--Также можно выполнить анализ количества регистраций и входов пользователей по месяцам для того, чтобы выявить периоды, 
--когда необходимо простимулировать потенциальных клиентов к покупке подписки

with t1 as (
	select 
		to_char(date_joined, 'YYYY-MM') as month, 
		count(id) as joined_cnt
	from users
	group by month
	order by month
),
t2 as (
	select 
		to_char(entry_at, 'YYYY-MM') as month, 
		count(distinct user_id) as entry_cnt
	from userentry
	group by month
	order by month
)
select 
	t1.month,  
	coalesce(joined_cnt,0) as joined_cnt, 
	coalesce(entry_cnt,0) as entry_cnt
from t1
full join t2
on t1.month=t2.month
order by t1.month

--Данных пока не так много, но очевиден спад в период с мая по август, что логично (подобным направлениям бизнеса свойственна такая картина в период отпусков и каникул). 
--Можно порекомендовать запуск акций, скидок в данный период.
--Также видим резкий скачок количества регистраций и входов в феврале 2022 года. Нужно проанализовать причины данного скачка. Возможно, была запущена какая-то выгодная акция,
--которую надо будет повторять время от времени для привлечения новых клиентов. Возможно, здесь были задействованы внешние факторы, подтолкнувшие людей, которые давно
--задумывались о начале обучения или о смене профессии, наконец приступить к задуманному.



------------------------------------------Итоговые выводы по смене модели монетизации
--По результатам анализа очевидно, что модель должна быть изменена (в частности, из-за невысокой заинтересованности пользователей в трате коинов).
--Если оставлять модель без изменений, то необходимо предпринять действия, направленные на повышение заинтересованности пользователей в использовании коинов. 
--Необходимо рассмотреть различные варианты подписок (по сроку и наполнению).
--Стоимость подписки можно определить, отталкиваясь от медианного баланса. 
--Необходимо наблюдать за динамикой активности пользователей платформы, чтобы отследить эффект от нововведений, и в зависимости от данного эффекта запланировать пересмотр цен на следующем этапе.
--Рекомендуется провести работу по привлечению новых пользователей (в частности, корпоративных).
--Рекомендуется рассмотреть запуск акций и скидок в периоды спада активности

-- Дополнительное задание 2

--Для выгрузки данных используем SQL-запрос:
with t as (
	select created_at
	from codesubmit
	union
	select created_at
	from coderun
	union
	select created_at
	from teststart
)
select 
	distinct(to_char(created_at, 'HH24:00')) as hour,
	count(case when to_char(created_at, 'dy') ='mon' then created_at else null end) as mon,
	count(case when to_char(created_at, 'dy') ='tue' then created_at else null end) as tue,
	count(case when to_char(created_at, 'dy') ='wed' then created_at else null end) as wed,
	count(case when to_char(created_at, 'dy') ='thu' then created_at else null end) as thu,
	count(case when to_char(created_at, 'dy') ='fri' then created_at else null end) as fri,
	count(case when to_char(created_at, 'dy') ='sat' then created_at else null end) as sat,
	count(case when to_char(created_at, 'dy') ='sun' then created_at else null end) as sun
from t
group by hour
order by hour


#Для загрузки данных и построения графика используем такой код в Python:
import pandas as pd
import matplotlib.pyplot as plt
df = pd.read_csv('activity_export.csv')
df.head()
#прочитали файл, посмотрели, всё ли ок в таблице
#рисуем 7 графиков (для каждого дня недели), чтобы наглядно была видна динамика активности пользователей (ось y) в каждый день в разбивке по часам (ось x)
plt.figure(figsize=(10, 5))
for column in df.columns:
    plt.plot(df.index, df[column], label=column)
plt.title('Number of users per time and days of the week')
plt.legend(title='days')
plt.xlabel('time')
plt.ylabel('users')
plt.grid(True)
plt.xticks(rotation=90)
plt.show()

#Выводы:
#Пользователи проявляют активность на платформе чаще всего в будние дни (можно выделить четверг), реже всего - в выходные.
#Наименьшая активность наблюдается в ночные часы (с 0 до 3 часов), наибольшая - в дневные (примерно с 10 до 14 часов в будни и с 13 до 15 в выходные). 
#В будние дни также наблюдается рост активности утром (в районе 8 часов) и вечером (в районе 18 часов).
#Рекомендуется производить релизы (выкатывать новый функционал на платформу) в выходные в ночные часы, поскольку в это время активность пользователей платформы минимальна
![Python_plot](https://github.com/user-attachments/assets/7a1cd0c2-d0ee-45ff-bcae-6688bd09fa31)

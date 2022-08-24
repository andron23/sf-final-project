### **Задание 1**
+ Расчет rolling retention с разбивкой по когортам. В качестве когорт взят месяц регистрации на платформе. В качестве n-дней - 1, 3, 7, 14, 30, 60 и 90 дней.
```sql
with view as (
	select user_id, 
		   to_char(date_joined, 'YYYY-MM') as dt,
		   date(entry_at) - date(date_joined) as df_days
		from users u 
		join userentry u2 
			on (u.id = u2.user_id)
	    where to_char(date_joined, 'YYYY') = '2022'
)
select a.dt as yw,
	   round(100.0 * count(distinct case when df_days >= 1 then user_id end) / day0, 2) as day1,
	   round(100.0 * count(distinct case when df_days >= 3 then user_id end) / day0, 2) as day3,
	   round(100.0 * count(distinct case when df_days >= 7 then user_id end) / day0, 2) as day7,
	   round(100.0 * count(distinct case when df_days >= 14 then user_id end) / day0, 2) as day14,
	   round(100.0 * count(distinct case when df_days >= 30 then user_id end) / day0, 2) as day30,
	   round(100.0 * count(distinct case when df_days >= 60 then user_id end) / day0, 2) as day60,
	   round(100.0 * count(distinct case when df_days >= 90 then user_id end) / day0, 2) as day90 
	from view a
	join (select dt, count(distinct case when df_days >= 0 then user_id end) as day0
	      from view
	      group by dt) b
		on (a.dt = b.dt)
	group by a.dt, day0
```
---
### **Задание 2**
+ Cколько в среднем коинов списывает 1 человек
+ Cколько в среднем коинов начисляется 1 человеку
+ Какой средний баланс среди всех пользователей
+ Какой медианный баланс среди всех пользователей
```sql
--Все метрики посчитаны в одном запросе--

with task2 as (
	select user_id, 
	   	   sum(case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then value else 0 end) as spisanie,
	       sum(case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then 0 else value end) as nachislenie,
	       sum(case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then -value else value end) as avg_balance
        from "transaction" t 
	   group by user_id
)
select round(avg(spisanie), 2) as avg_spisanie, --Среднее списание-- 
       round(avg(nachislenie), 2) as avg_nachislenie, --Среднее начисление--
       round(avg(avg_balance), 2) as avg_balance, --Средний баланс всех пользователей-- 
       percentile_cont(0.5) within group (order by avg_balance) as median_balance --Медианный баланс--
	from task2;
```
---
### **Задание 3**
+ Сколько в среднем пользователь решает задач (без учета правильно/неправильно)
```sql
with view1 as (  				  
	(select user_id, 
		    problem_id as cnt
		from coderun)
		
	   union						 
	   
	(select user_id, 
	        problem_id as cnt   
		from codesubmit)
)

select round(avg(cnt), 2) as avg_task 
	from (select count(*) as cnt     	
		      from view1
	         group by user_id) a;	

```
+ Сколько в среднем пользователь проходит тестов
```sql
with view2 as (
	select count(*) as cnt 
		from teststart		
	   group by user_id 
)
select round(avg(cnt), 2) as avg_tests
	from view2;
```
+ Сколько в среднем пользователь делает попыток для решения 1 задачи
```sql
with view3 as (
	select count(*) - sum(is_false) as count_attemps_user
		from codesubmit
	   group by user_id, problem_id 
)
select round(avg(count_attemps_user), 2) as avg_count_attemps
	from view3;
```
+ Сколько в среднем пользователь делает попыток для прохождения 1 теста
```sql
with view4 as (
	select count(answer_id) as cnt
		from testresult t 
	   group by user_id, test_id 
)
select round(avg(cnt), 2) as avg_attemps_for_one_test 
	from view4;
```
#### **Дополнительно к 3 заданию:**
+ Какая доля от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест
```sql
with view as (
    select distinct user_id
	    from codesubmit
	   union
	select distinct user_id                   
	    from coderun c 
	   union
	select distinct user_id 
	    from teststart
)
select round(count(*) / (select count(*) from users)::numeric * 100, 2) as percent_share   
	from view
```
+ Следующие метрики описывают количество людей, которые использовали кодкоины для покупки задач и т.д.
```sql
with view as (
	select distinct user_id, 
		   type_id 
		from transaction
)
select count(case when type = 23 then 1 end) as tasks, --кол-во людей, открывших задачи за кодкоины--
	   count(case when type in (26, 27) then 1 end) as tests, --кол-во людей, открывших тесты за кодкоины-- 
	   count(case when type = 24 then 1 end) as hints, --кол-во людей, открывших подсказки за кодкоины-- 
	   count(case when type = 25 then 1 end) as solutions, --кол-во людей, открывших решения за кодкоины--
	   count(case when type in (23, 24, 25, 26, 27) then 1 end) as cnt_people --кол-во людей, которые покупали --
	from view t                                                               --хоть что-то из перечисленного--
	join transactiontype t2 
		on (t.type_id = t2."type")
```
+ Сколько подсказок/тестов/задач/решений было открыто за кодкоины
```sql
select count(case when type = 24 then 1 end) as hints, --кол-во подсказок--
	   count(case when type in (26, 27) then 1 end) as tests, --кол-во тестов--
	   count(case when type = 23 then 1 end) as tasks, --кол-во задач--
	   count(case when type = 25 then 1 end) as solutions --кол-во решений--
	from "transaction" t 
	join transactiontype t2 
		on (t.type_id = t2."type")
```
+ Количество людей, которые имеют хотя бы 1 транзакцию (любую)
```sql
select count(distinct user_id) as cnt_people
	from "transaction" t 
   where type_id is not null
```
---
### **Дополнительное задание №1**
Мне кажется в качестве дополнительных метрик подойдут:
+ 1 метрика - **MAU (monthly active users)** <p>Данная метрика показывает количество уникальных клиентов, проявляющих активность в течение месяца</p>

```sql
with mau as(   
	select count(distinct(user_id)) as cnt, 
		   to_char(entry_at, 'Month') as mon 
		from userentry
	   group by mon
)
select avg(cnt) as mau 
	from mau
```
+ 2 метрика - **CR (conversation rate)** <p>Данная метрика
вычисляет коэффициент конверсии, который показывает отношение
числа посетителей сайта, <br>выполнивших на нем какие-то действия 
(в нашем случае покупки), к общему числу посетителей.
<br>Результат представлен в %.</p>

```sql
with view as(   
	select count(distinct(user_id)) as cnt, 
		   to_char(entry_at, 'YYYY-MON') as dt
		from userentry
	   group by dt
)
select a.dt, round(b.cn / a.cnt :: numeric * 100, 2) as cr
	from view a 
	join (select count(distinct user_id) as cn, 
	             to_char(created_at, 'YYYY-MON') as dt
		      from "transaction"                             
		     where type_id in (1, 23, 24, 25, 26, 27, 28, 30)
	         group by dt									 
	         order by dt) b 
        on (a.dt = b.dt)
```
+ 3 метрика - **Наиболее популярный стек технологий среди пользователей платформы**.<p>
Данная метрика показывает количество людей использующих Sql и Python одновременно, 
а также по отдельности.
<br>(Sql и Python, представленный стек технологий на платформе на данный момент).

```sql
--Количество пользователей, которые используют sql и python в решении задач одновременно--

select count(distinct a.user_id) 
	from (select user_id
		      from "language" l
	          join coderun c
		          on (l.id = c.language_id)
	         where l."name" = 'SQL') a  
    join (select user_id
	          from "language" l
	          join coderun c
		          on (l.id = c.language_id)
	         where l."name" = 'Python') b 
	    on (a.user_id = b.user_id)
```
```sql
--Количество пользователей, использующих sql, а также количество пользователей, использующих python--

select count(distinct case when name = 'SQL' then user_id end) as sql_cnt,
       count(distinct case when name = 'Python' then user_id end) as python_cnt 
	from "language" l 
	join coderun c 
		on (l.id = c.language_id)
```

#### **Итоговые выводы по смене модели монетизации**
> Я считаю, что для вашей компании подойдут несколько моделей монетизации:
>> 1. Freemium. <br>Суть данной модели заключается в бесплатном предоставлении пробной (базовой) версии продукта, <br>за дальнейшее использование (расширенный функционал) потребитель вносит плату. 
<br>Данный вариант интересен тем, что пользователь сможет протестировать функционал платформы и 
<br>в дальнейшем приобрести полный доступ ко всем продуктам.
<br>
<br> 2. Subscribe.
<br>Subscribe в качестве модели монетизации будет также рентабельна, 
потому что пользователь сможет <br>небольшими платежами вносить ежемесячную плату за подписку, 
что будет положительно влиять <br>на прибыль компании, из-за уменьшения оттока пользователей,
отказывающихся оплачивать <br>полную стоимость продукта сразу.
<br>
<br> Дополнение.
<br>Учитывая, что платформа активно развивается, в качестве совета ребятам из IT Resume, 
<br>я бы предложил в дальнейшем расширять стек предлагаемых технологий, чтобы развивать 
<br>коммьюнити платформы. Это будет способствовать узнаваемости компании и возможности 
<br>выхода на новые рынки.

<br>

---
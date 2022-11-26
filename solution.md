### **Задание 1**
+ Расчет rolling retention с разбивкой по когортам. В качестве когорт взят месяц регистрации на платформе. В качестве n-дней - 1, 3, 7, 14, 30, 60 и 90 дней.
```sql
with df as (
	select user_id, 
	   to_char(date_joined, 'YYYY-MM') as dt,
	   date(entry_at)-date(date_joined) as q_days
	from users u 
	join userentry u2 
	on (u.id = u2.user_id)
	where to_char(date_joined, 'YYYY-MM') > '2021-10'
	order by u2.user_id
)
select dt as yw,		
	round(count(distinct case when q_days >= 0 then user_id end) / count(distinct case when q_days >= 0 then user_id end), 2) as day0,
	round(100.0 * count(distinct case when q_days >= 1 then user_id end) / count(distinct case when q_days >= 0 then user_id end), 2) as day1,
	round(100.0 * count(distinct case when q_days >= 3 then user_id end) / count(distinct case when q_days >= 0 then user_id end), 2) as day3,
	round(100.0 * count(distinct case when q_days >= 7 then user_id end) / count(distinct case when q_days >= 0 then user_id end), 2) as day7,
	round(100.0 * count(distinct case when q_days >= 14 then user_id end) / count(distinct case when q_days >= 0 then user_id end), 2) as day14,
	round(100.0 * count(distinct case when q_days >= 30 then user_id end) / count(distinct case when q_days >= 0 then user_id end), 2) as day30,
	round(100.0 * count(distinct case when q_days >= 60 then user_id end) / count(distinct case when q_days >= 0 then user_id end), 2) as day60,
	round(100.0 * count(distinct case when q_days >= 90 then user_id end) / count(distinct case when q_days >= 0 then user_id end), 2) as day90
from df a
group by dt
```
Выводы: В среднем за последние 6 месяцев rolling retention в кагортах составил следующие значения:
- в 1-ый день в среднем возвращается 48% пользователей
- на 3-ий день в среднем возвращается 39% пользователей
- на 7-ой день в среднем возвращается 33% пользователей
- на 14-ый день в среднем возвращается 29% пользователей
- на 30-ый день в среднем возвращается 21% пользователей
- на 60-ый день в среднем возвращается 15% пользователей
- на 90-ый день в среднем возвращается 8% пользователей

До 14 дня мы удерживаем в среднем до 29% пользователей. При этом в период с 2021-11 до 22022-03 показатель  rolling retention падал. 
Для сравнения 2021-11 в 1 день возращалось 72% пользователей на 2022-03 показатель составил 35%, т.е показатель упал за 5 месяцев более  чем на 30%. Но в 2022-04 в 1 день показатель составил уже 48%


### **Задание 2**
+ Cколько в среднем коинов списывает 1 человек
+ Cколько в среднем коинов начисляется 1 человеку
+ Какой средний баланс среди всех пользователей
+ Какой медианный баланс среди всех пользователей
```sql
with t1 as (
	select user_id, 
	   sum(case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then value else 0 end) as spisanie,
	   sum(case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then 0 else value end) as nachislenie,
	   sum(case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then -value else value end) as avg_balance
	from "transaction" t 
	group by user_id
)
select 
	round(avg(spisanie), 2) as avg_spisanie, --Среднее списание-- 
    round(avg(nachislenie), 2) as avg_nachislenie, --Среднее начисление--
    round(avg(avg_balance), 2) as avg_balance, --Средний баланс всех пользователей-- 
    mode() WITHIN GROUP (ORDER BY avg_balance) as mode --Медианный баланс--
from t1;
```
Выводы: Средняя сумма начислений коинов составляет 307 в то время как сумма списаний около 31. Пользователи получают коины, но практически их не тратят. Необходимо больше платного контента.

### **Задание 3**
+ Сколько в среднем пользователь решает задач
```sql
with t1 as(  				  
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
t2 as (
	select count(*) as cnt     	
	from t1
	group by user_id
)
select round(avg(cnt), 2) as avg_task
from t2
```
Выводы: В среднем пользователь решает 9 задач

+ Сколько в среднем пользователь проходит тестов
```sql
with t1 as (
	select count(distinct test_id) as cnt 
	from teststart		
	group by user_id 
)
select round(avg(cnt), 2) as avg_tests
	from t1;
  ```
Выводы: В среднем пользователь проходит 2 теста

+ Сколько в среднем пользователь делает попыток для решения 1 задачи
```sql
with t1 as (
	select 
    user_id,
    problem_id,
    count(problem_id) as cnt
	from codesubmit c 
	group by user_id, problem_id
)
select round(avg(cnt),2) as avgTry
from t1;
```
Выводы: В среднем пльзователь решает задачу с 3 попытки

+ Сколько в среднем пользователь делает попыток для прохождения 1 теста
```sql
with t1 as (
	select user_id, count(test_id) as cnt
	from teststart t
	group by user_id, test_id
)
select round(avg(cnt), 2) as avg_attemps_for_one_test 
from t1;
```
Выводы: В среднем пользователю требуется 1 попытка для прохождения теста. 

+ Какая доля от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест
```sql
with t1 as (
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
from t1
```
Выводы: 63,5% от общего числа пользователей пытались решить хотя бы одну задачу или хотя бы один тест.

+ Открытие/покупка тестов, задач, подсказок и т.д.
```sql
with view as (
	select 
		distinct user_id, 
		type_id 
	from transaction
)
select 
	count(case when type = 23 then 1 end) as tasks, --Сколько человек открывало задачи за кодкоины--
	count(case when type in (26, 27) then 1 end) as tests, --Сколько человек открывало тесты за кодкоины-- 
	count(case when type = 24 then 1 end) as hints, --Сколько человек открывало подсказки за кодкоины-- 
	count(case when type = 25 then 1 end) as solutions, --кол-во людей, открывших решения за кодкоины--
	count(case when type in (23, 24, 25, 26, 27) then 1 end) as all, --Сколько человек покупало хотя бы что-то из вышеперечисленного--
	count(distinct user_id) as any_trancastion --Сколько человек всего имеют хотя бы 1 транзакцию--
from view t                                                               
join transactiontype t2 
on (t.type_id = t2.type)

select 
	count(case when type = 23 then 1 end) as tasks, --купленные задачи всего--
	count(case when type in (26, 27) then 1 end) as tests, --купленные тесты всего-- 
	count(case when type = 24 then 1 end) as hints, --купленные подсказки всего -- 
	count(case when type = 25 then 1 end) as solutions, --купленные решения всего --
	count(case when type in (23, 24, 25, 26, 27) then 1 end) as all -- Сколько подсказок/тестов/задач/решений было открыто за кодкоины--
from transaction t 
join transactiontype t2 
on (t.type_id = t2.type)
```
	Выводы: 1402 человека купило на сайте что-либо, из них:
	- 522 человек купили задачи
	- 676 человек купили тесты
	- 53 человекакупили подсказки
	- 151 человек купили решения

	Так же всего было  3205 транзакций на покупку:
	- на  задачи 1 675 транзакций
	- на тесты 989 транзакций
	- на подсказки  118 транзакций
	- на решения 423 транзакций

**Задание №1:**
+   Расчет rolling retention с разбивкой по когортам. В качестве когорт взяты месяца регистрации и активности на платформе. 
+   В качестве n-дней: 0, 1, 3, 7, 14, 30, 60 и 90 дней.
+   Код решения (SQL):
+   with p1 as 
+       (
+       select
+       u.user_id,
+       to_char(u2.date_joined, 'YYYY-MM') as date_joined,
+       to_char(u.entry_at, 'YYYY-MM') as day_entry, 
+       date(u.entry_at) - date(u2.date_joined) as date_diff
+   from 
+       userentry u 
+   join users u2 
+   on u2.id=u.user_id
+   where to_char(u2.date_joined, 'YYYY')='2022'
+       ),
+   p2 as 
+       (
+       select 
+       user_id, date_joined, date_diff,
+       case when date_diff>=90 then 1 end as day90,
+       case when date_diff>=60 then 1 end as day60,
+       case when date_diff>=30 then 1 end as day30,
+       case when date_diff>=14 then 1 end as day14,
+       case when date_diff>=7 then 1 end as day7,
+       case when date_diff>=3 then 1 end as day3,
+       case when date_diff>=1 then 1 end as day1,
+       case when date_diff>=0 then 1 end as day0
+       from p1)
+   select date_joined,
+   round(count(day0)/count(day0), 2) as day0,
+   round(100*count(day1)/count(day0), 2) as day1,
+   round(100*count(day3)/count(day0), 2) as day3,
+   round(100*count(day7)/count(day0), 2) as day7,
+   round(100*count(day14)/count(day0), 2) as day14,
+   round(100*count(day30)/count(day0), 2) as day30,
+   round(100*count(day60)/count(day0), 2) as day60,
+   round(100*count(day90)/count(day0), 2) as day90
+   from p2
+   group by date_joined

**Выводы: согласно полученным данным, резкое падение посещений происходит сразу же на след.день после регистрации (почти в 2 раза), можно предположить, что:
+   - возникли трудности на сайте, связанные со сложностью решения задач (недостаточно базы знаний), либо  сложности с пониманием работы самого сайта (как + +   решение: снять видеоролик «как работать на сайте»),
+   - регистрация была как необходимость (учащиеся на курсах должны зарегистрироваться на сайте), решение задач было отложено на более поздний срок.
+   - дальнейшие действия: проанализировать динамику посещения сайта (для учащихся на курсе с динамикой прохождения лекций). Вероятно, половина оставшихся пользователей в 1-й день – это постоянно изучающие теоретическую часть.**

**Задание №2:**
+   Расчет метрик относительно баланса пользователя.
+   -	сколько в среднем коинов списывает 1 человек
+   -	сколько в среднем коинов начисляется 1 человек
+   -	какой средний баланс среди всех пользователей
+   -	какой медианный баланс среди всех пользователей
+   Код решения с помощью 1 запроса (SQL):
+   with p1 as ( 
+           select tt.user_id,
+               sum(case when tt.type_id in (1, 23, 24, 25, 26, 27, 28, 30) then tt.value else 0 end) as balance_minus,
+               sum(case when tt.type_id not in (1, 23, 24, 25, 26, 27, 28, 30) then tt.value else 0 end) as balance_plus
+           from "transaction" tt 
+           join transactiontype t
+           on t.type = tt.type_id 
+           group by tt.user_id
+              )
+   select 
+   round(avg(balance_minus), 2) as spisanie, -- среднее списание – 31,29
+   round(avg(balance_plus), 2) as nachislenie, -- среднее начисление – 306,52
+   round(avg(balance_plus - balance_minus), 2) as middle_balance, -- средний баланс – 275,22
+   percentile_cont(0.5) within group(order by (balance_plus - balance_minus)) as median_balance – медианный баланс - 62
+   from p1

**Выводы: 
+   - больше половины пользователей с небольшим балансом (медиана = 62 намного меньше среднего значения = 275),
+   -  исходя из выше указанного и низкого списания = 31,29 следует, что мало активных людей, заинтересованных в начислениях, покупках, тратах,
+   - активные пользователи много покупают или получают бонусов, за счет этого большие среднее начисление и средний баланс.**

**Задание №3:**
+   Расчет метрик активности пользователей на платформе:
+   3.1. В среднем пользователь решает 9.18 задач. 
+   Код решения (SQL):

+   select round(avg(cnt), 2) from 
+       (
+       select user_id, count(*) as cnt from 
+           (
+           select user_id, problem_id from coderun c 
+           union
+           select user_id, problem_id from codesubmit c2 
+           )as summ
+       group by user_id 
+   ) as midle
+     
+   3.2. В среднем пользователь решает 2.11 теста.
+   Код решения (SQL):
+
+   select round(avg(cnt), 2) from 
+       (
+       select count(test_id) as cnt 
+       from teststart t 
+       group by user_id
+       ) as cnt_total
+
+   3.2.1. В среднем пользователь решает 1.68 уникальных теста.
+   Код решения (SQL):
+
+   select round(avg(cnt), 2) from 
+       (
+       select count(distinct test_id) as cnt from teststart t 
+       group by user_id
+       ) as cnt_total 

+   3.3. В среднем пользователь делает 5.75 попыток для решения 1 задачи.
+   Код решения (SQL):
+
+   select round(avg(cnt), 2) from 
+       (
+       select user_id, problem_id, count(problem_id) as cnt from coderun c 
+       group by user_id, problem_id
+       union
+       select user_id, problem_id, count(problem_id) as cnt from codesubmit c2 
+       group by user_id, problem_id
+       order by user_id, problem_id 
+       ) as zadachi
    
+   3.4. В среднем пользователь делает 1.26 попыток для прохождения 1 теста.
+   Код решения (SQL):

+   select round(avg(cnt), 2) as middle_avg from 
+       (
+       select user_id, test_id, count(test_id) as cnt from teststart t 
+       group by user_id, test_id
+       ) as middle
+       
**Дополнительно к 3 заданию:**
+   3.5. Доля от общего числа пользователей, которая решала хотя бы одну задачу или начинала проходить хотя бы один тест (пользователи не повторялись): 64,3%.
+   Код решения (SQL):

+   with midle as
+       (
+       select count(*) as cnt_users from users u
+       )
+   select (count(*) / (select cnt_users from midle)::numeric * 100) 
+   from
+       (
+       select distinct c.user_id, c2.user_id, t.user_id from codesubmit c 
+       full outer join coderun c2 
+       on c.user_id = c2.user_id 
+       full outer join teststart t 
+       on c.user_id = t.user_id) as rows_num
  
+   3.6. Покупки материалов на платформе за кодкоины.
+   Код решения (SQL):
+  
+   select 
+       count(case when type_id = 23 then 'OK' end) as cnt_zadachi, --кол-во людей, открывших   задачи за кодкоины
+       count(case when type_id in (26, 27) then 'OK' end) as cnt_tests, --кол-во людей, открывших тесты за кодкоины
+       count(case when type_id = 24 then 'OK' end) as cnt_podskazki, --кол-во людей, открывших подсказки за кодкоины
+       count(case when type_id = 25 then 'OK' end) as cnt_decision, --кол-во людей, открывших решения за кодкоины
+       count(case when type_id in (23, 24, 25, 26, 27) then 'OK' end) as cnt_anything, --кол-во людей, которые покупали
+       count(distinct user_id) as cnt_any_transact, -- количество людей с любыми транзакциями
+       count(case when type_id in (23, 24, 25, 26, 27) then 'OK' end) as cnt_anytrans --кол-во подсказок/тестов/задач/решений было открыто за кодкойны (нужно без distinctб включить все повторы)
+   from (
+       select distinct t.user_id, t.type_id from "transaction" t 
+       join transactiontype t2 
+       on t.type_id = t2."type") as first_table

**Выводы: : Пользователи тратят много попыток (5,75) на решения задач, отсюда и много покупок решений за кодкоины. Популярность задач выше тестов (в системе больше задач, чем тестов), но пользователей, купивших тестов больше, значит и важность их выше. Нужно увеличивать количество тестов (значит и пользователей, которые хотят их купить).**

/*ЗАДАНИЕ №1
Расчет rolling retention с разбивкой по когортам. В качестве когорт берем месяц регистрации на платформе. 
В качестве n-дней - 0, 1, 3, 7, 14, 30, 60 и 90 дней.*/ 

with TMP_1 as -- формируем исходные данные об активности пользователей
        (
        select distinct 
            userentry.user_id
            ,to_char(users.date_joined, 'YYYY-MM') year_month
            ,cast(users.date_joined as date) joined_date
            ,cast(userentry.entry_at as date) entry_date
            ,cast(userentry.entry_at as date) - cast(users.date_joined as date) dates_intarval
        from public.userentry
        inner join public.users on userentry.user_id = users.id 
        where 1=1
            and userentry.entry_at >= users.date_joined
            and to_char(users.date_joined, 'YYYY-MM') > '2021-10' --фильтруем данные с даты запуска платформы в ноябре 2021 года
        )
    ,TMP_2 as -- определяем максимальный интервал активности пользователя
        (
        select distinct
            TMP_1.year_month
            ,TMP_1.user_id
            ,max(TMP_1.dates_intarval) over(partition by TMP_1.user_id) max_dates_intarval
        from TMP_1
        ) 
    ,TMP_3 as -- ставим признак попадания пользователя в целевые когорты
        (        
        select 
            TMP_2.*
            ,case
                when TMP_2.max_dates_intarval >= 0 then 1
                else 0
            end day_0
            ,case
                when TMP_2.max_dates_intarval >= 1 then 1
                else 0
            end day_1
            ,case
                when TMP_2.max_dates_intarval >= 3 then 1
                else 0
            end day_3
            ,case
                when TMP_2.max_dates_intarval >= 7 then 1
                else 0
            end day_7
            ,case
                when TMP_2.max_dates_intarval >= 14 then 1
                else 0
            end day_14
            ,case
                when TMP_2.max_dates_intarval >= 30 then 1
                else 0
            end day_30
            ,case
                when TMP_2.max_dates_intarval >= 60 then 1
                else 0
            end day_60
            ,case
                when TMP_2.max_dates_intarval >= 90 then 1
                else 0
            end day_90
        from TMP_2
        )       
select 
    TMP_3.year_month
    ,round(round(sum(TMP_3.day_0),2) / round(count(TMP_3.user_id),2) * 100,2) day_0
    ,round(round(sum(TMP_3.day_1),2) / round(count(TMP_3.user_id),2) * 100,2) day_1
    ,round(round(sum(TMP_3.day_3),2) / round(count(TMP_3.user_id),2) *100,2) day_3
    ,round(round(sum(TMP_3.day_7),2) / round(count(TMP_3.user_id),2) * 100,2) day_7
    ,round(round(sum(TMP_3.day_14),2) / round(count(TMP_3.user_id),2) * 100,2) day_14
    ,round(round(sum(TMP_3.day_30),2) / round(count(TMP_3.user_id),2) * 100,2) day_30
    ,round(round(sum(TMP_3.day_60),2) / round(count(TMP_3.user_id),2) * 100,2) day_60
    ,round(round(sum(TMP_3.day_90),2) / round(count(TMP_3.user_id),2) * 100,2) day_90
from TMP_3
group by 1
order by 1

/*
Выводы: 

Следует обратить внимание на данные с даты запуска платформы в ноябре 2021 года.

На основании статистики за 6 месяцев:

- в 1-ый день в среднем возвращается 48% пользователей
- на 3-ий день в среднем возвращается 39% пользователей
- на 7-ой день в среднем возвращается 33% пользователей
- на 14-ый день в среднем возвращается 29% пользователей
- на 30-ый день в среднем возвращается 21% пользователей
- на 60-ый день в среднем возвращается 13% пользователей
- на 90-ый день в среднем возвращается 8% пользователей

31% пользователей заинтересованы в обучении на протяжении 7-14 дней. 
Такой тариф можно позиционировать как "Базовый" (для подготовки к интервью). 

21% пользователей заинтересованы в фундаментальном развитии навыков (на протяжении 30 дней). 
Такой тариф "Оптимум" (для развития навыков). 

11% пользователей возвращаются на платформу на протяжении 60-90 дней. 
Для их удержания можно сделать тариф "Премиум" (годовая подписка со скидкой
и полным доступом ко всему функционалу платформы).

При этом за период с 2021-11 до 2022-03 показатель rolling retention неуклонно снижался. 
Например, на 2021-11 в 1 день возращалось 72% пользователей, а на 2022-03 показатель составил 35%, 
т.е за 5 месяцев снижение на 38%. Однако, в 2022-04 в 1 день показатель составил уже 48% 

В конце первой недели после регистрации на платформу заходят в среднем на 14% пользователей меньше. 
Можно предложить бесплатный доступ по тарифу "Премиум" в течение 3-х дней, 
для последующих возвратов и удержания на платформе в будущем. 

Также проанализируем активность пользователей, зарегестрировавшихся в марте-апреле 2022 года. 
На 60-й и 90-й день (т.e в июне-июле) пользователи не заходят на платформу. 
Возможно, стоит перед летними каникулами запустить рекламную кампанию с пакетами заданий со скидками - "Летний интенсив".
*/ 

--ЗАДАНИЕ №2
-- Расчет метрик относительно баланса пользователя:

with TMP_1 as (
	select user_id, 
	   sum(case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then value else 0 end) as avg_debit_coins,
	   sum(case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then 0 else value end) as avg_credit_coins,
	   sum(case when type_id in (1, 23, 24, 25, 26, 27, 28, 30) then -value else value end) as avg_balance
	from "transaction" t 
	group by user_id
)
select 
	round(avg(avg_debit_coins), 2) as avg_debit_coins,	--сколько в среднем коинов списывает 1 человек
    round(avg(avg_credit_coins), 2) as avg_credit_coins,	--сколько в среднем коинов начисляется 1 человеку
    round(avg(avg_balance), 2) as avg_balance,	--какой средний баланс среди всех пользователей
    mode() WITHIN GROUP (ORDER BY avg_balance) as mode_balance --какой медианный баланс среди всех пользователей
from TMP_1;

/*	
Выводы:
В среднем пользователям начисляется почти в 10 раз больше коинов, чем они в среднем тратят на платформе (+307/-31), 
Медианный баланс составил 53 коина, а в среднем за полгода списывается 31 коин.
Необходимо добавление платного контента, т.к. у пользователей отсутствует мотивация списывать коины. 
На основании полученных метрик, получено подтверждение гипотезы о смене модели монетизации.
*/

--ЗАДАНИЕ №3
--Расчет метрик активности пользователей на платформе:

--a). Сколько в среднем пользователь решает задач
with TMP_1 as(  				  
	select 
		user_id, problem_id as cnt
	from coderun
	union						 
	select 
		user_id, problem_id as cnt   
	from codesubmit
),
TMP_2 as (
	select count(*) as cnt     	
	from TMP_1
	group by user_id
)
select round(avg(cnt), 2) as avg_user_tasks
from TMP_2

--Вывод: 9 задач в среднем решает пользователь на платформе.

--b). Сколько в среднем пользователь проходит тестов
with TMP_1 as (
	select count(distinct test_id) as cnt 
	from teststart		
	group by user_id 
)
select round(avg(cnt), 2) as avg_user_tests
	from TMP_1

--Вывод: 2 теста в среднем проходит пользователь на платформе.
	
--c). Сколько в среднем пользователь делает попыток для решения 1 задачи
with TMP_1 as (
	select 
    	user_id,
    	problem_id,
    	count(problem_id) as cnt
	from codesubmit c 
	group by user_id, problem_id
)
select round(avg(cnt),2) as avg_task_attempts
from TMP_1

--Вывод: 3 попытки в среднем делает пользователь для решения задачи на платформе.

--d). Сколько в среднем пользователь делает попыток для прохождения 1 теста
with TMP_1 as (
	select user_id, count(test_id) as cnt
	from teststart t
	group by user_id, test_id
)
select round(avg(cnt), 2) as avg_test_attemps 
from TMP_1

--Вывод: 1 попытку в среднем делает пользователь для прохождения теста на платформе.

--e). Какая доля от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест
with TMP_1 as (
    select distinct user_id
	from codesubmit
	union
	select distinct user_id                   
	from coderun c 
	union
	select distinct user_id 
	from teststart
)
select 
	round(count(*) / (select count(*) from users)::numeric * 100, 2) as user_percent_atteps 
from TMP_1

--Вывод: 63,5% от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест


--f). Дополнительная информация по покупкам материалов на платформе за кодкоины
with TMP_1 as (
	select 
		count(distinct user_id) as people_transaction --Сколько человек всего имеют хотя бы 1 транзакцию, пусть даже только начисление
	from "transaction" t 
),
TMP_2 as ( --формируем выборку пользователей по типу транзакций
	select 
		user_id, 
        type_id,
        count(value) as cnt_val
	from "transaction" t 
	where value > 0 and type_id in (23,24,25,27)
	group by user_id, type_id
),
TMP_3 as (
	select 
    	sum(case when type_id = 23 then 1 end) as people_task, --Сколько человек открывало задачи за кодкоины
        sum(case when type_id = 27 then 1 end) as people_test, --Сколько человек открывало тесты за кодкоины                     
        sum(case when type_id = 24 then 1 end) as people_hint, --Сколько человек открывало подсказки за кодкоины                       
        sum(case when type_id = 25 then 1 end) as people_solution, --Сколько человек открывало решения за кодкоины           
        count(distinct user_id) as people_anything --Сколько человек покупало хотя бы что-то из вышеперечисленного
	from TMP_2 
),
TMP_4 as (
	select
		sum(case when type_id = 23 then cnt_val end) as cnt_task, 
        sum(case when type_id = 27 then cnt_val end) as cnt_test,           
        sum(case when type_id = 24 then cnt_val end) as cnt_hint,        
        sum(case when type_id = 25 then cnt_val end) as cnt_solution    
    from TMP_2 --Сколько подсказок/тестов/задач/решений было открыто за кодкоины
)
select  
	people_task,
    people_test,
    people_hint,
    people_solution,
    cnt_task,
    cnt_test,
    cnt_solution,
    cnt_hint,
    people_anything,
    people_transaction
from TMP_1, TMP_3, TMP_4

/* 
 Выводы: 

На основании полученных данных:

- 450 человек открывало задачи за кодкоины
- 588 человек открывало тесты за кодкоины
- 52 человека открывали подсказки за кодкоины
- 151 человек открывало решения за кодкоины
- 1589 задач/844 теста/423 решения/117 подсказок было открыто за кодкоины
- 991 человек покупало хотя бы что-то из вышеперечисленного
- 2402 человека имеют хотя бы 1 транзакцию

в бесплатном функционале стоит оставить: 

- 2 попытки на решение задач (в среднем затрачивается примерно 3 попытки на задачу),
- 1 попытку на решение теста (в среднем затрачивается чуть больше 1 попытки). 

Возможность проходить тесты следует поместить в платную подписку, т.к. количество их открытий за кодкоины почти в 2 раза меньше, 
чем за открытие задач (1589 задач/844 тестов). Однако при этом пользователей, которые открывает тесты(588), почти на 40% больше, 
чем тех кто открывает задачи(450).


В среднем на пользователя пришлись купленные за кодкоины:

- 4 задачи (1589 задач/450 человек) 
- 3 решения (423 решения/151 человека)
- 2 подсказки (117 подсказок/52 человека), 
- 1 тест (844 теста/588 человек), 

Также исходя из полученных данных можно сделать вывод, 
что 41% пользователей открывали подсказки/тесты/задачи/решения за кодкоины.
*/

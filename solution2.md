Дополнительные метрики

1. Среднее время с даты регистрации прежде чем пользователь попробует платный функционал платформы. Метрика оценивает, насколько сбалансировано отношение бесплатного и платного контента.

with UsersAndDatesOfJoinAndPay as
(
select 
       distinct t.user_id as users,
       to_char(u.date_joined, 'YYYY-MM-DD') as date_of_joining,
       least(to_char(t.created_at, 'YYYY-MM-DD')) as date_of_start_paying
 
from users u
right join "transaction" t  
on u.id = t.user_id
where type_id in (23,24,25,27)
and date(t.created_at) > '2021-10-31'
and date(u.date_joined) > '2021-10-31'
),

DateDiffByUser as 
(
select 
       users,
       date_of_joining,
       date_of_start_paying,
       date_of_start_paying::date - date_of_joining::date as date_diff
from UsersAndDatesOfJoinAndPay
)

select avg(date_diff) as avg_date_diff
from DateDiffByUser 


Выводы: В среднем пользователь начинал открывать платный функционал платформы на 16 день после регистрации, что подтверждает факт о том, что на платформе очень много бесплатного функционала. Оптимальным временем пока люди используют бесплатный функционал был бы срок до 7 дней. 
       
2. Количество пользователей, которые решили задачу с разного числа попыток. Метрика определяет оптимальное количество попыток в бесплатном доступе

select * from codesubmit c 

with TableSumOfAttempt as 
(
select 
       user_id,
       problem_id,
       sum(is_false) as sum_of_attempt
from   
       codesubmit c 
group by 
       user_id,
       problem_id
),

GroupAttempt as 
(
select 
		case 
			when 
			     sum_of_attempt >= 1 and sum_of_attempt <= 2
			then  
			     '1 or 2'
			when 
			     sum_of_attempt >= 3 and sum_of_attempt <= 5
			then 
			     '3 to 5'
			when 
			     sum_of_attempt > 5 
			then 
			     '6 and more'
			else 
			     'solved'
		end as group_attempt
	
from TableSumOfAttempt
)

select 
	group_attempt,
	count(group_attempt)
from
    GroupAttempt
group by
         group_attempt
         
Выводы: 3654 пользователя решили задачи сразу. 2902 пользователям потребовались 1-2 дополнительные попытки. 1 026 потратили от трех до 5 попыток. 614 человек потратило от 6 попыток. Таким образом, оптимально в бесплатном функционале оставить 2 попытки для решения.  


3. Среднее количество дней, в течение которых пользователи, которые пополнили кошелек, заходили на платформу. Метрика определяет мотивацию пользователей заходить на платформу, а также период времени в течение которого им хватило пакета кодкоинов

with AllUsersPaidForCodeCoins as 
(
select 
       distinct us.id,
       us.date_joined 
from 
       "transaction" t 
inner join
       users us 
on us.id = t.user_id 
where t.type_id = 2
),

LastEnterAfterJoin as 
(
select 
       to_char(ac.date_joined,'YYYY-MM') as yw,
       ac.id,
       max(case 
               when 
                    date(ue.entry_at) - date(ac.date_joined) < 0 
                    or date(ue.entry_at) is Null
               then 
                        0
               else 
                        date(ue.entry_at) - date(ac.date_joined)
           end) as days_since_join
from 
       AllUsersPaidForCodeCoins ac 
left join 
         userentry ue
on ac.id = ue.user_id
where 
      date(ac.date_joined) > '2021-10-31'
group by 
        yw, ac.id
)

select 
      round(avg(days_since_join),2) as avg_days_since_join
from 
      LastEnterAfterJoin 

Выводы: В среднем пользователи, пополнившие кошелек, остаются на платформе в течение 61 дня. Это может свидетельствовать, во-первых, о том, что пакета код-коинов хватает на 2 месяца, а также о том, что люди, которые заплатили на код-коины, дольше остаются заинтересованными в платформе. 

Итоговые выводы о смене монетизации. 
Смена модели монетизации с бесплатного начисления код-коинов и платных пакетов код-коинов на платную подписку обусловлена множеством способов начисления код-коинов, пользователи тратят в 10 раз меньше от начисленных коинов, а также, что пакета код-коинов в среднем хватает на 2 месяца. 

Оптимально создание платного тарифа на 14 дней (за это время в среднем возвращается 25% пользователей), 30 дней (22%), годовой c большой скидкой (менее 7% спустя 90 дней). 

Чтобы сохранить активность зарегестрировавшихся пользователей можно предложить 3 дня бесплатного доступа к закрытому контенту, это побудит 12% пользователей заходить чаще и в будущем остаться на платформе. 

Летом активность пользователей значительно падает, стоит накануне лета уведомить о специальных летних тарифах с большими скидками. 

В состав платной подписки следует включить: 
- более 2х попыток на решение задачи (большинство пользователей решает задачу за 2 попытки)
- большая часть тестов, малую часть с 1 попыткой оставить в бесплатной версии, чтобы оценить функционал, т.к. пользователи (588 человек) заинтересованы в покупке тестов, а также в среднем пользователю требуется 1 попытка для прохождения теста. 
- готовое решение задачи, т.к в среднем на пользователя пришлись 3 открытых решения за код-коины
- подсказки, т.к на пользователя в среднем пришлись 2 открытые подсказки за код-коины

Также имеет смысл создать опцию «платная подписка со скидкой за приглашенных друзей» и за большое количество выполненных задач. 

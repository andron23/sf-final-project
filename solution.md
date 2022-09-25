Задание 1: Расчет rolling retention с разбивкой по когортам

with RegisteredUserPerMonth as (
select 
          to_char(users.date_joined, 'YYYY-MM') as yw,
          count(distinct users.id) as RegisteredUser
from users 
group by yw
),

lastLoginAfterRegistration as ( 

select 
          to_char(u.date_joined, 'YYYY-MM') as yw,
          u.id,
          max(case
	              when date (u2.entry_at) - date(u.date_joined) < 0 
	              or date (u2.entry_at) is null 
	              then 
	              0
	              else 
	              date (u2.entry_at) - date(u.date_joined) 
	              end)
	              as n_days
from 
        users u
left join 
        userentry u2 
on u.id = u2.user_id 
group by 
         yw, u.id
), 

LoginByDaysAndYM as (
select 
             yw,
             sum(case when n_days >=0 then 1 else 0 end) as day0,
             sum(case when n_days >=1 then 1 else 0 end) as day1,
             sum(case when n_days >=3 then 1 else 0 end) as day3,
             sum(case when n_days >=7 then 1 else 0 end) as day7,
             sum(case when n_days >=14 then 1 else 0 end) as day14,
             sum(case when n_days >=30 then 1 else 0 end) as day30,
             sum(case when n_days >=60 then 1 else 0 end) as day60,
             sum(case when n_days >=90 then 1 else 0 end) as day90
from 
             lastLoginAfterRegistration
group by 
              yw
)

select 
       l.yw, 
       round(day0::numeric/RegisteredUser*100, 2) as day0,
       round(day1::numeric/RegisteredUser*100, 2) as day1,
       round(day3::numeric/RegisteredUser*100, 2) as day3,
       round(day7::numeric/RegisteredUser*100, 2) as day7,
       round(day14::numeric/RegisteredUser*100, 2) as day14,
       round(day30::numeric/RegisteredUser*100, 2) as day30,
       round(day60::numeric/RegisteredUser*100, 2) as day60,
       round(day90::numeric/RegisteredUser*100, 2) as day90
from 
       LoginByDaysAndYM l
inner join 
       RegisteredUserPerMonth r 
on l.yw = r.yw
order by yw
    
Выводы: Посмотрим на полученные данные с дата запуска платформы в ноябре 2021 года. 
На основании статистики за 6 месяцев:
- в 1-ый день в среднем возвращается 42% пользователей
- на 3-ий день в среднем возвращается 34% пользователей
- на 7-ой день в среднем возвращается 30% пользователей
- на 14-ый день в среднем возвращается 25% пользователей
- на 30-ый день в среднем возвращается 22% пользователей
- на 60-ый день в среднем возвращается 12% пользователей
- на 90-ый день в среднем возвращается 7% пользователей

Порядка 30% пользователей заинтересованы в обучении на протяжении 7-14 дней. Такой тариф можно позиционировать для подготовки к интервью. 

В фундаментальном развитии навыков (на протяжении 30 дней) заинтересованы около 20% пользователей. Такой срок тоже оптимален для тарифа. 

Для удержания пользователей спустя 30 дней, можно сделать годовой тариф с большой скидкой. 

В конце первой недели после регистрации на платформу заходят на 12% меньше зарегестрировавшихся пользователей. Можно предложить бесплатный доступ к premium контенту на 3 дня, что возможно побудит их заходить чаще и в будущем остаться на платформе. 

Далее обратим внимание на активность пользователей, зарегестрировавшихся в апреле 2022 года. 
На 60-ый и 90-ый день (т.e июнь и июль) пользователи не заходят на платформу. 
Аналогично для пользователей, зарегестрировавшихся в марте 2022 года. На 90-ый день (т.е июнь) пользователи не заходят на платформу. 
Возможно стоит накануне лета уведомить о летних тарифах с большими скидками. 




Задание 2: Расчет метрик относительно баланса пользователя

with sumBalanceMetric as 
(
select user_id,
           sum(case
	                when 
	                     type_id in ('1', '23', '24', '25', '26', '27', '28', '30') 
	                then 
	                     value 
	                else 
	                     0
               end
               ) as sumWriteOff,
           sum(case
	                when    
	                     type_id not in ('1', '23', '24', '25', '26', '27', '28', '30')
	                then 
	                     value 
	                else 
	                     0
               end
               ) as sumAccrual,
           sum (case
	                 when  
	                      type_id not in ('1', '23', '24', '25', '26', '27', '28', '30') 
	                 then
	                      value 
	                 else 
	                      -value
                end
               ) as sumBalance 
  
from 
          "transaction" t
group by 
           user_id
)

select 
       round(avg(sumWriteOff),2) as avgWriteOff,
       round(avg(sumAccrual),2) as avgAccrual,
       round(avg(sumBalance),2) as avgBalance,
       mode() WITHIN GROUP (ORDER BY sumBalance) as mode

from 
     sumBalanceMetric

Выводы: Средняя сумма списаний 31 коин, в то время как средняя сумма начислений в 10 раз больше - 307 коинов. 
Следовательно, на платформе представлено много бесплатного контента, и у пользователей нет нужды списывать коины. 
Медианный баланс составил 53 коина, таким образом, у половины пользователей на балансе находится менее 53 коинов, а у другой половины - больше 53. 

Учитывая, что в среднем за полгода списывают 31 коин, с текущим медианным балансом в 53 коина, в среднем покупать коины за рубли в ближайшие полгода нет необходимости, кроме того за решения будут еще добавляться коины. 
Поэтому потребуется сделать часть контента платным. 




Задание 3(1): Сколько в среднем пользователь решает задач

with TableCodeRunAndSubmit as 
(
select 
            user_id,
            problem_id -- problem_id - идектификатор задачи 
from codesubmit c 
union all --объединяем таблицы 'выполнить' и 'проверить' по совпадающим столбцам
select 
            user_id,
            problem_id
from coderun c2 
), 

CountProblemSolvedByUser as (
select 
            user_id,
            count(distinct problem_id) as cnt 
from TableCodeRunAndSubmit
group by user_id
)

select 
            round(avg(cnt),2) as avgProblemSolved
from CountProblemSolvedByUser

Выводы: В среднем пользователь за полгода решал 9 задач. 
        



Задание 3(2): Сколько в среднем пользователь проходит тестов

with CountTestSolveByUser as 
(
select 
		   user_id, 
		   count(distinct test_id) as cnt
from teststart t 
group by user_id
)
select 
        round(avg(cnt),2) as avgTestSolv
from CountTestSolveByUser

Вывод: в среднем пользователь за полгода решал 2 теста




Задание 3(3): Сколько в среднем пользователь делает попыток для решения 1 задачи

with CountCodeSubmitByUser as 
(
select 
            user_id,
            problem_id,
            count(problem_id) as cnt
from 
            codesubmit c 
group by
             user_id, problem_id
)

select 

       round(avg(cnt),2) as avgTry
from 
       CountCodeSubmitByUser 

Выводы: В среднем пользователю требуется 3 попытки для решения задачи. Предлагается оставить 2 бесплатные попытки, чтобы решить задачу. 




Задание 3(4): Сколько в среднем пользователь делает попыток для прохождения 1 теста

with CountTestRunByUser as 
(
       select 	
              user_id,
              test_id,
              count(test_id) as cnt
       from 
              teststart
       group by 
              user_id, test_id
)

select 
        round(avg(cnt),2) as avgTry
from 
        CountTestRunByUser 

Выводы: В среднем пользователю требуется 1 попытка для прохождения теста. 




Задание 3(5): Какая доля от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест

with CountUsers as 
(
select 
           count(distinct id) as cnt
from 
           users
),

TableCodeRunAndSubmitAndTeststart as 
(
select 
            user_id
from 
            codesubmit c 
union all
select 
            user_id
from 
            coderun c2 
union all
select 
            user_id
from 
            teststart t 
),
    СountUserTry as 
(
select 
            count(distinct user_id) as cnt
from 
            TableCodeRunAndSubmitAndTeststart
)
select 
        round(ct.cnt::numeric /cu.cnt*100,2) as PercentOfUserTry
from 
        CountUsers cu,
        СountUserTry ct
        
Выводы:  64% от общего числа пользователей пытались решить хотя бы одну задачу или хотя бы один тест. 




Задание 3(6-11): Информация по покупкам материалов на платформе за кодкоины

with PeopleWithTransact as
(
select 
             count(distinct user_id) as cnt_people_with_transact
from 
            "transaction" t 
),

TransactionByUserAndType as 
(
select 
              user_id, 
              type_id,
              count(value) as cntvalue
from 
              "transaction" t 
where 
              value > 0   
              and type_id in (23,24,25,27)
group by 
              user_id, 
              type_id
),

CountPeopleOpenTipWithCoins as (
select 
               sum(case 
                        when 
                             type_id = 23
                        then 
                             1 
                        else 
                             0
                   end) as people_buy_problem,
              sum(case 
                        when
                             type_id = 27
                        then 
                             1 
                        else 
                             0
                  end) as people_buy_test,
              sum(case 
                        when
                             type_id = 24
                        then  
                              1 
                        else 
                              0
                  end) as people_buy_tip,
              sum(case 
                        when 
                              type_id = 25
                        then 
                               1 
                        else 
                               0
                  end) as people_buy_solution,
              count(distinct user_id) as people_buy_anything
from 
               TransactionByUserAndType 
),

OpenedForCoinsByType as 
(
select 
           sum(case 
                    when
                        type_id = 23
                    then 
                        cntvalue
                    else
                        0
                end) as count_problem_bought,
            sum(case 
                    when
                        type_id = 27
                    then 
                        cntvalue
                    else
                        0
                end) as count_test_bought,
            sum(case 
                    when
                        type_id = 24
                    then 
                        cntvalue
                    else
                        0
                end) as count_tip_bought,
            sum(case 
                    when
                        type_id = 25
                    then 
                        cntvalue
                    else
                        0
                end) as count_solution_bought
from 
          TransactionByUserAndType
)
select 
           c1.people_buy_anything,
           c1.people_buy_problem,
           c1.people_buy_test,
           c1.people_buy_tip,
           c1.people_buy_solution,
           c2.count_problem_bought,
           c2.count_test_bought,
           c2.count_tip_bought,
           c2.count_solution_bought,
           c3.cnt_people_with_transact
from 
           CountPeopleOpenTipWithCoins c1, 
           OpenedForCoinsByType c2, 
           PeopleWithTransact c3

Выводы: Всего 450 человек покупало задачи за кодкоины, 588 человек покупало тест, 52 человека покупало подсказки, 151 человек покупали решения, и 991 человек покупало хотя бы один продукт из вышеперечисленного за кодкоины. 
1589 задач было открыто за кодкоины, а также 844 теста, 117 подсказок и 423 решения. 2404 человек производили хотя бы одну трансакцию. 

В среднем на пользователя пришлись 4 купленные за кодкоины задачи (1589 задач/450 человек), 1 тест(844 теста /588 человек), 2 подсказки (117 подсказок/52 человека), 3 решения (423 решения/151 человека).
Больше всего пользователей заинтересовано в покупке тестов, поэтому на платформе можно оставить лишь малую часть тестов с одной бесплатной попыткой на прохождение, чтобы ознакомиться с форматом.

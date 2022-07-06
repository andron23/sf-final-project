ЗАДАНИЕ 2
Расчет метрик относительно баланса пользователя:
-сколько в среднем коинов списывает 1 человек
-сколько в среднем коинов начисляется 1 человеку
-какой средний баланс среди всех пользователей
-какой медианный баланс среди всех пользователей
with balance_table as  (
    select 
       user_id,
       sum
       (case when type_id in (1,23,24,25,26,27,28,30) then value else 0 end) as write_off,
       sum
       (case when type_id in (2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,29) then value else 0 end) as charges,
       sum
       (case when type_id in (1,23,24,25,26,27,28,30) then -value else value end ) as balance
     from "transaction" t
     group by user_id
     )
select avg(write_off), avg(charges), avg(balance), mode() within group (order by balance) as median_balance
from balance_table
Выводы: очень маленький процент спиания коинов по сравнению со средним балансом и средним наччислением, не хватаем интересных идей на что можно использовать полученные коины.

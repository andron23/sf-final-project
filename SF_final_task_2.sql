-- Расчет метрик относительно баланса пользователя:
    -- сколько в среднем коинов списывает 1 человек
    -- сколько в среднем коинов начисляется 1 человеку
    -- какой средний баланс среди всех пользователей
    -- какой медианный баланс среди всех пользователей

-- рекомендуется использовать данные из таблиц transaction и transactiontype
-- но у нас в таблице transaction уже есть type_id и мы знаем из задачи значения для фильтрации,
-- так что обойдемся без JOIN

-- Или JOIN + where t2.description like 'Купить%' or t2.description like 'покупка%' or t2.description like 'Списание')
-- в случае когда мы не знаем нужные типы и надо искать среди ключевых слов



with table_transaction as (
	select
		user_id,
		sum(value) as user_value, --сразу сгруппируем списания/пополнения каждого пользователя
		case -- добавим параметр с указанием типа операции списания(spend_coin) и начисления (receive_coin)
			when type_id in (1,23,24,25,26,27,28,30) then 'spend_coin'
			else 'receive_coin'
		end type_transaction
	from transaction
	group by user_id, type_transaction 
	order by user_id
),
avg_transactions as(
	select
		round(sum(case when type_transaction='spend_coin' then user_value end)/count(case when type_transaction='spend_coin' then 1 end),0) as "В среднем списывает 1 чел.",
		round(sum(case when type_transaction='receive_coin' then user_value end)/count(case when type_transaction='receive_coin' then 1 end),0) as "В средним начисляется 1 чел.",
		round((sum(case when type_transaction='receive_coin' then user_value end) - sum(case when type_transaction='spend_coin' then user_value end))/count(distinct user_id),0) as "Средний баланс среди всех"
	from table_transaction
),
balance_users as (
	select
		user_id,
		sum(case when type_transaction='receive_coin' then user_value else 0 end) - sum(case when type_transaction='spend_coin' then user_value else 0 end) as balance_user
	from table_transaction
	group by user_id
),
median_balance as (
	select
		percentile_cont(0.5) WITHIN GROUP (ORDER BY balance_user) AS "Медианный баланс среди всех" 
	FROM balance_users
)
select *
from avg_transactions
cross join median_balance 

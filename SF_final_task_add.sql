-- Проверим статистику списания токенов
select
	--t2.type_id as "",
	t2.description as "Тип списания",
	count(t.value) as "Количество",
	round(100*count(t.value)/sum(count(t.value)) over(),1) as "%",
	sum(t.value) as "Общая сумма",
	round(100*sum(t.value)/sum(sum(t.value)) over(),1) as "%"
from transaction t
join transactiontype t2 on t.type_id = t2.type
where t.type_id in (1, 23, 24, 25, 26, 27, 28, 30)
group by t.type_id, t2.description
order by count(t.value)
-- Аномальных выбросов нет. Но можно заметить что часть операций с высоким количеством операций приносит меньший % сжигания коинов. 
-- Я бы предложил пересмотреть стоимость операций списания, чтобы быстрее сжигать залежавшиеся коины.



-- Теперь проверим статистику начислений коинов от платформы
-- я исключил из всех начислений операцию Найти баг, т.к. их всего 0.31%, но сумма начислений 53.09% и этот выброс портит статистику дял анализа
-- и исключил покупку коинов за деньги, т.к. это и есть наша цель повысить покупки коинов
select
	--t2.type_id as "",
	t2.description as "Тип начисления",
	count(t.value) as "Количество",
	round(100*count(t.value)/sum(count(t.value)) over(),2) as "%",
	sum(t.value) as "Общая сумма",
	round(100*sum(t.value)/sum(sum(t.value)) over(),2) as "%"
from transaction t
join transactiontype t2 on t.type_id = t2.type
where t.type_id between 2 and 22 and t.type_id <> 19 and t.type_id <> 2 
group by t.type_id, t2.description
order by count(t.value)
-- Есть аномальный выброс за операцию Регистрации, при количество 14% это дает значительную сумму в 57% от всех операций. 
-- Стоит снизить количество начисляемых коинов за регистрацию



-- Посмотрим долю оборачиваемости коинов
with sink_ratio as (
	select
		user_id,
		sum(value) filter(where type_id between 2 and 22) as receive_coin,
		sum(value) filter(where type_id in (1, 23, 24, 25, 26, 27, 28, 30)) as spend_coin,
		sum(value) filter(where type_id between 2 and 22) - coalesce(sum(value) filter(where type_id in (1, 23, 24, 25, 26, 27, 28, 30)),0) as balance_coin,
		100*coalesce(sum(value) filter(where type_id in (1, 23, 24, 25, 26, 27, 28, 30)),0)/(sum(value) filter(where type_id between 2 and 22)) as sink_ratio_coin
	from transaction
	group by user_id
	order by sink_ratio_coin
)
select
	100*(count(sink_ratio_coin) filter (where sink_ratio_coin = 0))/count(user_id) as "% кто не тратит коины",
	100*(count(sink_ratio_coin) filter (where sink_ratio_coin > 0 and sink_ratio_coin <=25))/count(user_id) as "% кто тратит до 25",
	100*(count(sink_ratio_coin) filter (where sink_ratio_coin > 20 and sink_ratio_coin <=50))/count(user_id) as "% кто тратит до 50%",
	100*(count(sink_ratio_coin) filter (where sink_ratio_coin > 50 and sink_ratio_coin <=75))/count(user_id) as "% кто тратит до 75%",
	100*(count(sink_ratio_coin) filter (where sink_ratio_coin > 75))/count(user_id) as "% кто тратит все коины"
from sink_ratio 
-- Почти 50% не тратит токены вобще, 26% тратит не больше 50% токенов
-- Можно ввести временные коины, которые будут сгорать (Но только не те, которые куплены за деньги)
-- Также можно ввести акционные предложения для тех, у кого коины залежались (Например купить 25 задач со скидкой)


-- Посмотрим когда пользователь совершает первую покупку
with data_date_sale as (
	select
		u.id as user,
		t2.description as transaction,
		u.date_joined::date as reg_date,
		min(t.created_at::date) - u.date_joined::date as day_first_sale
	from users u
	left join transaction t on u.id = t.user_id and t.type_id in (1, 23, 24, 25, 26, 27, 28, 30)
	left join transactiontype t2  on t.type_id  = t2.type
	where t.type_id is not null
	group by u.id, t2.description, u.date_joined::date
)
select
	100*(count(day_first_sale) filter (where day_first_sale = 0))/count(user) as "% first sale on 0 day",
	100*(count(day_first_sale) filter (where day_first_sale > 0 and day_first_sale <=1))/count(user) as "% first sale on 1 day",
	100*(count(day_first_sale) filter (where day_first_sale > 1 and day_first_sale <=7))/count(user) as "% first sale on 7 day",
	100*(count(day_first_sale) filter (where day_first_sale > 7 and day_first_sale <=14))/count(user) as "% first sale on 14 day",
	100*(count(day_first_sale) filter (where day_first_sale > 14 and day_first_sale <=30))/count(user) as "% first sale on 30 day",
	100*(count(day_first_sale) filter (where day_first_sale > 30 and day_first_sale <=45))/count(user) as "% first sale on 45 day",
	100*(count(day_first_sale) filter (where day_first_sale > 45 and day_first_sale <=60))/count(user) as "% first sale on 60 day",
	100*(count(day_first_sale) filter (where day_first_sale > 60))/count(user) as "% first sale more 60 day"
from data_date_sale
-- Из тех кто тратит коины, более 70% совершает свою первую покупку сразу же в день регистрации


-- посмотрим в какие дни совершает покупки клиенты (Не только первую)
with data_date_sale as (
	select
		u.id as user,
		t2.description as transaction,
		u.date_joined::date as reg_date,
		t.created_at::date - u.date_joined::date as day_sale
	from users u
	left join transaction t on u.id = t.user_id and t.type_id in (1, 23, 24, 25, 26, 27, 28, 30)
	left join transactiontype t2  on t.type_id  = t2.type
	where t.type_id is not null
)
select
	100*(count(day_sale) filter (where day_sale = 0))/count(user) as "Покупает в день регистрации",
	100*(count(day_sale) filter (where day_sale > 0 and day_sale <=7))/count(user) as "Покупает в течении 7 дней",
	100*(count(day_sale) filter (where day_sale > 7 and day_sale <=14))/count(user) as "Покупает в течении 14 дней",
	100*(count(day_sale) filter (where day_sale > 14 and day_sale <=30))/count(user) as "Покупает в течении 30 дней",
	100*(count(day_sale) filter (where day_sale > 30 and day_sale <=45))/count(user) as "Покупает в течении 45 дней",
	100*(count(day_sale) filter (where day_sale > 45 and day_sale <=60))/count(user) as "Покупает в течении 60 дней",
	100*(count(day_sale) filter (where day_sale > 60))/count(user) as "Покупает после 60 дней"
from data_date_sale
-- почти 40% продаж были совершены в день регистрации, 17% покупают совершаются в первую неделю и 14% покупок совершаются не раньше 60 дней
-- Стоит мотивировать клиентов на расход коинов в первую неделю, потом интерес спадает




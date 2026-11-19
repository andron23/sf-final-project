-- Расчет rolling retention с разбивкой по когортам. 
-- В качестве когорт берем месяц регистрации на платформе. 
-- В качестве n-дней - 0, 1, 3, 7, 14, 30, 60 и 90 дней.

-- в задании рекомендуется брать дату первого входа как дату регистрации из таблицы users
-- но при проверки MIN значения даты из таблцы userentry стало понятно, что это одно и тоже
-- поэтому я отказался от лишнего JOIN и сделал все через userentry

$$ -- сравниваем дату регистрации из [users] и минимальную дату входа из [userentry]
select
	u.id,
	u.date_joined::date,
	MIN(ue.entry_at::date) as first_login_date	
from users u
join userentry ue on u.id = ue.user_id
group by u.id, u.date_joined::date
$$


-- Используем временные таблицы для сбора нужных данных
with first_login as ( -- 1. Найдем дату первого входа для каждого пользователя
	select 
		u.user_id,
		MIN(u.entry_at::date) as first_login_date,
		date_trunc('month', MIN(u.entry_at::date))::date as cohort_month
	from userentry u
	group by u.user_id
	order by first_login_date asc
),
user_activ as ( -- 2.Считаем разницу дней между первым входом и каждым последующим
	select
		u.user_id,
		f.cohort_month,
		(u.entry_at::date - f.first_login_date) as day_diff
	from userentry u
	join first_login f on u.user_id = f.user_id
	group by u.user_id, f.cohort_month, (u.entry_at::date - f.first_login_date)
),
cohort_size as ( -- 3.Посчитаем уникальных пользователей в каждой когорте
	select
		cohort_month,
		count(distinct user_id) as total_user
		from first_login
		group by cohort_month
)
select -- 4. Формируем итоговый запрос для каждой когорты, считаем в день N и в последующие
	c.cohort_month as "month_cohort",
	c.total_user as "count_users",
	round(count(distinct case when a.day_diff >= 0 then a.user_id end) * 100.0 / c.total_user, 2) as "Day 0 %",
	round(count(distinct case when a.day_diff >= 1 then a.user_id end) * 100.0 / c.total_user, 2) as "Day 1 %",
	round(count(distinct case when a.day_diff >= 3 then a.user_id end) * 100.0 / c.total_user, 2) as "Day 3 %",
	round(count(distinct case when a.day_diff >= 7 then a.user_id end) * 100.0 / c.total_user, 2) as "Day 7 %",
	round(count(distinct case when a.day_diff >= 14 then a.user_id end) * 100.0 / c.total_user, 2) as "Day 14 %",
	round(count(distinct case when a.day_diff >= 30 then a.user_id end) * 100.0 / c.total_user, 2) as "Day 30 %",
	round(count(distinct case when a.day_diff >= 60 then a.user_id end) * 100.0 / c.total_user, 2) as "Day 60 %",
	round(count(distinct case when a.day_diff >= 90 then a.user_id end) * 100.0 / c.total_user, 2) as "Day 90 %"
from cohort_size c
left join user_activ a on c.cohort_month = a.cohort_month
group by c.cohort_month, c.total_user
order by c.cohort_month

	
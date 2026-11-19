
-- Соберем данные по количеству входов в каждый день недели
select
	extract(isodow from u.entry_at) as dow,
	to_char(u.entry_at, 'Day') as day_name,
	count(u.user_id) as count_users
 from userentry u
 group by to_char(u.entry_at, 'Day'),extract(isodow from u.entry_at)
 order by extract(isodow from u.entry_at)

 
 -- соберем данные по активностям в каждый час
 with hour_problem as (
 	select
	extract (hour from created_at) as hour,
 		count(user_id) as count_user_problem
	from codesubmit
 	group by hour
	order by hour
),
hour_test as (
 select
 	extract (hour from created_at) as hour,
 	count(user_id) as count_user_test
 from teststart
 group by hour
 order by hour
)
select
	hp.hour,
	hp.count_user_problem,
	ht.count_user_test 
from hour_problem hp
join hour_test ht on hp."hour" = ht.hour
	 


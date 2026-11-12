**Задание 1**
with cohorts as (
    select id as user_id, to_char(date_joined, 'YYYY-MM') as yw, date_joined::date as reg_date
    from users),
user_activity as (
    select c.user_id, c.yw, max(ue.entry_at::date - c.reg_date) as max_day
    from cohorts c
    left join userentry ue
        on ue.user_id = c.user_id
    group by c.user_id, c.yw )
select yw,
round(100.0 * count(*) filter (where coalesce(max_day, -1) >= 0) / count(*),
        2 ) as day0,
round(100.0 * count(*) filter (where coalesce(max_day, -1) >= 1) / count(*),
        2 ) as day1,
round(100.0 * count(*) filter (where coalesce(max_day, -1) >= 3) / count(*),
        2 ) as day3,
round(100.0 * count(*) filter (where coalesce(max_day, -1) >= 7) / count(*),
        2 ) as day7,
round(100.0 * count(*) filter (where coalesce(max_day, -1) >= 14) / count(*),
        2 ) as day14,
round(100.0 * count(*) filter (where coalesce(max_day, -1) >= 30) / count(*),
        2 ) as day30,
round(100.0 * count(*) filter (where coalesce(max_day, -1) >= 60) / count(*),
        2 ) as day60,
round( 100.0 * count(*) filter (where coalesce(max_day, -1) >= 90) / count(*),
        2 ) as day90
from user_activity
group by yw
order by yw;
**Выводы:** 
По результатам расчета Rolling Retention видно, что активность пользователей со временем снижается. Основной отток происходит в течение первого месяца после регистрации, после чего доля активных пользователей становится значительно ниже.
**Это показывает, что месячная подписка может стать основным тарифом.**
При этом часть пользователей продолжает пользоваться платформой длительное время, из этого мне кажется имеет смысл добавить долгосрочную подписку на 6 или 12 месяцев.

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

**Задание 2**
WITH user_balance AS (
SELECT
        user_id,
        SUM(CASE WHEN type_id = 1 THEN value ELSE 0 END) AS spent_coins,
        SUM(CASE WHEN type_id <> 1 THEN value ELSE 0 END) AS accrued_coins,
        SUM(CASE
                WHEN type_id <> 1 THEN value
                ELSE -value
            END) AS balance
    FROM transaction
    GROUP BY user_id
)
SELECT
    ROUND(AVG(spent_coins), 2) AS avg_spent_coins_per_user,
    ROUND(AVG(accrued_coins), 2) AS avg_accrued_coins_per_user,
    ROUND(AVG(balance), 2) AS avg_balance,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balance) AS median_balance
FROM user_balance;
**Выводы:** 
Среднее количество начисляемых коинов на пользователя составляет-337,6
Среднее количество списываемых коинов-0,21
Средний баланс пользователя составляет-337,4 коина
Медианный баланс равен 103 коинам.
Это показывает нам, что большинство пользователей накапливают коины быстрее, чем тратят их

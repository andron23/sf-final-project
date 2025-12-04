Задание 1

--создаем подзапрос для формирования рабочей таблицы
with work_table as (
	select 
		e.user_id,
--извлекаем даты регистрации и входа пользователей из таблиц
		date (e.entry_at) as entry_at,
		date (u.date_joined) as date_joined,
--рассчитываем количество дней между регистрацией и входом пользователя на платформу
		extract (days from e.entry_at-u.date_joined) as days,
--преобразовываем формат даты регистрации для последующей группировки помесячно
		to_char (u.date_joined, 'YYYY-MM') as date
	from userentry e
	join users u 
	on e.user_id=u.id
	)
--из рабочей таблицы рассчитываем процент пользователей, проявивших активность в заданные интервалы после регистрации, относительно всех активных пользователей и округляем в одном действии
select 
	date,
	round (100.0 * count(distinct case when days>=0 then user_id end)/ count(distinct case when days>=0 then user_id end),2) as "day_0 %",
	round (100.0 * count(distinct case when days>=1 then user_id end)/ count(distinct case when days>=0 then user_id end),2) as "day_1 %",
	round (100.0 * count(distinct case when days>=3 then user_id end)/ count(distinct case when days>=0 then user_id end),2) as "day_3 %",
	round (100.0 * count(distinct case when days>=7 then user_id end)/ count(distinct case when days>=0 then user_id end),2) as "day_7 %",
	round (100.0 * count(distinct case when days>=14 then user_id end)/ count(distinct case when days>=0 then user_id end),2) as "day_14 %",
	round (100.0 * count(distinct case when days>=30 then user_id end)/ count(distinct case when days>=0 then user_id end),2) as "day_30 %",
	round (100.0 * count(distinct case when days>=60 then user_id end)/ count(distinct case when days>=0 then user_id end),2) as "day_60 %",
	round (100.0 * count(distinct case when days>=90 then user_id end)/ count(distinct case when days>=0 then user_id end),2) as "day_90 %"
from work_table
--группируем помесячно
group by date

Закономерности:
1. Представленные данные демонстрируют большу общую активность пользователей платформы в 2021 году относительно 2022 года: если в 2021 году в первый день после регистрации в активность составляет 100 % в большинстве когорт, то в 2022 показатель не превышает 50 % и далее идет на спад.
2. Для 2021 года наивысшая активность выпадает для зарегистрированных в июле и августе, что соответствует летним каникулам у студентов и периодом отпусков у трудоустроеных пользователей, когда они имеют достаточно временных ресурсов для изучения материалов. Далее эта активность сохраняется независимо от периода, прошедшего после регистрации.
3. Минимальная активность в 2021 году наблюдается у пользователей, зарегистрированных в декабре, что также коррелирует с учебными и рабочими графиками пользователей.
4. В 2021 году к 90-му дню после регистрации активность пользователей падает на 30 %, что может быть связано как с потерей активного интереса к обучению, так и со своевременным завершением программ.
5. Анализ данных за 2022 год показывают сохрание тенденции снижения активности пользователей, которое наблюдалось в конце 2021 года: так, активность пользователей в первый день после регистрации в феврале равна активности на 90 день после регистрации в ноябре прошлого года. При этом к 90 дню для когорты февраля 2022 года показатель падает до критических 1,23 %.
6. Средняя активность по данным 2022 года в первый день составляет около 35% и к 90-му дню падает до 0. При этом необходимо отметить, что несмотря на то, что для марта и апреля 2021 года в первый день после регистрации активность была 100 %, к 90-му дню она также, как и в 2022 году упала до 0, что свидетельствует о закономерности тотального снижения активности для этой когорты.

Общие выводы:
1. Активность пользователей в 2021 значительно превышает активность 2022 года независимо от когорты и интервала после регистрации.
2. Для зарегистрированных в марте и апреле 2021 и 2022 года наблюдается полное отсутсвие активности к 90-му дню независимо от входных показателей.
3. Наивысшая активность в 2021 году отмечена для зарегистрированных в июле и августе, чего также можно ожидать и в 2022 году.
4. Независимо от входных показателей активности в среднем к 90-му дню показатели падают на 30 % относительно 1 дня после регистрации.
5. Падение активности от периода к периоду не однородно: наибольшая дельта приходится на стык 30 и 60 дней.

Задание 2

--создаем подзапрос для формирования рабочей таблицы для расчета
with coins as(
	select 
--списания
	sum(case when t.type_id in(1,23,24,25,26,27,28,30) then value else 0 end) as losses,
--начисления
	sum(case when t.type_id  not in(1,23,24,25,26,27,28,30) then value else 0 end) as profit
	from transaction t
	where user_id is not null
--группируем по пользователям
	group by user_id)
select
--расчет среднего по начислениям
	round(avg(profit), 0) as avg_profit,
--расчет среднего по списаниям
	round(avg(losses), 0) as avg_losses,
--расчет среднего баланса
	round(avg(profit - losses), 0) as avg_balance,
--расчет медианного баланса
	percentile_cont(0.5) within group(order by(profit - losses)) as median_balance
from coins

Результаты:
1. Среднее по начислениям - 307 коинов;
2. Среднее по списаниям - 31 коин;
3. Среднее по балансу - 275 коинов;
4. Медиана по балансу - 62 коина.
Выводы:
1. Пользователи тратят почти в 10 меньше коинов, чем получают, что говорит о недостаточной мотивации траты;
2. Медианный баланс почти в 5 раз меньше среднего, что свидетеьствует о большом количестве пользователей, минимально тратящих заработанные коины.
Предложения:
1. Пересмотреть систему стоимость подписки, сделать ее более комфортной для большинства пользователей;
2. Повысить заинтересованность пользователей путем предложения новых бенефитов.

Задание 3
Метрики активности пользователей:
--создаем подзапрос для создания вспомогательной таблицы
with tasks as (
--подсчет задач на пользователя
    select user_id, count(distinct problem_id) as task
    from codesubmit
    where is_false = 0
    group by user_id
),
--подсчет тестов на пользователя
tests as (
    select user_id, count(distinct test_id) as test
    from teststart
    group by user_id
),
--подсчет попыток для решения 1 задачи
attempts_tasks as (
    select user_id, problem_id, count(*) as attempts
    from codesubmit
    group by user_id, problem_id
),
--подсчет попыток для решения одного теста
attempts_tests as (
    select user_id, test_id, count(*) as attempts 
    from teststart
    group by user_id, test_id
),
--объединение id пользователей из всех таблиц
active_users as (
    select user_id from coderun
    union
    select user_id from codesubmit
    union
    select user_id from teststart
),
--подсчет всех пользователей
all_users as (
    select count(id) as all_users from users
)
select     
--подсчет среднего по задачам
    avg((select round(avg(task), 2) from tasks))as avg_tasks,
--подсчет среднеего по тестам
    avg((select round(avg(test), 2) from tests)) as avg_tests,
--подсчет среднего по попыткам решения 1 задачи
    avg((select round(avg(attempts), 2) from attempts_tasks)) as avg_attempts_tasks,
--подсчет среднего по попыткам решения 1 теста
    avg((select round(avg(attempts), 2) from attempts_tests)) as avg_attempts_tests,
--расчет доли от общего числа пользователей
    round(
        (select count(distinct user_id) from active_users)::numeric / (select all_users from all_users)::numeric,4)*100 as active_users_percent
from users

Результаты:
1. Среднее число задач на пользователя - 10,53.
2. Среднее число тестов на пользователя - 1,68.
3. Среднее число попыток для решения одной задачи - 2,9.
4. Среднее число попыток для решения одного теста - 1,26.
5. Процент активных пользователей, решавших хотя бы одну задачу или тест - 63,48.

Выводы: Число попыток решения задач не превышает 3, число попыток решения тестов не превышает 2, что говорит о том, что пользователи хорошо справляются с поставленными задачами. Процент активных пользователей также достаточно высокий, что говорит о хорошей вовлеченности пользователей платформы.

Продуктовые метрики:
--создаем подзапрос для расчета
with a as (
--подсчет пользователей, открывавших задачи за кодкоины
	select 
	count (distinct user_id) as users_opened_tasks
	from transaction t 
	where t.type_id=23
),
b as (
--подсчет пользователей, открывавших тесты за кодкоины
	select 
	count (distinct user_id) as users_opened_tests
	from transaction t 
	where t.type_id =26 or t.type_id=27
),
c as (
--подсчет пользователей, открывавших подсказки за кодкоины
	select 
	count (distinct user_id) as users_opened_tips
	from transaction t 
	where t.type_id =24
),
d as (
--подсчет пользователей, открывавших решения за кодкоины
	select 
	count (distinct user_id) as users_opened_solutions
	from transaction t 
	where t.type_id =25 or t.type_id=28
),
e as (
--подсчет опций, открытых за кодкоины	
select 
	count (*) as all_opened,
--подсчет пользователей, совершившихх покупки за кодкоины 
	count (distinct t.user_id ) as users_coins
	from transaction t 
	where t.type_id between 23 and 28
),
f as (
--подсчет пользователей, совершивших транзакции
	select 
	count (distinct t.user_id ) as users_buyers
	from transaction t 
)
--собираем в одну таблицу
select 
	a.users_opened_tasks,
	b.users_opened_tests,
	c.users_opened_tips,
	d.users_opened_solutions,
	e.all_opened,
	e.users_coins,
	f.users_buyers
from a, b, c, d, e, f 

Результаты:
1. 522 пользователя открыли задачи за кодкоины;
2. 676 пользователей открыли тесты за кодкоины;
3. 53 пользователя открыли подсказки за кодкоины;
4. 151 пользователь открыл решения за кодкоины;
5. Всего за кодкоины приобретено 3205 доп.опций;
6. 1139 пользователей воспользовались покупкой опция за кодкоины и 2402 пользователя совершили хотя бы одну транзакцию.

Выводы: Около 90 % зарегистрированных пользователей совершили хотя бы 1 транзакцию, около 50 % из них воспользовались для этого кодкоинами.
Среди опций по количеству пользователей лидируют тесты (676 пользователей), задачи куплены 522 пользователями (около 20 % от зарегистрированных). Подсказки и решения за кодкоины востребованы в сумме менее чем у 10 % пользователей.

Дополнительное задание

О востребованности платных опций необходимо судить опираясь не только на количество заинтересованных пользователей, но и на количество приобретенных позиций.

--количество подсказок, приобретенных за кодкоины
with tips as (
	select 
	count (*) as tips_for_coins
	from transaction t 
	where t.type_id= 24
),
--количество тестов, открытых за кодкоины
tests as (
	select 
	count (*) as tests_for_coins
	from transaction t 
	where t.type_id between 26 and 27
),
--количество задач, открытых за кодкоины
tasks as (
	select 
	count (*) tasks_for_coins
	from transaction t 
	where t.type_id= 23
),
--количество решений, открытых за кодкоины
solutions as (
	select 
	count (*) solutions_for_coins
	from transaction t 
	where t.type_id= 25 or t.type_id= 28
) 
--собираем в одну таблицу
select 
	tips.tips_for_coins,
	tests.tests_for_coins,
	tasks.tasks_for_coins,
	solutions.solutions_for_coins
from tips, tests, tasks, solutions

Результаты:
1. Количество подсказок за кодкоины - 118;
2. Количество тестов за кодкоины - 989;
3. Количество задач за кодкоины - 1675;
4. Количество решений за кодкоины - 423.

Таким образом, хотя тесты покупает большее число пользователей, они почти в два раза уступают задачам по количеству покупок.

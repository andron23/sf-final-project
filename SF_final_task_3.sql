$$
    Расчет метрик активности пользователей на платформе:
		Сколько в среднем пользователь решает задач (is_false = 0)
		Сколько в среднем пользователь проходит тестов
		Сколько в среднем пользователь делает попыток для решения 1 задачи
		Сколько в среднем пользователь делает попыток для прохождения 1 теста
	Все эти метрики считаем только для тех пользователей, которые проходили тесты или решали задачи. Понятно, что если человек задачи не решал - то его не нужно считать в усреднении. 

	Однако, дополнительно важно оценить:
OK		Какая доля от общего числа пользователей решала хотя бы одну задачу или начинала проходить хотя бы один тест

	Плюс еще информация по покупкам материалов на платформе за кодкоины - эти 6 чисел нужно вывести 1 запросом, чтобы было наглядно:
		Сколько человек открывало задачи за кодкоины
		Сколько человек открывало тесты за кодкоины
		Сколько человек открывало подсказки за кодкоины
		Сколько человек открывало решения за кодкоины
		Сколько подсказок/тестов/задач/решений было открыто за кодкоины (если задача/... открыта разными людьми, то это считаем разными фактами открытия)
		Сколько человек покупало хотя бы что-то из вышеперечисленного
		Сколько человек всего имеют хотя бы 1 транзакцию, пусть даже только начисление	
		
Для решения задачи используем таблицы:
    «сколько решает задач и сколько делает попыток» - coderun, codesubmit
    «сколько проходит тестов» - teststart
    «сколько открывает/покупает» - transaction + transactiontype

$$

-- Задачу буду решать через несколько подзапросов и потом сведу все в один select

with problem_table_1 as( -- в таблице codesubmit информация по попыткам отправить решение, из которых is_false=0 успешные (готовое решение)
	select
		(count(problem_id) filter (where is_false=0))/count(distinct user_id) as "В среднем 1 ученик решает задач",
		count(problem_id)/count(distinct user_id) as "В среднем попыток решить задачу"
	from codesubmit
),
problem_table_2 as ( -- в таблице coderun информация по проверкам кода. Это не попытки отправить решение, их не считаем в ответе, но активность отследим
	select
		count(problem_id)/count(distinct user_id) as "В среднем 1 ученик проверяет код"
	from coderun
),
test_table as (
	select
		round(sum(total_test)/count(user_id),1) as "В среднем попыток пройти тест",
		round(sum(test_pos)/count(user_id),1) as "В среднем 1 ученик проходит тестов"
	from (
		select --в подзапросе сгруппируем по каждому ученику его количество попыток и количество пройденых тестов
			user_id,
			count(test_id) as total_test,
			count(distinct test_id) as test_pos --у нас нет параметра для успешного теста, поэтому считаем успешным каждый последний тест
		from teststart
		group by user_id
	) as test_users
),
active_users as (
	select -- тут мы соединяем уже три таблицы users + codesubmit + teststart
		count(distinct users.user_id) filter (where users.problem_id is not null or t.test_id is not null) as "Кол-во учеников решали задачи или тест",
		(count(distinct users.user_id) filter (where users.problem_id is not null or t.test_id is not null))*100/(count (distinct users.user_id)) as "% учеников решали задачу или тест"
	from (
		select -- в подзапросе соединим таблицы users + codesubmit чтобы попали ученики кто не решал задач, но есть на платформе
			u.id as user_id,
			cs.problem_id as problem_id
		from users u
		left join codesubmit cs on u.id = cs.user_id
		order by user_id
		) as users
	left join teststart t on users.user_id = t.user_id
),
transaction_users as (
	select -- соединем таблицы users + transaction и собираем данные по всем транзакциям
		count (distinct u.id) as "Всего пользователей",
		count (distinct u.id) filter (where t.type_id in (23)) as "Человек купило задачи",
		count (distinct u.id) filter (where t.type_id in (27)) as "Человек купило тесты",
		count (distinct u.id) filter (where t.type_id in (24)) as "Человек купило подсказки",
		count (distinct u.id) filter (where t.type_id in (25)) as "Челвоек купило решения",
		count (t.type_id) filter (where t.type_id in (23,27,24,25)) as "Всего было открыто",
		count (distinct u.id) filter (where t.type_id in (23,27,24,25)) as "Кто купил что-то из этого",
		count (distinct u.id) filter (where t.type_id is not null) as "Людей с 1+ транзакцией"
	from users u
	left join transaction t on u.id = t.user_id
)
select * -- собираем все таблицы в одну для ответа
from problem_table_1
cross join problem_table_2
cross join test_table 
cross join active_users
cross join transaction_users




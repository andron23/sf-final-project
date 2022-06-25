Задание 1

	with sumDistinctRegUserPerMonth as (
		select 
			to_char(date_joined,'YYYY-MM') as yw,
			count(id) as sumDistinctRegUser
		from users
		group by yw
	),
	lastEnterAfterJoin as (
		select
				to_char(us.date_joined,'YYYY-MM') as yw,
				us.id,
				/* Данную конструкцию пришлось сделать, т.к в таблице userentry есть user_id у которых вход фиксировался до регистрации
				 *  или у которых не было входа в день регистрации */
				max(case 
					when 
						date(ue.entry_at) - date(us.date_joined) < 0 
						or date(ue.entry_at) is Null
					then 
						0
					else 
						date(ue.entry_at) - date(us.date_joined)
					end) 
					as nDays
			from 
				users us 
			left join 
				userentry ue
			on us.id = ue.user_id
			/*отфильтровал значения, т.к. платформа запустилась с ноября 21 года  */
			where 
				date(us.date_joined) > '2021-10-31'
			group by 
				yw, us.id
	),
	cntEnterByDaysAndYM as (
		select 
		yw,
		sum(
			case 
				when 
					ndays >= 0 
				then 1
				else 0
			end)
			as day0,
		sum(
			case 
				when 
					ndays >= 1
				then 1
				else 0
			end) 
			as day1,
		sum(
			case 
				when 
					ndays >= 3
				then 1
				else 0
			end) 
			as day3,
		sum(
			case 
				when 
					ndays >= 7
				then 1
				else 0
			end) 
			as day7,
		sum(
			case 
				when 
					ndays >= 14
				then 1
				else 0
			end)
			as day14,
		sum(
			case 
				when 
					ndays >= 30
				then 1
				else 0
			end)
			as day30,
		sum(
			case 
				when 
					ndays >= 60
				then 1
				else 0
			end) 
			as day60,
		sum(
			case 
				when 
					ndays >= 90
				then 1
				else 0
			end) 
			as day90
		from 
			lastEnterAfterJoin
		group by 
			yw
		)
	select 
		C.yw,
		round(day0::numeric / sumDistinctRegUser*100,2) as day0,
		round(day1::numeric / sumDistinctRegUser*100,2) as day1,
		round(day3::numeric / sumDistinctRegUser*100,2) as day3,
		round(day7::numeric / sumDistinctRegUser*100,2) as day7,
		round(day14::numeric / sumDistinctRegUser*100,2) as day14,
		round(day30::numeric / sumDistinctRegUser*100,2) as day30,
		round(day60::numeric / sumDistinctRegUser*100,2) as day60,
		round(day90::numeric / sumDistinctRegUser*100,2) as day90
	from cntEnterByDaysAndYM C 
	inner join sumDistinctRegUserPerMonth S
	on C.yw = S.yw
	order by yw

Выводы:  
За весь период наблюдений после семи дней использования и более на платформе в среднем остается 30% от зарегистрированных.

После снижения уровня возвратов в феврале и марте показатель retention вернулся на уровень 26% у зарегистрированных в апреле, и я считаю, что данный промежуток можно закладывать в подписку, т. к. имеется стабильный уровень возвратов.Так же промежуток в 7 дней удобен для подготовки к тестам или собеседованиям и такой срок может быть оптимальным. Те же выводы касаются и промежутка в 14 дней.

После 30 дней использования и более возврат в среднем равняется 19%. Последние три месяца показатель был в диапазоне 7–9%. Данный промежуток удобен для более серьезного подхода в изучении материала и может помочь в удержании большего количества клиентов на платформе дольше при помощи автопродления по окончании месяца.

Возврат для 60+ и 90+ дней на платформе для зарегистрировавшихся на платформе в среднем равняется 18% и 11% без учета данных, зарегистрировавшихся в марте и апреле. Так как данных активности для зарегистрированных в марте и апреле нет, то стоит накопить больше информации для принятия решения о подписке на промежуток более месяца.

Задание 2

	with sumWriteOffAcuuralsAnsBalance as (
		select 
			user_id,
			sum(case 
					when 
						type_id in (1,23,24,25,26,27,28,30)
					then 
						value 
					else 
						0
				end)
				as sumWriteOffs,
			sum(case 
					when 
						type_id not in (1,23,24,25,26,27,28,30)
					then 
						value 
					else 
						0
				end)
				as sumAccurals,
			sum(case 
					when 
						type_id not in (1,23,24,25,26,27,28,30)
					then 
						value 
					else 
						-value
				end) 
				as sumBalance
		from 
			"transaction" t 
		group by 
			user_id 
	)
	select 
		round(avg(sumwriteoffs),2) as avgwriteoffs,
		round(avg(sumAccurals),2) as avgAccurals,
		round(avg(sumbalance),2) as avgbalance,
		mode() WITHIN GROUP (ORDER BY sumbalance) as mode
	from sumWriteOffAcuuralsAnsBalance

Выводы:
В среднем пользователям начисляется почти в 10 раз больше codecoin, чем пользователь в среднем списывает (306 против 31), что говорит о разбалансированности системы мотивации и о большом количестве вариантов начислений при невозможности потратить все монеты. 

Пятикратное превышение среднего баланса пользователя над медианным значением(275 против 53) говорит о положительной асимметрии и о том, что большинство пользователей имеют баланс меньше среднего.

Задание 3_1

	with unionCodeRunAndSubmit as (
		select 
			user_id,
			problem_id 
		from codesubmit c 
		union 
		select 
			user_id,
			problem_id 
		from coderun c2 
	),
	groupUserTrySolve as (
		select
			user_id,
			count(distinct problem_id) as cnt
		from unionCodeRunAndSubmit 
		group by user_id
	)
	select 
		round(avg(cnt),2) as avgProblSolv
	from groupUserTrySolve

Задача 3_2

    with countTestSolve as (
	select 
		user_id, 
		count(distinct test_id) as cntTest
	from teststart t 
	group by user_id
    )
    select 
        round(avg(cntTest),2) as avgTestSolv
    from countTestSolve

Задача 3_3 

    with unionCodesubmitAndCorerun as (
        select 
            user_id,
            problem_id 
        from 
            codesubmit c 
        union all
        select 
            user_id,
            problem_id 
        from 
            coderun c2 
    ),
    countTryToSolveOneProblem as (
        select 	
            user_id,
            problem_id,
            count(problem_id) as cnt
        from 
            unionCodesubmitAndCorerun 
        group by 
            user_id, problem_id
    )
    select 
        round(avg(cnt),2) as avgAllAttempt
    from 
        countTryToSolveOneProblem    

Задача 3_4

    with countTryToSolveOneTest as (
        select 	
            user_id,
            test_id,
            count(test_id)
        from 
            teststart
        group by 
            user_id, test_id
    )
    select 
        round(avg(count),2) as avgAllAttempt
    from 
        countTryToSolveOneTest

Задача 3_доп

    with сountAllUsers as (
        select 
            count(distinct id) as cnt
        from 
            users
    ),
    unionProblemAndTest as (
        select 
            user_id
        from 
            codesubmit c 
        union
        select 
            user_id
        from 
            teststart t 
    ),
    countUsersTryProblemOrTest as (
        select count(distinct user_id) as cnt
        from 
        unionProblemAndTest
        )
    select 
        round(B.cnt::numeric /A.cnt,2) as shareUsersSolveProblemOrTest
    from 
        сountAllUsers A,
        countUsersTryProblemOrTest B

Задача 3_(5_11)

    with allPeoplewithTransact as (
        select 
            count(distinct user_id) as PeoplewithTransact
        from "transaction" t 
    ),
    gruopByUserAndType as (
        select 
            user_id, 
            type_id,
            count(value) as cnt
        from 
            "transaction" t 
        where 
            value > 0   
            and type_id in (23,27,24,25)
        group by 
            user_id, 
            type_id
    ),
    people_open_test_problem_solution_clue as (
        select 
            sum(case 
                    when 
                        type_id = 23
                    then 
                        1 
                    else 
                        0
                end) 
                as people_open_with_coins_type_23,
            sum(case 
                    when
                        type_id = 27
                    then 
                        1 
                    else 
                        0
                end)
                as people_open_with_coins_type_27,
            sum(case 
                    when
                        type_id = 24
                    then 
                        1 
                    else 
                        0
                end) 
                as people_open_with_coins_type_24,
            sum(case 
                    when 
                        type_id = 25
                    then 
                        1 
                    else 
                        0
                end) 
                as people_open_with_coins_type_25,
            count(distinct user_id) as people_open_Smth_Of_23_27_24_25
        from 
            gruopByUserAndType 
    ),
    all_openings_for_coins_by_type as (
        select 
            sum(case 
                    when
                        type_id = 23
                    then 
                        cnt
                    else
                        0
                end
                ) as all_openings_for_coins_type_23,
            sum(case 
                    when
                        type_id = 27
                    then 
                        cnt
                    else
                        0
                end
                ) as all_openings_for_coins_type_27,
            sum(case 
                    when
                        type_id = 24
                    then 
                        cnt
                    else
                        0
                end
                ) as all_openings_for_coins_type_24,
            sum(case 
                    when
                        type_id = 25
                    then 
                        cnt
                    else
                        0
                end
                ) as all_openings_for_coins_type_25
        from 
            gruopByUserAndType
            )
    select 
        A.people_open_with_coins_type_23,
        A.people_open_with_coins_type_27,
        A.people_open_with_coins_type_24,
        A.people_open_with_coins_type_25,
        B.all_openings_for_coins_type_23,
        B.all_openings_for_coins_type_27,
        B.all_openings_for_coins_type_24,
        B.all_openings_for_coins_type_25,
        A.people_open_Smth_Of_23_27_24_25,
        C.PeoplewithTransact
    from 
        people_open_test_problem_solution_clue A, 
        all_openings_for_coins_by_type B, 
        allPeoplewithTransact C

**Выводы:** На основе полученных данных я считаю,
что в бесплатном функционале стоит оставить 5 попыток на решение задач(в среднем затрачивается примерно 9 попыток на задачу),
1 попытку на решение теста(в среднем затрачивается чуть больше 1 попытки).

Подсказки и решения следует поместить в платную подписку,
т.к. по сравнению с количеством открытий задач(1589 раз) или тестов(844) за codecoins, открытие подсказок(117) и решений(423) существенно ниже. 
Но при этом данный функционал может привлекать людей в платную подписку. 


**Дополнительное задание**  
Мне кажется что в данном исследовании не хватает метрик по пользователям, которые покупали codecoin за рубли.

**Для этого я предлагаю посчитать:**
- Какой процент от общего числа пользователей покупали codecoin за рубли?
- Сколько в среднем человек тратит codecoin после покупки их за рубли в целом, а так же по всем типам списаний?
- Rolling retention по когортам для людей, купивших codecoin за рубли.
- Среднее количество дней на платформе для людей, купивших codecoin за рубли?

**Сколько человек от общего числа пользователей покупали codecoin за рубли?**

    with count_user_account_funding as (
        select
            count(distinct user_id) as cnt_user_account_funding
        from 
            "transaction" t 
        /*отфильтровал значения, т.к. платформа запустилась с ноября 21 года  */
        where 
            type_id = 2 and date(created_at) > '2021-10-31'
    ),
    all_users as (
        select 
            count(distinct id) as cnt_all_users
        from 
            users u
        /*отфильтровал значения, т.к. платформа запустилась с ноября 21 года  */
        where 
            date(date_joined) > '2021-10-31'
    )	
    select 
        round(c.cnt_user_account_funding / a.cnt_all_users::numeric * 100, 2) as persent_of_users_account_funding
    from
        count_user_account_funding c,
        all_users a

**Сколько в среднем человек тратит codecoin после покупки их за рубли в целом, а так же по всем типам списаний?**

    with each_account_funding as (
        select
            user_id,
            min(created_at) as date_first_funding,
            sum(value) as sum_account_funding
        from 
            "transaction" t 
        where 
            type_id = 2
        group by user_id
    ),
    all_write_offs as (
        select 
            user_id,
            created_at,
            value,
            type_id
        from 
            transaction 
        where type_id in (1,23,24,25,26,27,28,30)
    ),
    sum_funding_and_write_off_by_user as (
    select 
            e.user_id,
            e.sum_account_funding,
            sum(a.value) as sum_write_off_after_account_funding,
            sum(case 
                    when 
                        type_id = 1
                    then 
                        a.value
                    else 
                        0
                end ) as sum_write_off_type_1,
            sum(case 
                    when 
                        type_id = 23
                    then 
                        a.value
                    else 
                        0
                end ) as sum_write_off_type_23,
                sum(case 
                    when 
                        type_id = 24
                    then 
                        a.value
                    else 
                        0
                end ) as sum_write_off_type_24,
                sum(case 
                    when 
                        type_id = 25
                    then 
                        a.value
                    else 
                        0
                end ) as sum_write_off_type_25,
                sum(case 
                    when 
                        type_id = 26
                    then 
                        a.value
                    else 
                        0
                end ) as sum_write_off_type_26,
                sum(case 
                    when 
                        type_id = 27
                    then 
                        a.value
                    else 
                        0
                end ) as sum_write_off_type_27,
                sum(case 
                    when 
                        type_id = 28
                    then 
                        a.value
                    else 
                        0
                end ) as sum_write_off_type_28,
                sum(case 
                    when 
                        type_id = 30
                    then 
                        a.value
                    else 
                        0
                end ) as sum_write_off_type_30
        from all_write_offs a inner join each_account_funding e 
        on a.user_id = e.user_id
        where a.created_at > e.date_first_funding 
        /*отфильтровал значения, т.к. платформа запустилась с ноября 21 года  */
        and e.date_first_funding > '2021-10-31'
        group by e.user_id, e.sum_account_funding
    )
    select 
        round(avg(sum_account_funding),2) as avg_all_acount_funding,
        round(avg(sum_write_off_after_account_funding),2) as sum_all_write_off_after_account_funding,
        round(avg(sum_write_off_type_1),2) as avg_write_off_type_1,
        round(avg(sum_write_off_type_23),2) as avg_write_off_type_23,
        round(avg(sum_write_off_type_24),2) as avg_write_off_type_24,
        round(avg(sum_write_off_type_25),2) as avg_write_off_type_25,
        round(avg(sum_write_off_type_26),2) as avg_write_off_type_26,
        round(avg(sum_write_off_type_27),2) as avg_write_off_type_27,
        round(avg(sum_write_off_type_28),2) as avg_write_off_type_28,
        round(avg(sum_write_off_type_30),2) as avg_write_off_type_30
    from 
        sum_funding_and_write_off_by_user

**Rolling retention по когортам для людей, купивших codecoin за рубли.**

    with count_user_account_funding as (
        select 
            distinct us.id,
            us.date_joined 
        from 
            "transaction" t 
        inner join
            users us 
        on us.id = t.user_id 
        where t.type_id = 2
    ),
    sumDistinctRegUserPerMonth as (
        select
            to_char(date_joined,'YYYY-MM') as yw,
            count(id) as sumDistinctRegUser
        from 
            count_user_account_funding
        group by 
            yw
    ),
    lastEnterAfterJoin as (
        select
                to_char(us.date_joined,'YYYY-MM') as yw,
                us.id,
                /* Данную конструкцию пришлось сделать, т.к в таблице userentry есть user_id у которых вход фиксировался до регистрации
                 *  или у которых не было входа в день регистрации */
                max(case 
                    when 
                        date(ue.entry_at) - date(us.date_joined) < 0 
                        or date(ue.entry_at) is Null
                    then 
                        0
                    else 
                        date(ue.entry_at) - date(us.date_joined)
                    end) 
                    as nDays
            from 
                count_user_account_funding us 
            left join 
                userentry ue
            on us.id = ue.user_id
            /*отфильтровал значения, т.к. платформа запустилась с ноября 21 года  */
            where 
                date(us.date_joined) > '2021-10-31'
            group by 
                yw, us.id
    ),
    cntEnterByDaysAndYM as (
        select 
        yw,
        sum(
            case 
                when 
                    ndays >= 0 
                then 1
                else 0
            end)
            as day0,
        sum(
            case 
                when 
                    ndays >= 1
                then 1
                else 0
            end) 
            as day1,
        sum(
            case 
                when 
                    ndays >= 3
                then 1
                else 0
            end) 
            as day3,
        sum(
            case 
                when 
                    ndays >= 7
                then 1
                else 0
            end) 
            as day7,
        sum(
            case 
                when 
                    ndays >= 14
                then 1
                else 0
            end)
            as day14,
        sum(
            case 
                when 
                    ndays >= 30
                then 1
                else 0
            end)
            as day30,
        sum(
            case 
                when 
                    ndays >= 60
                then 1
                else 0
            end) 
            as day60,
        sum(
            case 
                when 
                    ndays >= 90
                then 1
                else 0
            end) 
            as day90
        from 
            lastEnterAfterJoin
        group by 
            yw
        )
    select 
        C.yw,
        round(day0::numeric / sumDistinctRegUser*100,2) as day0,
        round(day1::numeric / sumDistinctRegUser*100,2) as day1,
        round(day3::numeric / sumDistinctRegUser*100,2) as day3,
        round(day7::numeric / sumDistinctRegUser*100,2) as day7,
        round(day14::numeric / sumDistinctRegUser*100,2) as day14,
        round(day30::numeric / sumDistinctRegUser*100,2) as day30,
        round(day60::numeric / sumDistinctRegUser*100,2) as day60,
        round(day90::numeric / sumDistinctRegUser*100,2) as day90
    from cntEnterByDaysAndYM C 
    inner join sumDistinctRegUserPerMonth S
    on C.yw = S.yw
    order by yw

**Среднее количество дней на платформе для людей купивший codecoin за рубли?**

    with count_user_account_funding as (
        select 
            distinct us.id,
            us.date_joined 
        from 
            "transaction" t 
        inner join
            users us 
        on us.id = t.user_id 
        where t.type_id = 2
    ),
    lastEnterAfterJoin as (
        select 
                to_char(us.date_joined,'YYYY-MM') as yw,
                us.id,
                /* Данную конструкцию пришлось сделать, т.к в таблице userentry есть user_id у которых вход фиксировался до регистрации
                 *  или у которых не было входа в день регистрации */
                max(case 
                    when 
                        date(ue.entry_at) - date(us.date_joined) < 0 
                        or date(ue.entry_at) is Null
                    then 
                        0
                    else 
                        date(ue.entry_at) - date(us.date_joined)
                    end) 
                    as nDays
            from 
                count_user_account_funding us 
            left join 
                userentry ue
            on us.id = ue.user_id
            /*отфильтровал значения, т.к. платформа запустилась с ноября 21 года  */
            where 
                date(us.date_joined) > '2021-10-31'
            group by 
                yw, us.id
    )
    select 
        round(avg(ndays),2) as avg_last_day
    from 
        lastEnterAfterJoin

**Выводы:** На основе **первой дополнительной метрики** можно подтвердить тезис 
о необходимости смены монетизации, т.к. от общего количества пользователей только 0,81% 
покупали codecoin за рубли.  
По **второй метрике** я делаю выводы, что основноые траты codecoin, купленных за рубли,
приходятся на открытие задач, что подтверждает необходимость добавления задач в платную подписку 
с возможностью решать задачи в бесплатном доступе с ограничениями по попыткам.
На решение задач, в среднем, пользователи, купившие codecoins за рубли, тратят 198,16 рублей.
Следующим по популярности явлется трата на открытие тестов(33,68 рублей), потом на открытие решений(19,47)
и на открытие подсказок(0,53). На типы списаний 1,26,28,30 не пришлось ни одного рубля.  
В среднем люди покупали coin на 286,86 рублей.  
**Третья метрика** дает следующие результаты:
- После 7 и 14 дней средний показатель rolling retention,для людей тратящих на платформе рубли за codecoin, равнялся 89,14%
- После 30 дней равнялся 71,62%
- После 60 дней равнялся 57,74% (для 2022-04 значение day60 в расчет не берем, т.к. датасет не имеет данных для апреля больше 60 дней)
- После 90 дней равнялся 49,41% (для 2022-04 значение day90 в расчет не берем)

Таким образом мы имеем: 
- не вернувшихся после 14 дней 10,86%, людей.
- после 30 дней = 89,14 - 71,62 = 17,52%
- после 60 дней = 13,88%
- после 90 дней = 49,41%

**Четвертая метрик**а показывает сколько в среднем находится на платформе пользователь, купивший codecoin за рубли.
В результате данная метрика показывает, что в среднем такие пользователи находятся на платформе 60,74 дней.  
Таким образом данная метрика и результат средней покупки codecoin за рубли из второй метрики дает нам минимальное значение стоимости подписки, которое пользователи косвенно платят в данный момент.
Минимальная стоимость подписки равняется: 
- 286,86/60,74 = 4,72 руб/день 
- 33,04 рубля в неделю
- 138,3 рубля в месяц



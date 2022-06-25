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

Выводы: На основе полученных данных я считаю,
что в бесплатном функционале стоит оставить 5 попыток на решение задач(в среднем затрачивается примерно 9 попыток на задачу),
1 попытку на решение теста(в среднем затрачивается чуть больше 1 попытки). Подсказки и решения следует поместить в платную подписку,
т.к. по сравнению с количеством открытий задач(1589 раз) или тестов(844) за codecoins, открытие подсказок(117) и решений(423) существенно ниже. 
Но при этом данный функциоонал может привлекать людей в подписку. 



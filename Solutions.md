#### Задание 1: Расчет rolling (RR) retention с разбивкой по когортам

with cohorts as(
  select
     u.user_id,
     to_char (u2.date_joined,'YYYY-MM') as cohort, -- сегментация на когорты по дате регистрации
    (date(u.entry_at)- date(u2.date_joined))*1 as int -- интервал между датой регистрации и датой входа
  from userentry u
  join users u2 on u.user_id  = u2.id)
select
   cohort,
   round(count(distinct case when int >=0 then c.user_id end)*100.0/count(distinct case when int >=0 then c.user_id end),2) as "0_day",
   round(count(distinct case when int >=1 then c.user_id end)*100.0/count(distinct case when int >=0 then c.user_id end),2) as "1_day",
   round(count(distinct case when int >=3 then c.user_id end)*100.0/count(distinct case when int >=0 then c.user_id end),2) as "3_day",
   round(count(distinct case when int >=7 then c.user_id end)*100.0/count(distinct case when int >=0 then c.user_id end),2) as "7_day",
   round(count(distinct case when int >=7 then c.user_id end)*100.0/count(distinct case when int >=0 then c.user_id end),2) as "14_day",
   round(count(distinct case when int >=30 then c.user_id end)*100.0/count(distinct case when int >=0 then c.user_id end),2) as "30_day",
   round(count(distinct case when int >=60 then c.user_id end)*100.0/count(distinct case when int >=0 then c.user_id end),2) as "60_day",
   round(count(distinct case when int >=90 then c.user_id end)*100.0/count(distinct case when int >=0 then c.user_id end),2) as "90_day"
from cohorts c
where cohort >= '2022-01'
group by cohort


Выводы:
По данным за 2022 год наблюдается выраженное снижение удержания уже в первые дни после регистрации. В среднем по когортам показатель RR в 1-й день составляет около 40%, на 3-й день — около 31%, на 7-й день — около 24%, на 14-й день — также около 24%, на 30-й день — около 11%, на 16-й день — около 4%, а на 90-й день — не более 1,5%.
Основной период, в который пользователь либо формирует устойчивую привычку пользоваться продуктом, либо перестает быть активным, ограничен первыми 7–30 днями после регистрации. Следовательно, именно этот временной промежуток должен рассматриваться как приоритетный при разработке новой модели монетизации.
Поскольку именно в течение первой недели наблюдается наиболее резкое снижение доли возвращающихся пользователей, присутствует группа с с ситуативной мотивацией: подготовка к собеседованию, решение конкретного набора задач, прохождение тестов в течение ограниченного периода. Целесообразно предусмотреть краткосрочный 7-й тариф, рассчитанный на таких пользователей.
Основной тариф: 30 дней - в течение первого месяца происходит основная потеря пользователей, значит монетизировать нужно именно этот период.
Возможно введение долгосрочной подписки сроком на 12 месяцев для наиболее вовлеченных и лояльных пользователей, при этом нужно предусмотреть скидку для такого тарифа в целях удержания лояльности.

#### 2. Расчет метрик относительно баланса:

with balances as (
    select
        to_char(created_at, 'YYYY') as year,
        user_id,
        sum(case when type_id not in (1,23,24,25,26,27,28,30) then value else 0 end) as accrual,
        SUM(case when type_id in (1,23,24,25,26,27,28,30) then -value else 0 end) as write_off,
        SUM(case when type_id in (1,23,24,25,26,27,28,30) then -value else value end) as balance
    from "transaction" t
    group by to_char(created_at, 'YYYY'), user_id
)
select
    year,
    round(sum(write_off) / nullif(count(distinct case when write_off <> 0 then user_id end), 0),2) as avg_write_off, -- средние списания
    round(sum(accrual) / nullif(count(distinct user_id), 0),2) as avg_accrual, -- средние начисления
    round(sum(balance) / nullif(count(distinct user_id), 0),2) as avg_balance, -- средний баланс
    percentile_cont(0.5) within group (order by balance) as median_balance -- медианный баланс
 from balances
 where year = '2022'
 group by year

Выводы:
По данным за 2022 год среднее списание составило 68,4 CodeCoins, среднее начисление — 138,18 CodeCoins, средний баланс — 109,69 CodeCoins, медианный баланс — 61 CodeCoin.
Полученные результаты показывают, что в среднем пользователи получали внутренней валюты больше, чем тратили. Это свидетельствует о том, что существующая модель недостаточно эффективно формировала регулярную платежную потребность. Пользователь мог накапливать запас коинов за счет активности на платформе и в течение длительного времени пользоваться платными элементами без необходимости повторной покупки.
Положительные показатели баланса это подтверждают. Текущая модель способствовала поддерживанию вовлеченности за счет зарабатывания вынутренней валюты, но не способствавала тому, чтобы покупки были регулярными.
Следовательно, переход к подписочной системе представляется экономически оправданным, поскольку подписка позволяет перевести выручку из режима редких микроплатежей в режим регулярных предсказуемых поступлений.
Также предварительно можно сделать вывод, что основной тариф должен быть не выше среднего занчения по списаниям коинов в денежном эквиваленте.


#### Задание 3.

-- Часть 1. Активность при решении задач:

with union_code as(                                    -- объединение таблиц coderun и codesubmit по нужным столбцам
      select
        to_char (created_at, 'YYYY') as year,
        user_id,
        problem_id,
        id
      from coderun
      union all
      select
        to_char (created_at, 'YYYY') as year,
        user_id,
        problem_id,
        id
      from codesubmit),
     unique_problem as(
      select
        year,
        user_id,
        count (distinct problem_id) as cnt_problem,        -- подсчет номеров задач, которые решал каждый пользователь                                          
        count (id) as attempt                              -- подсчет попыток решения задачи  
        from union_code uc
        group by year, user_id),
     total_user as(
        select
        to_char (date_joined, 'YYYY') as year,
        sum(count(id)) over (order by to_char(date_joined, 'YYYY')) as cnt_user_full
        from users 
        group by to_char (date_joined, 'YYYY'))
select
  up.year,
  count (distinct user_id) as cnt_user,
  sum (cnt_problem) as quantity_problem,
  sum (attempt) as quantity_attempt,
  round (sum (cnt_problem)*1.0 / count (distinct user_id), 1) as avg_problem, -- Сколько в среднем пользователь решает задач
  round (sum (attempt)*1.0 / sum (cnt_problem) , 1) as avg_attempt, -- Сколько в среднем пользователь делает попыток для решения 1 задачи
  round (count (distinct user_id)*1.0/tu.cnt_user_full*1.0*100, 1) as per_or_total_user -- Какая доля от общего числа пользователей решала хотя бы одну задачу
from unique_problem up
join total_user tu on up."year" = tu."year" 
where up.year = '2022'
group by up.year, tu.cnt_user_full

-- Часть 2. Активность при прохождении тестов:

with unique_test as (
      select
        to_char (created_at, 'YYYY') as year,
        user_id,
        count (distinct test_id) as cnt_test,             -- подсчет номеров тестов, которые решал каждый пользователь    
        count (id) as attempt                             -- подсчет попыток решения теста  
      from teststart t
      group by to_char (created_at, 'YYYY'), user_id),
     total_user as(
      select
      to_char (date_joined, 'YYYY') as year,
      sum(count(id)) over (order by to_char(date_joined, 'YYYY')) as cnt_user_full
      from users 
      group by to_char (date_joined, 'YYYY'))
select
  ut.year,
  count (distinct user_id) as cnt_user,
  sum (cnt_test) as quantity_test,
  sum (attempt) as quantity_attempt,
  round (sum (cnt_test)*1.0 / count (distinct user_id), 1) as avg_test, -- Сколько в среднем пользователь решает тестов
  round (sum (attempt)*1.0 / sum (cnt_test) , 1) as avg_attempt, -- Сколько в среднем пользователь делает попыток для решения 1 теста
  round (count (distinct user_id)*1.0/tu.cnt_user_full*1.0*100, 1) as per_or_total_user -- Какая доля от общего числа пользователей решала хотя бы один тест
from unique_test ut
join total_user tu on ut."year" = tu."year" 
where ut.year = '2022'
group by ut.year, tu.cnt_user_full

-- Часть 2. Общие показатели активности:
with total as(
    select
        to_char(t.created_at, 'YYYY') AS year,
        t.type_id,
        t.user_id,
        sum(value) as total_value,
        count(*) as openings_count,
        sum(value) as total_values
    from "transaction" t
    group by to_char(t.created_at, 'YYYY'), t.type_id, t.user_id
)
select
    total.year,
    count(distinct case when type_id = 23 then user_id end)          as users_open_tasks,      --  Сколько человек открывало задачи за кодкоины
    count(distinct case when type_id = 24 then user_id end)           as users_open_hints,      -- Сколько человек открывало подсказки за кодкоины
    count(distinct case when type_id = 25 then user_id end)           as users_open_solutions,  -- Сколько человек открывало решения за кодкоины
    count(distinct case when type_id = 27 then user_id end)           as users_open_tests,      -- Сколько человек открывало тесты за кодкоины
    count(distinct case when type_id in (23,24,25,27) then user_id end)  as users_any_write_off, -- Сколько человек покупало хотя бы что-то из вышеперечисленного
    sum(case when type_id in (23,24,25,27) then openings_count else 0 end) as total_openings,        -- Сколько подсказок/тестов/задач/решений было открыто за кодкоины (если задача/... открыта разными людьми, то это считаем разными фактами открытия)
    count(distinct user_id)                                            as users_total           -- Сколько человек всего имеют хотя бы 1 транзакцию, пусть даже только начисление
from total 
where total.year = '2022' and total_values > 0 -- исключаем транзакции, по которым по каким-то причинам не начислили списание
group by total.year

Выводы:
По результатам анализа пользовательской активности можно заключить, что основную ценность платформы формирует решение задач, поэтому данный функционал должен оставаться базово бесплатным.
Высокое среднее число попыток на одну задачу (10) показывает, что многократное решение является естественной частью обучения, а значит, жесткие ограничения на попытки в бесплатной версии могут негативно повлиять на пользовательский опыт.
Одновременно тесты охватывают более широкую аудиторию (1 124 пользователя), чем задачи, что делает их перспективным инструментом для включения в состав платной подписки. При этом глубина использования тестов ниже, поэтому они могут эффективно выполнять роль массового платного контента с понятной ценностью для пользователя.
Наличие списаний в целом подтверждает готовность пользователей платить за расширенный пакет тесты (559 пользователей), дополнительные задачи (397 пользователей),  решения (132 пользователя).
Что оставить бесплатным: задач и тесты легкого уровня на базовый функционал без ограничения попыток и доступом к решению и подсказкам для удержания заинтересованности, задачи и тесты среднего уровня с ограничением попыток и подсказок, но с доступом к решению. Что сделать платным: задачи и тесты среднего уровня, но с разбором реальных кейсов, задачи продвинутого уровня, тесты среднего на узкие сегменты знаний, тесты продвинутого уровня перенести в платную подписку. Также можно разнообразить платные пакеты детальными разборами решений, симуляторами по прохождению собесетодований и т.п.

#### Дополнительное задание:

-- Часть 1. Сегментирование пользователей по размеру трат.
    
-- Мне кажется, что медианный баланс, и в принципе показатели баланса не совсем подходят для принятия решения по стоимости услуг.
Лучше анализировать списания. Для этого нужно посмотреть сколько коинов тратят пользователи в разных сегментах и сравнить со средними списаниями.
Итого не смотря на то, что средний показатель по списаниям в районе 68 коинов, половина пользователей тратит не больше 30. Соотвественно, базовый тариф нецелесообразно устанавливать выше этой суммы в денежном эквиваленте. И далее нужно развивать ценность контента.

with total as( 
select
        to_char(t.created_at, 'YYYY') as year,
        t.user_id,
        sum(value) as total_value
    from "transaction" t
    where  to_char(t.created_at, 'YYYY') = '2022' and type_id in (1,23,24,25,26,27,28,30)
    group by to_char(t.created_at, 'YYYY'), t.user_id
    having sum(value) > 0)  -- исключаем транзакции, по которым по каким-то причинам не начислили списание 
select
 count (distinct user_id) as user_id, -- количество пользователей, которые потратили коины
 round(avg(total_value),2) as avg_write_off, -- средняя величина списания
 percentile_cont(0.25) within group (order by total_value) as P25_write_off, -- 1 сегмент
 percentile_cont(0.5) within group (order by total_value) as median_write_off,  -- 2 сегмент
 percentile_cont(0.75) within group (order by total_value) as P75_write_off -- 3 сегмент
from total

-- Часть 2. Сегментирование пользователей по интервалу от последней до первой покупки трат и частоте трат.

-- Для дополнительного подтверждения выбора гипотезы по продолжительности тарифа целесообразно просегментировать пользователей по интервалам от первой и послдней покупки и активности. Медианный интервал между транзакциями  8 дней согласуется с гипотезой о ситуативном использовании платформы — например, при интенсивной подготовке к интервью или прохождении учебного блока в течение одной недели.
В то же время верхний квартиль интервала, равный 34 дням, указывает на наличие другой группы пользователей, чье взаимодействие с платным функционалом укладывается в месячный цикл.
Таким образом, данные о транзакциях дополнительно подтверждают целесообразность тарифов на 7 дней и 30 дней.

with intervals as(
     select
       user_id,
       count(*) as guantity, -- количество тразакций по списанию (активность)
       max(t.created_at)::date - min(t.created_at)::date as interval, -- интервал от первой до последней транзакции
       sum(value) as total_value
      from "transaction" t
      where  to_char(t.created_at, 'YYYY') = '2022' and type_id in (1,23,24,25,26,27,28,30)
      group by user_id
      having count(*) > 2 and sum(value) > 0) -- оставляем только тех пользователей, которые сделали хотя-бы 2 покупки, т.е. прослеживается хоть какая-то регулярность и исключаем транзакции, по которым по каким-то причинам не начислили списание 
select
  count (distinct user_id) as user_id, -- количество пользователей, которые сделали от 2х покупок
  round(avg(interval),1) as avg_int_write_off, -- средний интервал
  round(avg(guantity),1) as avg_guantity, -- средняя активность
  percentile_cont(0.25) within group (order by interval) as P25_avg_interval, -- 1 сегмент по интервалу
  percentile_cont(0.25) within group (order by guantity) as P25_avg_guantity, -- 1 сегмент по активности
  percentile_cont(0.50) within group (order by interval) as P50_avg_interval, -- 2 сегмент по интервалу
  percentile_cont(0.50) within group (order by guantity) as P50_avg_guantity, -- 2 сегмент по активности
  percentile_cont(0.75) within group (order by interval) as P75_avg_interval, -- 3 сегмент по интервалу
  percentile_cont(0.75) within group (order by guantity) as P75_avg_guantity  -- 3 сегмент по активности
from intervals
     
 -- Часть 3. Соотношение трат к начислениям:
 
 -- Важный вывод дает анализ соотношения списаний и начислений: медианное значение, равное нулю, свидетельствует о том, что значительная часть пользователей практически не тратит внутреннюю валюту и не формирует устойчивую платежную привычку. Есть группа пользователей, накопивших приличный баланс, что оначает, что переход к новой модели монетизации должен быть постепенным. Часть коинов можно направить на оплату подписок или функционала, а также оставить начиление коинов за выполнение некоторых достижений для более плавного перехода. Таким образом неполный отказ от CodeCoins является оптимальным решением, как инструмент удержания.
 Таким образом, сегментационный анализ указывает на необходимость гибридной модели, в которой основная монетизация переносится на подписку, а внутренняя валюта сохраняет вспомогательную мотивационную функцию.

 with total as(
      select
        user_id,
        sum (case when type_id in (1,23,24,25,26,27,28,30) then value else 0 end) as write_off,
        sum (case when type_id not in (1,23,24,25,26,27,28,30) then value else 0 end) as accural
      from "transaction" t 
      where  to_char(t.created_at, 'YYYY') = '2022'
      group by user_id),
      percent as(
      select
       user_id,
       round(write_off::numeric/accural::numeric*100,2) as perc_write_off
      from total
      where (write_off + accural) > 0) -- исключаем пользователей, по которым по каким-то причинам не оцифровались транзакции 
 select
     count (distinct user_id) as user_id,
     round(avg (perc_write_off),2) as avg_perc_write_off,
     percentile_cont(0.25) within group (order by perc_write_off) as P25_perc_write_off, -- 1 сегмент
     percentile_cont(0.50) within group (order by perc_write_off) as P50_perc_write_off, -- 2 сегмент
     percentile_cont(0.75) within group (order by perc_write_off) as P75_perc_write_off  -- 3 сегмент
 from percent


 #### Итоговый вывод по смене модели монетизации:

 Переход от монетизации через внутреннюю валюту CodeCoins к подписочной модели является обоснованным как с продуктовой, так и с экономической точки зрения.
 Текущая  система эффективно поддерживает вовлечение и геймификацию, однако слабо формирует регулярную выручку, поскольку пользователи в среднем получают больше коинов, чем тратят, а покупки совершаются нерегулярно и небольшими объемами.
 При этом данные подтверждают наличие платежного спроса: пользователи готовы платить за тесты, дополнительные задачи, решения и другие элементы расширенного контента. Это означает, что проблема заключается не в отсутствии интереса к платному функционалу, а в недостаточной эффективности действующей модели монетизации.
 Наиболее целесообразной для внедрения в первом приближении является гибридная модель, при которой базовый функционал и большая часть открытых задач остаются бесплатными, а подписка предоставляет доступ к дополнительным возможностям и премиальным материалам. При этом некоторую часть коинов можно зачесть в оплату, а также для более плавного перехода сохранить как инструмент для пообщрения активностию.
 С учетом пользовательского поведения наиболее обоснованной тарифной структурой являются подписки на 7 дней, 30 дней и 12 месяцев, ориентированные соответственно на краткосрочное, регулярное и долгосрочное использование.
 Таким образом, оптимальным решением является перенос основной коммерческой нагрузки на подписку при сохранении CodeCoins в качестве вспомогательного механизма удержания и вовлечения пользователей.



#### Дополнительное задание 2

-- Для выгрузки данных используем SQL-запрос (данные в такой ориентации, чтобы сократить запрос):

with activity as( 
     select
        'Problem' as category,
        extract (hour from created_at) as hour_num,   -- для сортировки
        extract (hour from created_at) || ':00' as hour_of_day,
        to_char(created_at, 'FMDay') as day_of_week,
        user_id
      from coderun
      union all
      select
        'Problem' as category,
        extract (hour from created_at) as hour_num,   -- для сортировки
        extract (hour from created_at) || ':00' as hour_of_day,
        to_char(created_at, 'FMDay') as day_of_week,
        user_id
      from codesubmit
      union all
      select
        'Test' as category,
        extract (hour from created_at) as hour_num,   -- для сортировки
        extract (hour from created_at) || ':00' as hour_of_day,
        to_char(created_at, 'FMDay') as day_of_week,
        user_id                       
      from teststart)
 select 
    hour_of_day,
    count (distinct case when day_of_week = 'Monday' then user_id end) as "Пн",
    count (distinct case when day_of_week = 'Tuesday' then user_id end) as "Вт",
    count (distinct case when day_of_week = 'Wednesday' then user_id end) as "Ср",
    count (distinct case when day_of_week = 'Thursday' then user_id end) as "Чт",
    count (distinct case when day_of_week = 'Friday' then user_id end) as "Пт",
    count (distinct case when day_of_week = 'Saturday' then user_id end) as "Сб",
    count (distinct case when day_of_week = 'Sunday' then user_id end) as "Вс"
 from activity
 group by hour_of_day, hour_num
 order by hour_num


 -- Дя загрузки данных, построения графика используем код:

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

# Загрузка данных из csv
df = pd.read_csv('E:\Учеба\Итоговый проект\график.csv', index_col='hour_of_day')
# Создаём новое окно для графика размером 14x10 дюймов
plt.figure(figsize=(14, 10))
# Строим тепловую карту (heatmap) с помощью библиотеки seaborn.
# df.T — транспонируем DataFrame: дни недели становятся строками, часы — столбцами.
# annot=True — отображаем значения в ячейках карты.
# fmt='g' — формат отображения чисел (без лишних нулей).
# cmap='YlOrRd' — используем цветовую палитру от жёлтого к красному (чем активнее, тем краснее).
# linewidths=0.5 — добавляем тонкие линии между ячейками для лучшей читаемости.
# cbar_kws={'label': 'Количество активностей'} — подписываем шкалу цветов.
# vmin=0, vmax=df.max().max() — задаём диапазон значений для цветовой шкалы (от 0 до максимального значения в таблице).
sns.heatmap(df.T, annot=True, fmt='g', cmap='YlOrRd',
            linewidths=0.5, cbar_kws={'label': 'Количество активностей'},
            vmin=0, vmax=df.max().max())
# Добавляем заголовок графика.
plt.title('Тепловая карта активности пользователей\nпо дням недели и часам',
          fontsize=18, fontweight='bold', pad=20)
# Подписываем оси графика.
plt.xlabel('Час дня', fontsize=14, fontweight='bold')
plt.ylabel('День недели', fontsize=14, fontweight='bold')
# Поворачиваем подписи по оси X на 45 градусов для лучшей читаемости.
plt.xticks(rotation=45, ha='right')
# Автоматически подстраиваем размеры элементов графика, чтобы ничего не обрезалось.
plt.tight_layout()
# Сохраняем получившийся график в файл с высоким разрешением (300 dpi).
plt.savefig('тепл_карта_активности.png', dpi=300, bbox_inches='tight')
plt.show()

Выводы:
Тепловая карта показывает, что наиболее эффективным временем для публикации продуктовых анонсов, промо-кампаний и запуска маркетинговых коммуникаций являются дневные и ранние вечерние часы, прежде всего интервал 10:00–13:00, а также, в качестве дополнительного окна, 17:00–19:00. Именно в эти периоды информация о новой подписке, специальных условиях или новых функциях будет охватывать максимальную долю активной аудитории.
Для технических релизов предпочтительно использовать периоды с наименьшей пользовательской активностью, то есть ночные часы, ориентировочно с 1:00 до 6:00. Это позволит минимизировать риски негативного пользовательского опыта в случае возникновения технических сбоев после выкладки изменений.
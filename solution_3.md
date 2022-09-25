Дополнительное задание 2. Вопросы СТО. SQL-запрос

with UsersActivity as 
(
select 
        created_at
from 
        teststart t 
union all
select 
        created_at 
from 
        coderun c  
union all
select 
        created_at 
from 
        codesubmit c2  
)
select 
        created_at,
        to_char(created_at, 'HH24:00') as hour,
        to_char(created_at, 'Day') as weekday,
        extract(isodow from created_at) as number_of_weekday
from UsersActivity




Дополнительное задание 2. Вопросы СТО. Python код 

import pandas as pd
import matplotlib.pyplot as plt 
%matplotlib inline

#прочитаем csv-файл из Jupyter Notebook
data = pd.read_csv("usersactivity_202209241901.csv")
data

#строим график активности по часам 
dataframe_hours = data[['created_at', 'hour']].groupby(['hour']).count().reset_index() 
plt.figure(figsize=(12,12))
x1 = dataframe_hours['hour']
y1 = dataframe_hours['created_at']
plt.subplot(2, 1, 1) #the figure has 2 rows, 1 column, and this plot is the first plot.
plt.subplots_adjust(hspace=0.3)
plt.title('Число пользователей с разбивкой по часам')
plt.xlabel('Время')
plt.ylabel('Пользователи')
plt.xticks(rotation=90) #Rotate axis text 
plt.plot(x1, y1, color="blue")
for i in range(len(x1)):
        plt.text(i, y1[i], y1[i], ha='center', va='bottom', fontweight='bold') #s - строка с текстом

#строим график активности по дням недели
dataframe_weekdays = data[['created_at','weekday','number_of_weekday']].groupby(['number_of_weekday','weekday']).count().reset_index()
plt.subplot(2, 1, 2) #the figure has 2 rows, 1 column, and this plot is the second plot.
y2 = dataframe_weekdays['weekday']
x2 = dataframe_weekdays['created_at']
plt.title('Число пользователей с разбивкой по дням недели')
plt.ylabel('День недели')
plt.xlabel('Пользователи')
plt.barh(y2, x2, color="blue")
for i, v in enumerate(x2):
    plt.text(v, i, " "+str(v), color='black', va='center', fontweight='bold')

Выводы: В среду и четверг люди проявляют наибольшую активность на платформе (13 593 и 13 767 человек соответственно) и, напротив, наименьшую активность - в выходные дни (9392 в субботу и 9475 чел. в воскресенье). 

В течение дня пик активности пользователей на платформе происходит в период с 13.00 до 14.00 (6017 человек), и меньше всего пользователей находится на платформе в период с 2.00 до 3.00 (288 человек). 

Соответственно оптимальное время на добавления нового функционала - время с наименьшей активностью на платформе, т.е с 0.00 до 3.00, чтобы своевременно устранить баги. Подходящим моментом для уведомления о выпуске релиза является среда и четверг накануне 13 часов, когда можно добиться максимального охвата аудитории. 

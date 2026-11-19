import pandas as pd
import matplotlib.pyplot as plt

## загружаем обе таблицы
df_hours = pd.read_csv('hours_active_users.csv') 
df_days = pd.read_csv('days_entry_users.csv')

## Будем строить два графика на одном полотне, чтобы потом выгрузить одним скриншотом
fig,axes = plt.subplots(nrows=2,ncols=1,figsize=(12,10))

ax1 = axes[0]
ax1.bar(df_hours.hour,df_hours.count_user_problem,color='steelblue',label='Задачи',alpha=0.7)
ax1.bar(df_hours.hour,df_hours.count_user_test,color='green',alpha=0.6,label='Тесты')
ax1.set_title('Активность пользователей по часам')
ax1.set_xticks(range(0,24))
ax1.set_ylabel('Активность')
ax1.set_xlabel('Час суток')
ax1.grid(axis='y', alpha=0.3)
ax1.legend(title='Тип активности',bbox_to_anchor=(1.05,1),loc='upper left')

ax2 = axes[1]
ax2.bar(df_days.day_name,df_days.count_users, color='red',label='Активность на платформе по дням')
ax2.set_title('Активность пользователей на платформе')
ax2.set_xlabel('Входы на платформу')
ax2.set_ylabel('День недели')
ax2.legend()
ax2.grid(axis='y', alpha=0.3)

plt.tight_layout(h_pad=2.5) ## немного раздвинем графики, т.к. легенда накладывается
plt.savefig('Avtive_users.png',dpi=300)
plt.show()

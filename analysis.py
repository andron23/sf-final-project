import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

sns.set_theme(style="whitegrid")

# Загружаем данные
df = pd.read_csv('activity_data.csv', sep=',')

# Переводим дни недели
days_map = {0: 'Вс', 1: 'Пн', 2: 'Вт', 3: 'Ср', 4: 'Чт', 5: 'Пт', 6: 'Сб'}
df['day_name'] = df['day_of_week'].map(days_map)

# График 1
plt.figure(figsize=(10, 5))
day_activity = df.groupby('day_name')['activity_count'].sum().reindex(['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'])
ax1 = day_activity.plot(kind='bar', color='skyblue', edgecolor='black')
plt.title('Суммарная активность пользователей по дням недели', fontsize=14)
plt.xlabel('День недели', fontsize=12)
plt.ylabel('Количество действий', fontsize=12)
plt.xticks(rotation=0)
for p in ax1.patches:
    ax1.annotate(str(int(p.get_height())), (p.get_x() + p.get_width() / 2., p.get_height()), ha='center', va='bottom')
plt.tight_layout()
plt.savefig('activity_by_day.png')
plt.show()

# График 2
plt.figure(figsize=(12, 5))
hour_activity = df.groupby('hour_of_day')['activity_count'].sum()
plt.plot(hour_activity.index, hour_activity.values, marker='o', color='orange', linewidth=2)
plt.title('Суммарная активность пользователей по часам суток', fontsize=14)
plt.xlabel('Час дня (0-23)', fontsize=12)
plt.ylabel('Количество действий', fontsize=12)
plt.xticks(range(0, 24))
plt.grid(True, alpha=0.5)
plt.tight_layout()
plt.savefig('activity_by_hour.png')
plt.show()

print("Графики успешно построены и сохранены в папку с проектом!")
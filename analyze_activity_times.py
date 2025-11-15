"""
Анализ времени активности пользователей на платформе IT Resume
Скрипт для определения оптимального времени для релизов
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# Настройка стиля графиков
plt.style.use('seaborn-v0_8-darkgrid')
sns.set_palette("husl")

# Загрузка данных из CSV файла
print("Загрузка данных...")
df = pd.read_csv('Query_results/activity_times.csv', parse_dates=['activity_time'])

# Преобразуем day_of_week в правильный формат (0=понедельник, 6=воскресенье)
# В PostgreSQL DOW: 0=воскресенье, поэтому преобразуем для удобства
df['day_of_week'] = df['activity_time'].dt.dayofweek  # 0=понедельник, 6=воскресенье
df['day_name'] = df['activity_time'].dt.day_name()
df['hour_of_day'] = df['activity_time'].dt.hour

print(f"Загружено {len(df):,} записей об активности")
print(f"Период данных: {df['activity_time'].min()} - {df['activity_time'].max()}")

# Создаем фигуру с несколькими графиками
fig, axes = plt.subplots(2, 2, figsize=(16, 12))
fig.suptitle('Анализ времени активности пользователей на платформе', fontsize=16, fontweight='bold')

# График 1: Распределение активности по дням недели
ax1 = axes[0, 0]
day_order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
day_counts = df['day_name'].value_counts().reindex(day_order)
day_counts.plot(kind='bar', ax=ax1, color='steelblue', edgecolor='black')
ax1.set_title('Активность по дням недели', fontsize=12, fontweight='bold')
ax1.set_xlabel('День недели', fontsize=10)
ax1.set_ylabel('Количество активностей', fontsize=10)
ax1.tick_params(axis='x', rotation=45)
ax1.grid(axis='y', alpha=0.3)

# Добавляем значения на столбцы
for i, v in enumerate(day_counts):
    if not pd.isna(v):
        ax1.text(i, v, f'{int(v):,}', ha='center', va='bottom', fontsize=9)

# График 2: Распределение активности по времени суток
ax2 = axes[0, 1]
hour_counts = df['hour_of_day'].value_counts().sort_index()
hour_counts.plot(kind='bar', ax=ax2, color='coral', edgecolor='black')
ax2.set_title('Активность по времени суток', fontsize=12, fontweight='bold')
ax2.set_xlabel('Час дня', fontsize=10)
ax2.set_ylabel('Количество активностей', fontsize=10)
ax2.tick_params(axis='x', rotation=0)
ax2.grid(axis='y', alpha=0.3)

# График 3: Тепловая карта активности (день недели × час дня)
ax3 = axes[1, 0]
heatmap_data = df.groupby(['day_name', 'hour_of_day']).size().unstack(fill_value=0)
heatmap_data = heatmap_data.reindex(day_order)
sns.heatmap(heatmap_data, ax=ax3, cmap='YlOrRd', annot=False, fmt='d', cbar_kws={'label': 'Количество активностей'})
ax3.set_title('Тепловая карта активности (День недели × Час дня)', fontsize=12, fontweight='bold')
ax3.set_xlabel('Час дня', fontsize=10)
ax3.set_ylabel('День недели', fontsize=10)

# График 4: Активность по типам действий по времени суток
ax4 = axes[1, 1]
activity_by_hour = df.groupby(['hour_of_day', 'activity_type']).size().unstack(fill_value=0)
activity_by_hour.plot(kind='line', ax=ax4, marker='o', linewidth=2, markersize=6)
ax4.set_title('Активность по типам действий по времени суток', fontsize=12, fontweight='bold')
ax4.set_xlabel('Час дня', fontsize=10)
ax4.set_ylabel('Количество активностей', fontsize=10)
ax4.legend(title='Тип активности', fontsize=9)
ax4.grid(alpha=0.3)

plt.tight_layout()
plt.savefig('activity_analysis.png', dpi=300, bbox_inches='tight')
print("\nГрафик сохранен в файл activity_analysis.png")

# Выводим статистику
print("\n" + "="*60)
print("СТАТИСТИКА ПО ДНЯМ НЕДЕЛИ")
print("="*60)
day_stats = df['day_name'].value_counts().reindex(day_order)
for day, count in day_stats.items():
    pct = (count / len(df)) * 100
    print(f"{day:15s}: {count:8,} активностей ({pct:5.2f}%)")

print("\n" + "="*60)
print("СТАТИСТИКА ПО ВРЕМЕНИ СУТОК")
print("="*60)
hour_stats = df['hour_of_day'].value_counts().sort_index()
for hour, count in hour_stats.items():
    pct = (count / len(df)) * 100
    print(f"Час {hour:2d}:00-{hour+1:2d}:00: {count:8,} активностей ({pct:5.2f}%)")

# Находим наименее активные периоды
print("\n" + "="*60)
print("НАИМЕНЕЕ АКТИВНЫЕ ПЕРИОДЫ (оптимальное время для релизов)")
print("="*60)
min_day = day_stats.idxmin()
min_day_count = day_stats.min()
min_hour = hour_stats.idxmin()
min_hour_count = hour_stats.min()

print(f"\nСамый неактивный день: {min_day} ({min_day_count:,} активностей)")
print(f"Самый неактивный час: {min_hour}:00-{min_hour+1}:00 ({min_hour_count:,} активностей)")

# Находим наименее активные комбинации день+час
print("\n" + "="*60)
print("ТОП-5 НАИМЕНЕЕ АКТИВНЫХ ПЕРИОДОВ (день + час)")
print("="*60)
period_counts = df.groupby(['day_name', 'hour_of_day']).size().reset_index(name='count')
period_counts = period_counts.sort_values('count').head(5)
for idx, row in period_counts.iterrows():
    print(f"{row['day_name']:15s} {row['hour_of_day']:2d}:00 - {row['count']:6,} активностей")

print("\n" + "="*60)
print("АНАЛИЗ ЗАВЕРШЕН")
print("="*60)


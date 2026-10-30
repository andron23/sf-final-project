# -*- coding: utf-8 -*-
"""
Построение графиков активности пользователей IT Resume по времени суток
и дням недели. Данные: user_activity.csv (выгрузка из PostgreSQL).

Запуск:  python plot_activity.py
Результат: activity_distributions.png
"""
import pandas as pd
import matplotlib.pyplot as plt

CSV_FILE = "user_activity.csv"
OUT_FILE = "activity_distributions.png"

DOW_NAMES = {1: "Пн", 2: "Вт", 3: "Ср", 4: "Чт", 5: "Пт", 6: "Сб", 7: "Вс"}

def main():
    df = pd.read_csv(CSV_FILE)

    visits = df[df["activity_type"] == "visit"]
    tasks = df[df["activity_type"] == "task_solve"]
    tests = df[df["activity_type"] == "test_start"]

    fig, axes = plt.subplots(2, 2, figsize=(15, 10))
    fig.suptitle("Активность пользователей IT Resume по времени", fontsize=15)

    # 1. Посещения по часам суток
    by_hour = visits.groupby("hour")["count"].sum().reindex(range(24), fill_value=0)
    axes[0, 0].bar(by_hour.index, by_hour.values, color="#4472c4")
    axes[0, 0].set_title("Посещения по часам суток")
    axes[0, 0].set_xlabel("Час")
    axes[0, 0].set_ylabel("Число визитов")
    axes[0, 0].set_xticks(range(0, 24, 2))

    # 2. Решение задач и прохождение тестов по часам
    axes[0, 1].plot(tasks.groupby("hour")["count"].sum().reindex(range(24), fill_value=0),
                    marker="o", label="Решение задач", color="#ed7d31")
    axes[0, 1].plot(tests.groupby("hour")["count"].sum().reindex(range(24), fill_value=0),
                    marker="s", label="Прохождение тестов", color="#70ad47")
    axes[0, 1].set_title("Решение задач / прохождение тестов по часам")
    axes[0, 1].set_xlabel("Час")
    axes[0, 1].set_ylabel("Число действий")
    axes[0, 1].set_xticks(range(0, 24, 2))
    axes[0, 1].legend()

    # 3. Посещения по дням недели
    by_dow = visits.groupby("day_of_week")["count"].sum().reindex(range(1, 8), fill_value=0)
    axes[1, 0].bar([DOW_NAMES[d] for d in by_dow.index], by_dow.values,
                   color=["#4472c4"] * 5 + ["#a5a5a5"] * 2)
    axes[1, 0].set_title("Посещения по дням недели")
    axes[1, 0].set_ylabel("Число визитов")

    # 4. Тепловая карта: посещения по дням недели и часам
    hm = (visits.pivot_table(index="day_of_week", columns="hour",
                             values="count", aggfunc="sum")
          .reindex(index=range(1, 8), columns=range(24), fill_value=0))
    im = axes[1, 1].imshow(hm.values, aspect="auto", cmap="YlGnBu")
    axes[1, 1].set_title("Тепловая карта посещений (день × час)")
    axes[1, 1].set_xlabel("Час")
    axes[1, 1].set_yticks(range(7))
    axes[1, 1].set_yticklabels([DOW_NAMES[d] for d in hm.index])
    axes[1, 1].set_xticks(range(0, 24, 2))
    fig.colorbar(im, ax=axes[1, 1], label="Визиты")

    plt.tight_layout()
    plt.savefig(OUT_FILE, dpi=150)
    print(f"Saved: {OUT_FILE}")

if __name__ == "__main__":
    main()

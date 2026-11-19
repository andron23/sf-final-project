import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

df = pd.read_csv('result_psql_tsk_1.csv')

df_plot = df.drop(columns=['count_users'])
df_plot = df_plot.set_index('month_cohort')

sns.set_theme(style='whitegrid')
plt.figure(figsize=(12,6))
sns.lineplot(data=df_plot.T)
plt.title('Кривая удержания:')
plt.xlabel('День жизни')
plt.ylabel('Процент удержания')
plt.ylim(0,105)
plt.legend(title='Когорта', loc='upper right')
plt.tight_layout()
plt.savefig('retention_curve.png',dpi=300)
plt.show()

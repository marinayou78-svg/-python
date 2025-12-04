# 1
# список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе без пропусков за указанный годовой период,
# средний чек за период с 01.06.2015 по 01.06.2016, 
# средняя сумма покупок за месяц, 
# количество всех операций по клиенту за период;

WITH monthly_t AS (
    SELECT t.ID_client,
		   DATE_FORMAT(t.date_new, '%Y-%m') AS transaction_month,
           SUM(t.Sum_payment) AS avg_check,
           COUNT(t.ID_check) AS count_check,
           SUM(c.Total_amount) AS sum_amount
    FROM Transactions t
    JOIN customers c ON t.Id_client=c.Id_client
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ID_client,DATE_FORMAT(date_new, '%Y-%m')
),
client_history AS (
    SELECT ID_client
    FROM monthly_t
    GROUP BY ID_client
    HAVING COUNT(DISTINCT transaction_month) = 12  
)
SELECT ch.ID_client,
	   ROUND(AVG(mt.avg_check),2) AS avg_check_all_period,  
	   ROUND(AVG(mt.sum_amount) / 12,2) AS avg_sum_amount, 
       SUM(mt.count_check) AS count_operations 
FROM client_history ch
JOIN monthly_t mt ON ch.ID_client = mt.ID_client
GROUP BY ch.ID_client;

# 2
# информацию в разрезе месяцев:
# средняя сумма чека в месяц;
# среднее количество операций в месяц;
# среднее количество клиентов, которые совершали операции;
# долю от общего количества операций за год и долю в месяц от общей суммы операций;
# вывести % соотношение M/F/NA в каждом месяце с их долей затрат

SELECT 
	DATE_FORMAT(date_new, '%Y-%m') AS month,    
	AVG(Sum_payment) AS avg_check,      
	COUNT(Id_check) AS operations_count,        
	COUNT(DISTINCT ID_client) AS clients_count            
FROM Transactions 
WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY DATE_FORMAT(date_new, '%Y-%m');

# вывести % соотношение M/F/NA в каждом месяце с их долей затрат

WITH monthly_stats AS (
    SELECT 
        DATE_FORMAT(t.date_new, '%Y-%m') AS month,    
        COUNT(DISTINCT t.ID_client) AS clients_count,
        COUNT(t.Id_check) AS operations_count,        
        SUM(t.Sum_payment) AS total_sum,             
        AVG(t.Sum_payment) AS avg_check         
    FROM Transactions t
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY DATE_FORMAT(t.date_new, '%Y-%m')
),
gender_distribution AS (
    SELECT
        DATE_FORMAT(t.date_new, '%Y-%m') AS month,
        SUM(CASE WHEN c.Gender = 'M' THEN t.Sum_payment ELSE 0 END) AS male_spent,
        SUM(CASE WHEN c.Gender = 'F' THEN t.Sum_payment ELSE 0 END) AS female_spent,
        SUM(CASE WHEN c.Gender IS NULL THEN t.Sum_payment ELSE 0 END) AS na_spent,
        COUNT(DISTINCT CASE WHEN c.Gender = 'M' THEN t.ID_client ELSE NULL END) AS male_count,
        COUNT(DISTINCT CASE WHEN c.Gender = 'F' THEN t.ID_client ELSE NULL END) AS female_count,
        COUNT(DISTINCT CASE WHEN c.Gender IS NULL THEN t.ID_client ELSE NULL END) AS na_count
    FROM Transactions t
    JOIN Customers c ON t.ID_client = c.ID_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY DATE_FORMAT(t.date_new, '%Y-%m')
)
SELECT 
    ms.month,
    gd.male_spent / ms.total_sum * 100 AS male_share,       
    gd.female_spent / ms.total_sum * 100 AS female_share,  
    gd.na_spent / ms.total_sum * 100 AS na_share,            
    gd.male_count / ms.clients_count * 100 AS male_count_share, 
    gd.female_count / ms.clients_count * 100 AS female_count_share, 
    gd.na_count / ms.clients_count * 100 AS na_count_share  
FROM 
    monthly_stats ms
    JOIN gender_distribution gd ON ms.month = gd.month
ORDER BY ms.month;

# доля от общего количества операций за год  и доля в месяц от общей суммы операций   

SELECT
	DATE_FORMAT(date_new, '%Y-%m') AS operation_month,
    COUNT(ID_client) AS clients_count,
    COUNT(Id_check) * 100.0 / SUM(COUNT(Id_check)) OVER () AS operation_share ,
    SUM(Sum_payment) * 100.0 / SUM(SUM(Sum_payment)) OVER () AS monthly_share
FROM
    Transactions
GROUP BY
    DATE_FORMAT(date_new, '%Y-%m')
ORDER BY
    DATE_FORMAT(date_new, '%Y-%m') ;

# 3
# возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации, 
# с параметрами сумма и количество операций за весь период, и поквартально - средние показатели и %.

WITH age_groups AS (
    SELECT ID_client,
           CASE 
               WHEN AGE BETWEEN 0 AND 9 THEN '0-9'
               WHEN AGE BETWEEN 10 AND 19 THEN '10-19'
               WHEN AGE BETWEEN 20 AND 29 THEN '20-29'
               WHEN AGE BETWEEN 30 AND 39 THEN '30-39'
               WHEN AGE BETWEEN 40 AND 49 THEN '40-49'
               WHEN AGE BETWEEN 50 AND 59 THEN '50-59'
               WHEN AGE BETWEEN 60 AND 69 THEN '60-69'
               WHEN AGE BETWEEN 70 AND 79 THEN '70-79'
               ELSE 'Unknown'
           END AS age_group
    FROM Customers
)
SELECT age_group, 
       COUNT(t.ID_check) AS operations_count, 
       SUM(t.Sum_payment) AS total_sum,
       AVG(Sum_payment) AS avg_payment_per_quarter,
       (COUNT(ID_check) * 100) / (SELECT COUNT(ID_check) 
								  FROM Transactions 
                                  WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01') AS percentage
FROM Transactions t
JOIN age_groups a ON t.ID_client = a.ID_client
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY age_group;
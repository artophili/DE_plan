CREATE TABLE credit_profiles (
	user_id INT,
	city VARCHAR(30) NOT NULL,
	credit_score INT NOT NULL,
	application_date DATE
);

INSERT INTO credit_profiles (user_id, city, credit_score, application_date)
VALUES
	(1,'Mumbai',720,'2026-10-05'),
	(2,'Pune',762,'2026-09-05'),
	(3,'Delhi',780,'2026-08-10'),
	(4,'Goa',720,'2026-09-05'),
	(4,'Goa',728,'2026-10-08');

SELECT * FROM credit_profiles;

--Latest application per user
WITH latest AS (SELECT *,
	ROW_NUMBER() OVER(
		PARTITION BY user_id
		ORDER BY application_date DESC)
	AS latest_application
FROM credit_profiles
ORDER BY latest_application)
SELECT * FROM latest WHERE latest_application = 1;

--The 2nd highest score within each city
SELECT city, credit_score,
	DENSE_RANK() OVER(
	PARTITION BY city
	ORDER BY credit_score DESC)
	AS highest_score_rank
FROM credit_profiles;

WITH RankedProfiles AS (
    SELECT city, credit_score,
        DENSE_RANK() OVER(
            PARTITION BY city
            ORDER BY credit_score DESC
        ) AS highest_score_rank
    FROM credit_profiles
)
SELECT city, credit_score
FROM RankedProfiles
WHERE highest_score_rank = 2;


--Adding more data
INSERT INTO credit_profiles (user_id, city, credit_score, application_date)
VALUES
	(1,'Mumbai',690,'2026-07-01'),
	(1,'Mumbai',705,'2026-08-15'),
	(1,'Mumbai',700,'2026-09-12'),
	(2,'Pune',770,'2026-07-20'),
	(2,'Pune',748,'2026-10-02'),
	(3,'Delhi',780,'2026-10-01'),
	(4,'Goa',735,'2026-08-01'),
	(5,'Mumbai',780,'2026-09-20'),
	(6,'Mumbai',745,'2026-09-25'),
	(7,'Pune',715,'2026-10-03'),
	(8,'Pune',762,'2026-10-04'),
	(9,'Delhi',700,'2026-09-15'),
	(10,'Nagpur',690,'2026-09-28');

SELECT * FROM credit_profiles;

--Each application with the user's previous score next to it
SELECT
	user_id,
	application_date,
	LAG(credit_score,1,0) OVER(PARTITION BY user_id ORDER BY credit_score) AS previous_score
FROM credit_profiles;

--The score change between consecutive applications, and a CASE column that labels it Improved, Dropped or No change
WITH score_change_table AS (
	SELECT
		user_id,
		application_date,
		credit_score,
		credit_score - LAG(credit_score,1,0) OVER(PARTITION BY user_id ORDER BY application_date) AS score_change
	FROM credit_profiles
)
SELECT
	user_id,
	application_date,
	score_change,
	CASE
		WHEN score_change > 0 THEN 'Improved'
		WHEN score_change < 0 THEN 'Dropped'
		ELSE 'No change'
	END AS Improvement
FROM score_change_table;
	

--The number of days since the user's previous application
SELECT * FROM credit_profiles;

WITH application_history AS (
SELECT
	user_id,
	application_date,
	LAG(application_date) OVER (PARTITION BY user_id ORDER BY application_date) AS prev_date
FROM credit_profiles
)
SELECT 
	user_id,
	application_date,
	(application_date - prev_date) AS days_since_last_application
FROM application_history;

--Only the users whose latest score is lower than their previous one.
WITH score_change_table AS (
	SELECT
		user_id,
		application_date,
		credit_score,
		credit_score - LAG(credit_score,1,0) OVER(PARTITION BY user_id ORDER BY application_date) AS score_change
	FROM credit_profiles
)
SELECT
	user_id,
	application_date,
	score_change
FROM score_change_table
WHERE score_change < 0;


--Cumulative Sums & Aggregations
CREATE TABLE transactions (
	txn_id INT PRIMARY KEY,
	account_id INT NOT NULL,
	txn_date DATE NOT NULL,
	txn_type VARCHAR(6) NOT NULL,
	amount DECIMAL(10,2) NOT NULL
);

INSERT INTO transactions (txn_id, account_id, txn_date, txn_type, amount)
VALUES
	(1,101,'2026-10-01','CREDIT',5000),
	(2,101,'2026-10-02','DEBIT',1200),
	(3,101,'2026-10-05','DEBIT',800),
	(4,101,'2026-10-05','CREDIT',2000),
	(5,101,'2026-10-08','DEBIT',1500),
	(6,102,'2026-10-01','CREDIT',1000),
	(7,102,'2026-10-03','DEBIT',1500),
	(8,102,'2026-10-06','CREDIT',2000),
	(9,102,'2026-10-09','DEBIT',700),
	(10,102,'2026-10-12','DEBIT',900),
	(11,103,'2026-10-02','CREDIT',3000),
	(12,103,'2026-10-04','DEBIT',500),
	(13,103,'2026-10-07','DEBIT',600),
	(14,103,'2026-10-10','CREDIT',1000),
	(15,103,'2026-10-11','DEBIT',400);


SELECT account_id FROM transactions;

--Running balance per account, treating credits as positive and debits as negative
SELECT
	account_id,
	SUM(CASE
			WHEN txn_type = 'CREDIT' THEN amount
			WHEN txn_type = 'DEBIT' THEN -amount
			ELSE 0
		END) AS Total_balance
FROM transactions
GROUP BY account_id;


SELECT
	account_id,
	txn_id,
	txn_date,
	txn_type,
	amount,
	SUM(CASE
			WHEN txn_type = 'CREDIT' THEN amount
			WHEN txn_type = 'DEBIT' THEN -amount
			ELSE 0
		END) OVER (PARTITION BY account_id ORDER BY txn_date, txn_id) AS Running_Balance
FROM transactions;

--Each transaction's amount as a percentage of its account's total
WITH total_amount AS (
	SELECT
		account_id,
		amount,
		-- Calculates the grand total for the account across all rows without squashing them
		SUM(CASE
				WHEN txn_type = 'CREDIT' THEN amount
				WHEN txn_type = 'DEBIT' THEN -amount
				ELSE 0
			END) OVER (PARTITION BY account_id) AS Total_balance
	FROM transactions
)
SELECT 
	account_id,
	amount,
	Total_balance,
	-- Calculates the individual transaction's percentage of the total account balance
	((amount / Total_balance) * 100) AS percentage
FROM total_amount;

SELECT * FROM credit_profiles;
--users whose latest score is above the average of everyone’s latest scores.
WITH latest_score AS (
SELECT user_id, city, credit_score,
    	ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY application_date DESC) AS rn
  FROM credit_profiles
),
avg_latest_score AS (
SELECT AVG(credit_score) FROM latest_score WHERE rn = 1
)
SELECT user_id, city, credit_score FROM latest_score WHERE rn = 1 AND credit_score > (SELECT * FROM avg_latest_score);

--Join execution mechanics
--A join takes two tables and pairs up rows whose key value matches.
--Every join type is the same pairing step. The only difference is what happens to rows that have no match
--INNER - Drops unmatched rows from both sides
--LEFT - Keeps every left row and fills the right column with NULL when there is no match
--FULL OUTER - Keeps unmatched rows from both sides
--CROSS - No matching happens so every left row pairs with every right row

--Duplicate keys multiply rows - If a key appears 2 times on left and 3 times on the right, then join gives 2*3 = 6 rows for that key
--Null never matches anything not even another null
--Database picks a method to perform join
--Nested join (For each left row, search the right)
--Hash join (Build a lookup table from the smaller side)
--Merge join (Sort both sides, then walk them together)

CREATE TABLE customers (customer_id INT, name VARCHAR(20));
INSERT INTO customers VALUES
  (1,'Asha'),(2,'Ravi'),(3,'Meera'),(4,'Karan'),(5,'Divya');

CREATE TABLE loans (loan_id INT, customer_id INT, amount INT);
INSERT INTO loans VALUES
  (101,1,50000),(102,1,30000),(103,2,80000),
  (104,4,20000),(105,6,45000),(106,NULL,10000);

SELECT * FROM customers;
SELECT * FROM loans;

--For inner - 4
SELECT * FROM loans l INNER JOIN customers c ON l.customer_id = c.customer_id;
--For left - 6
SELECT * FROM customers c LEFT JOIN loans l ON l.customer_id = c.customer_id;
SELECT * FROM customers c FULL OUTER JOIN loans l ON l.customer_id = c.customer_id;
--Cartesian product
SELECT * FROM customers c CROSS JOIN loans l;

--Customers with no loans
SELECT * FROM customers c LEFT JOIN loans l ON c.customer_id = l.customer_id WHERE l.loan_id IS NULL;

--Loans with no matching customers
SELECT * FROM loans l LEFT JOIN customers c ON l.customer_id = c.customer_id WHERE c.customer_id IS NULL;

--Creating a duplicate key problem
INSERT INTO customers VALUES (1,'Asha');
SELECT * FROM customers;

SELECT COUNT(*), SUM(l.amount) FROM loans l INNER JOIN customers c ON l.customer_id = c.customer_id;

--Removing duplicate keys risk by using CTE
WITH unique_customer AS (
SELECT customer_id, name, ROW_NUMBER() OVER (PARTITION BY customer_id) AS rn FROM customers
)
SELECT COUNT(*), SUM(l.amount) FROM loans l INNER JOIN unique_customer u ON l.customer_id = u.customer_id WHERE rn = 1;

--NULL means unknown or missing. It isn’t 0, and it isn’t an empty string
--SQL can’t say whether an unknown equals anything, comparisons with NULL give “unknown”\
--Where and ON keep only rows where the result is true.
--Comparisons skip NULL rows.
--Aggregates skip NULLs.
--Replacing NULLs changes the answer.

--Functions to return a replacement of null
--COALESCE(a, b, c) returns the first non-NULL value

CREATE TABLE applicants (applicant_id INT, name VARCHAR(20), mobile VARCHAR(12),
  city VARCHAR(20), income INT, credit_score INT);
INSERT INTO applicants VALUES
  (1,'Asha','9820011111','Mumbai',60000,720),
  (2,'Ravi',NULL,'Pune',45000,NULL),
  (3,'Meera','9820033333',NULL,NULL,690),
  (4,'Karan',NULL,NULL,52000,745),
  (5,'Divya','9820055555','Mumbai',NULL,NULL),
  (6,'Neel','9820066666','Delhi',70000,780),
  (7,'Zoya','','Goa',40000,710);

 SELECT * FROM applicants;

 SELECT COUNT(*) FROM applicants;
 SELECT COUNT(applicant_id), COUNT(name), COUNT(mobile), COUNT(city), COUNT(income), COUNT(credit_score) FROM applicants;

 SELECT AVG(income) FROM applicants;
 --53400.000000000000

 SELECT AVG(COALESCE(income, 0)) FROM applicants;
 --38142.857142857143

 SELECT * FROM applicants WHERE city <> 'Mumbai' 
 SELECT * FROM applicants WHERE city = 'Mumbai'

 SELECT *,
 	CASE WHEN mobile IS NOT NULL AND city IS NOT NULL AND income IS NOT NULL AND credit_Score IS NOT NULL THEN 'Complete'
 	ELSE 'Incomplete'
	END AS account_complete
FROM applicants;

UPDATE applicants SET mobile = NULLIF(mobile, '');

 SELECT *,
 	CASE WHEN mobile IS NOT NULL AND city IS NOT NULL AND income IS NOT NULL AND credit_Score IS NOT NULL THEN 'Complete'
 	ELSE 'Incomplete'
	END AS account_complete
FROM applicants;

CREATE TABLE blocked_cities (city VARCHAR(20));
INSERT INTO blocked_cities VALUES ('Pune'), (NULL);

SELECT * FROM applicants
WHERE city NOT IN (SELECT city FROM blocked_cities);

SELECT * FROM applicants a
WHERE NOT EXISTS (
    SELECT 1 FROM blocked_cities b
);
 
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

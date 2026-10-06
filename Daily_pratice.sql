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


	
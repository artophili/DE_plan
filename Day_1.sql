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



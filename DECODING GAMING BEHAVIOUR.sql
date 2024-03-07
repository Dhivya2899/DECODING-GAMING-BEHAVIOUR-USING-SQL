-- Create database
CREATE DATABASE GAME_ANALYSIS

-- Use database
USE GAME_ANALYSIS;

-- Alter table
alter table  player_details  modify L1_Status varchar(30);
alter table player_details  modify L2_Status varchar(30);
alter table player_details modify P_ID int primary key;
alter table player_details drop myunknowncolumn;
SELECT * FROM player_details;

alter table level_details  drop myunknowncolumn;
alter table level_details change timestamp start_datetime datetime;
alter table level_details modify Dev_Id varchar(10);
alter table level_details modify Difficulty varchar(15);
alter table level_details add primary key(P_ID,Dev_id,start_datetime);
SELECT * FROM level_details;

-- Display table 
SELECT * FROM player_details;
SELECT*FROM level_details;

-- 1. Extract `P_ID`, `Dev_ID`, `PName`, and `Difficulty_level` of all players at Level 0.
SELECT ld.P_ID, ld.Dev_ID, pd.PName, ld.Difficulty AS Difficulty_level
FROM level_details ld
JOIN player_details pd ON ld.P_ID = pd.P_ID
WHERE ld.Level = 0;


-- 2. Find `Level1_code`wise average `Kill_Count` where `lives_earned` is 2, and Stages_crossed at least 3
SELECT pd.L1_Code, AVG(ld.Kill_Count) AS Avg_Kill_Count
FROM level_details ld
JOIN player_details pd ON ld.P_ID = pd.P_ID
WHERE ld.Lives_Earned = 2 AND ld.Stages_crossed >= 3
GROUP BY pd.L1_Code;



-- 3. Find the total number of stages crossed at each difficulty level for Level 2 with players
-- using `zm_series` devices. Arrange the result in decreasing order of the total number of stages crossed. --
SELECT 
    ld.Difficulty,
    SUM(ld.Stages_crossed) AS Total_Stages_Crossed
FROM 
    level_details ld
JOIN 
    player_details pd ON ld.P_ID = pd.P_ID
WHERE 
    ld.Level = 2
    AND ld.Dev_ID LIKE 'zm_%'
GROUP BY 
    ld.Difficulty
ORDER BY 
    Total_Stages_Crossed DESC;


-- 4. Extract `P_ID` and the total number of unique dates for those players who have played games on multiple days.
SELECT ld.P_ID,
       COUNT(DISTINCT DATE(ld.start_datetime)) AS Total_Unique_Dates
FROM level_details ld
GROUP BY ld.P_ID
HAVING COUNT(DISTINCT DATE(ld.start_datetime)) > 1;


-- 5. Find `P_ID` and levelwise sum of `kill_counts` where `kill_count` is greater than the average kill count for Medium difficulty.
SELECT 
    ld.P_ID,
    ld.Level,
    SUM(ld.Kill_Count) AS Levelwise_Sum_of_Kill_Counts
FROM 
    level_details ld
WHERE 
    ld.Kill_Count > (
        SELECT 
            AVG(ld2.Kill_Count)
        FROM 
            level_details ld2
        WHERE 
            ld2.Difficulty = 'Medium'
    )
GROUP BY 
    ld.P_ID, ld.Level;

-- 6. Find `Level` and its corresponding `Level_code`wise sum of lives earned, excluding Level 0. Arrange in ascending order of level.
SELECT 
    ld.Level,
    pd.L1_Code AS Level_Code,
    SUM(ld.Lives_Earned) AS Total_Lives_Earned
FROM 
    level_details ld
JOIN 
    player_details pd ON ld.P_ID = pd.P_ID
WHERE 
    ld.Level > 0
GROUP BY 
    ld.Level, pd.L1_Code
ORDER BY 
    ld.Level ASC;


-- 7. Find the top 3 scores based on each `Dev_ID` and rank them in increasing order using `Row_Number`. Display the difficulty as well.
WITH RankedScores AS (
    SELECT 
        ld.P_ID,
        ld.Dev_ID,
        ld.Score,
        ld.Difficulty,
        ROW_NUMBER() OVER (PARTITION BY ld.Dev_ID ORDER BY ld.Score ASC) AS ScoreRank
    FROM 
        level_details ld
)
SELECT 
    Dev_ID,
    Score,
    Difficulty
FROM 
    RankedScores
WHERE 
    ScoreRank <= 3;

-- 8. Find the `first_login` datetime for each device ID.
SELECT Dev_ID, MIN(start_datetime) AS first_login
FROM level_details
GROUP BY Dev_ID;

-- 9. Find the top 5 scores based on each difficulty level and rank them in increasing order using `Rank`. Display `Dev_ID` as well.
WITH RankedScores AS (
    SELECT ld.Dev_ID,
           ld.difficulty,
           ld.score,
           RANK() OVER (PARTITION BY ld.difficulty ORDER BY ld.score DESC) AS score_rank
    FROM level_details ld
)
SELECT Dev_ID,
       difficulty,
       score
FROM RankedScores
WHERE score_rank <= 5;

-- 10. Find the device ID that is first logged in (based on `start_datetime`) for each player (`P_ID`). Output should contain player ID, device ID, and first login datetime.
SELECT ld.P_ID,
       ld.Dev_ID,
       ld.start_datetime AS first_login_datetime
FROM level_details ld
JOIN (
    SELECT P_ID,
           MIN(start_datetime) AS first_login_time
    FROM level_details
    GROUP BY P_ID
) AS first_login ON ld.P_ID = first_login.P_ID AND ld.start_datetime = first_login.first_login_time;

-- 11. For each player and date, determine how many `kill_counts` were played by the player so far.
-- a) Using window functions
SELECT P_ID,
       start_datetime,
       kill_count,
       SUM(kill_count) OVER (PARTITION BY P_ID ORDER BY start_datetime) AS cumulative_kill_count
FROM level_details;

-- b) Without window functions
SELECT ld.P_ID,
       ld.start_datetime,
       ld.kill_count,
       (SELECT SUM(kill_count)
        FROM level_details ld2
        WHERE ld2.P_ID = ld.P_ID AND ld2.start_datetime <= ld.start_datetime) AS cumulative_kill_count
FROM level_details ld;

-- 12. Find the cumulative sum of stages crossed over `start_datetime` for each `P_ID`, excluding the most recent `start_datetime`.
WITH CumulativeSum AS (
    SELECT P_ID,
           start_datetime,
           stages_crossed,
           SUM(stages_crossed) OVER (PARTITION BY P_ID ORDER BY start_datetime) AS cumulative_stages
    FROM level_details
)
SELECT P_ID,
       start_datetime,
       stages_crossed,
       cumulative_stages - LAG(stages_crossed, 1, 0) OVER (PARTITION BY P_ID ORDER BY start_datetime) AS cumulative_sum_excluding_latest
FROM CumulativeSum;

-- 13. Extract the top 3 highest sums of scores for each `Dev_ID` and the corresponding `P_ID`.
WITH RankedScores AS (
    SELECT Dev_ID,
           P_ID,
           SUM(score) AS total_score,
           RANK() OVER (PARTITION BY Dev_ID ORDER BY SUM(score) DESC) AS score_rank
    FROM level_details
    GROUP BY Dev_ID, P_ID
)
SELECT Dev_ID,
       P_ID,
       total_score
FROM RankedScores
WHERE score_rank <= 3;

-- 14. Find players who scored more than 50% of the average score, scored by the sum of scores for each `P_ID`.
WITH PlayerAverage AS (
    SELECT 
        P_ID,
        AVG(Score) AS AverageScore
    FROM 
        level_details
    GROUP BY 
        P_ID
)
SELECT 
    ld.P_ID,
    ld.Score
FROM 
    level_details ld
JOIN 
    PlayerAverage pa ON ld.P_ID = pa.P_ID
WHERE 
    ld.Score > 0.5 * pa.AverageScore;


-- 15. Create a stored procedure to find the top `n` `headshots_count` based on each `Dev_ID` and rank them in increasing order using `Row_Number`. Display the difficulty as we

DELIMITER //

CREATE PROCEDURE GetTopNHeadshots(IN n INT)
BEGIN
    SET @n = n;

    SELECT Dev_ID,
           difficulty,
           headshots_count,
           headshots_rank
    FROM (
        SELECT Dev_ID,
               difficulty,
               headshots_count,
               ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY headshots_count ASC) AS headshots_rank
        FROM level_details
    ) AS ranked_headshots
    WHERE headshots_rank <= @n;
END //

DELIMITER ;
CALL GetTopNHeadshots(5);



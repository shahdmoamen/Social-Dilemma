/*
ETL (Extract, Transform, Load) Process for Social Media Usage Data

This SQL script outlines the ETL process to extract, clean, and load data into a structured database tables. 
The dataset consists of demographic and social media usage details of individuals.

Steps:
1. **Extract**: 
   - Load raw CSV data containing information such as user demographics, platform usage, and behavioral patterns into a staging SQL table.
   
2. **Transform**: 
   - Clean and normalize the data by fixing inconsistencies 

3. **Load**: 
   - Insert the transformed data into the final SQL (facts and dimensions) for efficient querying and reporting.

This process ensures that the dataset is cleaned and organized, improving its usability for analysis.
*/

--1.extract
--extracted the data from the csv file to Time-Wasters on Social Media table via microsoft sql server

--rename the table 
EXEC sp_rename 'Time-Wasters on Social Media', 'SocialMediaData';

--2.tranform

-- Update country name 'Barzil' to 'Brazil'
UPDATE SocialMediaData
SET Location = 'Brazil'
WHERE Location = 'Barzil';

UPDATE SocialMediaData
SET Watch_Time = CAST(Watch_Time AS TIME);


--3.load 

--3.1)create the structure for the dimensions
--our data will have three dimensions 

/*
DimUser:
Purpose: This table stores demographic and personal information about users
who engage with social media platforms. 
It provides context for analyzing user behavior and patterns based on their characteristics. 
*/
CREATE TABLE DimUser (
    dimUserID INT PRIMARY KEY IDENTITY(1,1),
	userid int,
    Age INT,
    Gender VARCHAR(10),
    Location VARCHAR(50),
    Income DECIMAL(10, 2),
    Debt BIT,
    OwnsProperty BIT,
    Profession VARCHAR(50),
    Demographics VARCHAR(10)
);

/*
DimDevice:
Purpose: This table captures the types of devices used by users to access social media platforms,
providing insights into the technology landscape of social media engagement.
*/
CREATE TABLE DimDevice (
    DeviceID INT PRIMARY KEY IDENTITY(1,1),
    DeviceType VARCHAR(50),
    OS VARCHAR(50)
);

/*
DimWatchDetails:
Purpose: This table stores detailed information about the watching activities of users
on social media platforms,allowing for deep analysis of viewing behavior.
*/
CREATE TABLE DimWatchDetails (
    WatchDetailsID INT PRIMARY KEY IDENTITY(1,1),
    PlatformName VARCHAR(50),
    CurrentActivity VARCHAR(50),
    WatchReason VARCHAR(50),
    WatchTime TIME,
    ConnectionType VARCHAR(50),
    Video_Category NVARCHAR(50),
    Time_Spent_On_Video INT,  
    Video_Length INT      
);

--3.2)create the structure for the fact table
CREATE TABLE FactSocialMediaUsage (
    FactID INT PRIMARY KEY IDENTITY(1,1),
    dimUserID INT,
    WatchDetailsID INT,
    DeviceID INT,
    ProductivityLoss INT,
    Satisfaction INT,
    SelfControl INT,
    AddictionLevel INT,
    Frequency VARCHAR(50),
    Engagement INT,
    Number_of_Videos_Watched INT,
    Number_of_Sessions INT,
    Total_Time_Spent INT,
    Scroll_Rate INT,
    FOREIGN KEY (dimUserID) REFERENCES DimUser(dimUserID),
    FOREIGN KEY (WatchDetailsID) REFERENCES DimWatchDetails(WatchDetailsID),
    FOREIGN KEY (DeviceID) REFERENCES DimDevice(DeviceID)
);

--3.3)load into dimensions
INSERT INTO DimUser (userID,Age, Gender, Location, Income, Debt, OwnsProperty, Profession, Demographics)
SELECT DISTINCT userID,Age, Gender, Location, Income, Debt, Owns_Property, Profession, Demographics
FROM SocialMediaData;

INSERT INTO DimDevice (DeviceType, OS)
SELECT DISTINCT DeviceType, OS
FROM SocialMediaData;

INSERT INTO DimWatchDetails (PlatformName, CurrentActivity, WatchReason, WatchTime, ConnectionType, Video_Category, Time_Spent_On_Video, Video_Length)
SELECT DISTINCT 
    Platform,
    CurrentActivity,
    Watch_Reason,
    CAST(Watch_Time AS TIME),
    ConnectionType,
    Video_Category,
    Time_Spent_On_Video,  
    Video_Length          
FROM SocialMediaData;

--delete duplicates
WITH CTE_Duplicates AS (
    SELECT 
        WatchDetailsID,
        ROW_NUMBER() OVER (PARTITION BY 
            PlatformName, 
            CurrentActivity, 
            WatchReason, 
            WatchTime, 
            ConnectionType, 
            Video_Category 
        ORDER BY 
            WatchDetailsID) AS RowNum
    FROM 
        DimWatchDetails
)
DELETE FROM CTE_Duplicates
WHERE RowNum > 1;

WITH CTE AS (
   SELECT *,
          ROW_NUMBER() OVER (PARTITION BY devicetype,os ORDER BY deviceID) AS RowNum
   FROM Dimdevice
)
DELETE FROM CTE WHERE RowNum > 1;

--3.4)load the fact
INSERT INTO  FactSocialMediaUsage (
    dimUserID, WatchDetailsID, DeviceID, ProductivityLoss, Satisfaction, SelfControl, 
    AddictionLevel, Frequency,  
    Engagement, Number_of_Videos_Watched, Number_of_Sessions, 
    Total_Time_Spent, Scroll_Rate
)
SELECT 
    u.dimUserID,
    wd.WatchDetailsID,
    d.DeviceID,
    s.ProductivityLoss,
    s.Satisfaction,
    s.Self_Control,
    s.Addiction_Level,
    s.Frequency,
    s.Engagement,
    s.Number_of_Videos_Watched,
    s.Number_of_Sessions,
    s.Total_Time_Spent,
    s.Scroll_Rate
FROM SocialMediaData s
JOIN DimUser u ON s.userID = u.userID
JOIN DimWatchDetails wd ON s.Platform = wd.PlatformName
    AND s.CurrentActivity = wd.CurrentActivity
    AND s.Watch_Reason = wd.WatchReason
    AND CAST(s.Watch_Time AS TIME) = wd.WatchTime
	AND s.ConnectionType  = wd.ConnectionType 
JOIN DimDevice d ON s.DeviceType = d.DeviceType AND s.OS = d.OS;

-------------------------------------------------------------------------------------------------------------
--Exploratry data analysis and statistical analysis

--view the head of the data
SELECT TOP 10 *
FROM FactSocialMediaUsage;

SELECT TOP 10 
    *
FROM FactSocialMediaUsage fsu
JOIN DimUser u ON fsu.dimUserID = u.dimUserID
JOIN DimWatchDetails wd ON fsu.WatchDetailsID = wd.WatchDetailsID
JOIN DimDevice d ON fsu.DeviceID = d.DeviceID;

--count of fact rows
SELECT COUNT(*)
FROM FactSocialMediaUsage;

--Fact summary statistcs 
SELECT 
    COUNT(fsu.FactID) AS Total_Records,
    AVG(fsu.Total_Time_Spent) AS Avg_Total_Time_Spent,
    SUM(fsu.Total_Time_Spent) AS Total_Time_Spent,
    MIN(fsu.Total_Time_Spent) AS Min_Time_Spent,
    MAX(fsu.Total_Time_Spent) AS Max_Time_Spent,
    AVG(fsu.ProductivityLoss) AS Avg_ProductivityLoss,
    MIN(fsu.ProductivityLoss) AS Min_ProductivityLoss,
    MAX(fsu.ProductivityLoss) AS Max_ProductivityLoss,
    AVG(fsu.AddictionLevel) AS Avg_AddictionLevel,
    MIN(fsu.AddictionLevel) AS Min_AddictionLevel,
    MAX(fsu.AddictionLevel) AS Max_AddictionLevel
FROM FactSocialMediaUsage fsu

--  Dimensions summary statistics
SELECT 
    COUNT(*) AS Total_Users,
    AVG(Age) AS Avg_Age,
    MIN(Age) AS Min_Age,
    MAX(Age) AS Max_Age,
    COUNT(DISTINCT Gender) AS Unique_Genders,
    AVG(Income) AS Avg_Income,
    MIN(Income) AS Min_Income,
    MAX(Income) AS Max_Income
FROM DimUser;

SELECT 
    COUNT(DISTINCT Video_Category) AS Unique_Video_Categories,
    COUNT(DISTINCT PlatformName) AS Unique_Platforms,
    COUNT(DISTINCT WatchReason) AS Unique_Watch_Reasons
FROM DimWatchDetails;

SELECT 
    COUNT(*) AS Total_Devices,
    COUNT(DISTINCT DeviceType) AS Unique_Device_Types,
    COUNT(DISTINCT OS) AS Unique_OS
FROM DimDevice;


--check for duplicates
SELECT 
     WatchDetailsID, 
    dimUserID, 
    DeviceID, 
    ProductivityLoss,
    Satisfaction,
    SelfControl,
    AddictionLevel,
    Frequency,
    Engagement,
    Number_of_Videos_Watched,
    Number_of_Sessions,
    Total_Time_Spent,
    Scroll_Rate,
    COUNT(*) AS DuplicateCount
FROM 
    FactSocialMediaUsage
GROUP BY
    WatchDetailsID, 
    dimUserID, 
    DeviceID, 
    ProductivityLoss,
    Satisfaction,
    SelfControl,
    AddictionLevel,
    Frequency,
    Engagement,
    Number_of_Videos_Watched,
    Number_of_Sessions,
    Total_Time_Spent,
    Scroll_Rate
HAVING 
    COUNT(*) > 1; 
/* No duplicates found */

--check outliars
WITH Quartiles AS (
    SELECT 
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Total_Time_Spent) OVER () AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Total_Time_Spent) OVER () AS Q3
    FROM 
        FactSocialMediaUsage
),
IQR_Calculation AS (
    SELECT 
        Q1,
        Q3,
        (Q3 - Q1) AS IQR
    FROM 
        Quartiles
    GROUP BY Q1, Q3 
)
SELECT 
    fsu.*,
    CASE 
        WHEN fsu.Total_Time_Spent < (q.Q1 - 1.5 * q.IQR) THEN 'Lower Outlier'
        WHEN fsu.Total_Time_Spent > (q.Q3 + 1.5 * q.IQR) THEN 'Upper Outlier'
    END AS Outlier_Status
FROM 
    FactSocialMediaUsage fsu
CROSS JOIN 
    IQR_Calculation q
WHERE 
    fsu.Total_Time_Spent IS NOT NULL
    AND (fsu.Total_Time_Spent < (q.Q1 - 1.5 * q.IQR) OR fsu.Total_Time_Spent > (q.Q3 + 1.5 * q.IQR));
/*completed the outliar detection in python and no outliars found*/

--Calculate the correlation between Total_Time_Spent and Addiction_Level.
WITH Stats AS (
    SELECT 
        COUNT(*) AS n,
        SUM(CAST(Total_Time_Spent AS FLOAT)) AS Sum_X,
        SUM(CAST(AddictionLevel AS FLOAT)) AS Sum_Y,
        SUM(CAST(Total_Time_Spent AS FLOAT) * CAST(AddictionLevel AS FLOAT)) AS Sum_XY,
        SUM(CAST(Total_Time_Spent AS FLOAT) * CAST(Total_Time_Spent AS FLOAT)) AS Sum_X2,
        SUM(CAST(AddictionLevel AS FLOAT) * CAST(AddictionLevel AS FLOAT)) AS Sum_Y2
    FROM 
        FactSocialMediaUsage
)
SELECT 
    (n * Sum_XY - Sum_X * Sum_Y) / 
    (SQRT(n * Sum_X2 - Sum_X * Sum_X) * SQRT(n * Sum_Y2 - Sum_Y * Sum_Y)) AS Correlation
FROM 
    Stats;
/* a heatmap is done in python to identify the correallation between all the columns */

SELECT 
    Gender,
	Profession,
    COUNT(*) AS UserCount,
    AVG(Age) AS AvgAge,
    AVG(Income) AS AvgIncome,
    SUM(CASE WHEN Debt = 1 THEN 1 ELSE 0 END) AS UsersWithDebt,
    SUM(CASE WHEN OwnsProperty = 1 THEN 1 ELSE 0 END) AS UsersOwningProperty
FROM 
    DimUser
GROUP BY 
    Gender, Profession
ORDER BY 
    UserCount DESC;


SELECT 
    PlatformName,
    AVG(Time_Spent_On_Video) AS AvgTimeSpent,
    AVG(Video_Length) AS AvgVideoLength
FROM 
    DimWatchDetails
GROUP BY 
    PlatformName

SELECT AVG(fsu.AddictionLevel) AS AvgAddictionLevel, AVG(fsu.SelfControl) AS AvgSelfControl
FROM FactSocialMediaUsage fsu;
---------------------------------------------------------------------------------------------------------------------------------
--1. Platform and Device Usage
-- This section analyzes the usage of different platforms and devices 
-- by counting total watches, average time spent, satisfaction levels, 
-- and total sessions.

-- Query to get the total number of watches per platform
SELECT wd.PlatformName, COUNT(fact.FactID) AS Total_Watches
FROM FactSocialMediaUsage fact
JOIN DimWatchDetails wd ON fact.WatchDetailsID = wd.WatchDetailsID
GROUP BY wd.PlatformName
ORDER BY Total_Watches DESC;

-- Query to calculate the average and total time spent by device type
SELECT d.DeviceType, 
       AVG(fact.Total_Time_Spent) AS Avg_Time_Spent, 
       SUM(fact.Total_Time_Spent) AS TotalTimeSpent
FROM FactSocialMediaUsage fact
JOIN DimDevice d ON fact.DeviceID = d.DeviceID
GROUP BY d.DeviceType
ORDER BY Avg_Time_Spent DESC;

-- Query to get the total sessions per device type
SELECT d.DeviceType, SUM(fact.Number_of_Sessions) AS Total_Sessions
FROM FactSocialMediaUsage fact
JOIN DimDevice d ON fact.DeviceID = d.DeviceID
GROUP BY d.DeviceType
ORDER BY Total_Sessions DESC;

-- Query to calculate the average satisfaction per device type
SELECT d.DeviceType, AVG(fact.Satisfaction) AS Avg_Satisfaction
FROM FactSocialMediaUsage fact
JOIN DimDevice d ON fact.DeviceID = d.DeviceID
GROUP BY d.DeviceType
ORDER BY Avg_Satisfaction DESC;

-- Query to calculate the average satisfaction per platform
SELECT wd.PlatformName, AVG(fact.Satisfaction) AS Avg_Satisfaction
FROM FactSocialMediaUsage fact
JOIN DimWatchDetails wd ON fact.WatchDetailsID = wd.WatchDetailsID
GROUP BY wd.PlatformName
ORDER BY Avg_Satisfaction DESC;


/*
1. Platform Usage
Total Watches by Platform: TikTok is the most popular among users.

2. Device Usage and total sessions: Smartphones are the main device for watching content and have the highest sessions.

3. Satisfaction Levels

Average Satisfaction by Device:
Users like tablets more as Tablets offer a larger screen size than smartphones, 
making them more comfortable for users to engage with content

Average Satisfaction by Platform:
All platforms have an average satisfaction of 4 so, Satisfaction is okay, but it can improve.

***********Recommendations**********
Optimize for Mobile:
-Make sure content is good for and seen enough on smartphones since users spend a lot of time there.
-recommend on smartphones company increase mobiles sizes

Engage with TikTok:
Since TikTok is popular, invest in creative content for this platform.

Gather Feedback:
Ask users for their opinions to understand how to improve satisfaction.

Use Session Data:
Use the data on sessions to create marketing strategies.

*/

-----------------------------------------------------------------------------------------------------------------------------------------------------
--2. User Demographics
-- This section analyzes user demographics by age and income, 
-- summarizing metrics such as productivity loss, addiction level, 
-- self-control, satisfaction, and total time spent.

-- Query to analyze productivity loss, addiction level, self-control, 
-- satisfaction, and total time spent by age group
SELECT 
  CASE 
    WHEN u.Age BETWEEN 18 AND 25 THEN '18-25'
    WHEN u.Age BETWEEN 26 AND 35 THEN '26-35'
    WHEN u.Age BETWEEN 36 AND 45 THEN '36-45'
    WHEN u.Age BETWEEN 46 AND 55 THEN '46-55'
    WHEN u.Age BETWEEN 56 AND 65 THEN '56-65'
    ELSE '66+' 
  END AS AgeGroup,
  AVG(fact.ProductivityLoss) AS Avg_ProductivityLoss,
  AVG(fact.AddictionLevel) AS Avg_AddictionLevel,
  AVG(fact.SelfControl) AS Avg_SelfControl,
  AVG(fact.Satisfaction) AS Avg_Satisfaction,
  AVG(fact.Total_Time_Spent) AS Avg_Total_Time_Spent
FROM FactSocialMediaUsage fact
JOIN DimUser u ON fact.dimUserID = u.dimUserID
GROUP BY 
  CASE 
    WHEN u.Age BETWEEN 18 AND 25 THEN '18-25'
    WHEN u.Age BETWEEN 26 AND 35 THEN '26-35'
    WHEN u.Age BETWEEN 36 AND 45 THEN '36-45'
    WHEN u.Age BETWEEN 46 AND 55 THEN '46-55'
    WHEN u.Age BETWEEN 56 AND 65 THEN '56-65'
    ELSE '66+' 
  END
ORDER BY AgeGroup;

-- Query to analyze productivity loss, addiction level, self-control, 
-- satisfaction, and total time spent by income group
SELECT 
  CASE 
    WHEN u.Income BETWEEN 0 AND 25000 THEN '0-25k'
    WHEN u.Income BETWEEN 25001 AND 50000 THEN '25k-50k'
    WHEN u.Income BETWEEN 50001 AND 75000 THEN '50k-75k'
    WHEN u.Income BETWEEN 75001 AND 100000 THEN '75k-100k'
    ELSE '100k+' 
  END AS IncomeGroup,
  AVG(fact.ProductivityLoss) AS Avg_ProductivityLoss,
  AVG(fact.AddictionLevel) AS Avg_AddictionLevel,
  AVG(fact.SelfControl) AS Avg_SelfControl,
  AVG(fact.Satisfaction) AS Avg_Satisfaction,
  AVG(fact.Total_Time_Spent) AS Avg_Total_Time_Spent -- Adding total time spent here
FROM FactSocialMediaUsage fact
JOIN DimUser u ON fact.dimUserID = u.dimUserID
GROUP BY 
  CASE 
    WHEN u.Income BETWEEN 0 AND 25000 THEN '0-25k'
    WHEN u.Income BETWEEN 25001 AND 50000 THEN '25k-50k'
    WHEN u.Income BETWEEN 50001 AND 75000 THEN '50k-75k'
    WHEN u.Income BETWEEN 75001 AND 100000 THEN '75k-100k'
    ELSE '100k+' 
  END
ORDER BY IncomeGroup;

-- Query to calculate total time spent by gender
SELECT 
  u.Gender,
  SUM(fact.Total_Time_Spent) AS Total_Time_Spent
FROM FactSocialMediaUsage fact
JOIN DimUser u ON fact.dimUserID = u.dimUserID
GROUP BY u.Gender
ORDER BY Total_Time_Spent DESC;

-- Query to count users per platform segmented by gender
SELECT 
  watch.PlatformName,
  u.Gender,
  COUNT(*) AS User_Count
FROM FactSocialMediaUsage fact
JOIN DimUser u ON fact.dimUserID = u.dimUserID
JOIN DimWatchDetails watch ON fact.WatchDetailsID = watch.WatchDetailsID
GROUP BY watch.PlatformName, u.Gender
ORDER BY watch.PlatformName, u.Gender;

-- Query to analyze total time spent and number of users by platform and country
SELECT 
    wd.PlatformName,
    u.Location AS Country,
    SUM(fact.Total_Time_Spent) AS Total_Time_Spent,
    COUNT(fact.dimUserID) AS Number_of_Users
FROM FactSocialMediaUsage fact
JOIN DimUser u ON fact.dimUserID = u.dimUserID
JOIN DimWatchDetails wd ON fact.WatchDetailsID = wd.WatchDetailsID
GROUP BY 
    wd.PlatformName,
    u.Location
ORDER BY 
    u.Location, 
    wd.PlatformName;

-- Query to calculate average addiction level by country
SELECT u.Location, AVG(fact.AddictionLevel) AS Avg_AddictionLevel
FROM FactSocialMediaUsage fact
JOIN DimUser u ON fact.dimUserID = u.dimUserID
GROUP BY u.Location
ORDER BY Avg_AddictionLevel DESC;

-- Query to calculate average satisfaction by country
SELECT u.Location, AVG(fact.Satisfaction) AS Avg_Satisfaction
FROM FactSocialMediaUsage fact
JOIN DimUser u ON fact.dimUserID = u.dimUserID
GROUP BY u.Location
ORDER BY Avg_Satisfaction DESC;

-- Query to analyze total time spent by profession
SELECT 
    u.Profession, 
    SUM(fact.Total_Time_Spent) AS Total_Time_Spent
FROM FactSocialMediaUsage fact
JOIN DimUser u ON fact.dimUserID = u.dimUserID
GROUP BY u.Profession
ORDER BY Total_Time_Spent DESC;

-- Query to analyze total time spent by current activity
SELECT 
    wd.CurrentActivity,
    SUM(fact.Total_Time_Spent) AS Total_Time_Spent
FROM FactSocialMediaUsage fact
JOIN DimWatchDetails wd ON fact.WatchDetailsID = wd.WatchDetailsID
GROUP BY wd.CurrentActivity
ORDER BY Total_Time_Spent DESC;

/*
1. Age Groups:
Younger users (18-35) feel social media makes them less productive (score of 5). Older users (36-65) feel more addicted (score of 3).
Satisfaction scores are low (4-5) for all ages, showing users want better experiences.
Time spent on social media is similar across age groups.

Income Groups:
Lower-income users (0-25k) feel more addicted (score of 3) than higher-income users. 
All income groups report low satisfaction.

Gender Usage:
TikTok and Instagram have a balanced number of male and female users, while Facebook has more male users.

Geographic Differences:
Users in India spend the most time on TikTok and Instagram. Users in the U.S. and Brazil feel more addicted (score of 5).

************Recommendations******************

Content for Young Users:
Create content that helps young users manage their time better and promotes productivity.

Support for Low-Income Users:
Provide resources to help lower-income users control their social media use and how they can increase their income.

Marketing:
Develop marketing strategie to different genders.

Improve User Experience:
Make changes to improve satisfaction across all users, based on feedback.

Tailor Campaigns by Country:
Use country data to create campaigns that match local interests.

Monitor Addiction Levels:
Keep checking addiction levels and adjust strategies to encourage healthier social media use.
*/
-----------------------------------------------------------------------------------------------------------------------------------------------------
--3. Content and Time
-- This section examines the content consumption patterns, 
-- including total time spent on different video categories, 
-- watch reasons, and the overall engagement.

-- Query to analyze total watch time based on time spent on videos
SELECT dwd.Video_Category, SUM(dwd.Time_Spent_On_Video) AS TotalWatchTime
FROM FactSocialMediaUsage fsu
JOIN DimWatchDetails dwd ON fsu.WatchDetailsID = dwd.WatchDetailsID
GROUP BY dwd.Video_Category
ORDER BY TotalWatchTime DESC;

-- Query to analyze average addiction level based on watch reasons
SELECT dwd.WatchReason, AVG(fsu.AddictionLevel) AS AvgAddictionLevel
FROM FactSocialMediaUsage fsu
JOIN DimWatchDetails dwd ON fsu.WatchDetailsID = dwd.WatchDetailsID
GROUP BY dwd.WatchReason
ORDER BY AvgAddictionLevel DESC;

-- Query to count the number of unique users for each watch reason
SELECT 
    wd.WatchReason,
    COUNT(DISTINCT u.dimUserID) AS Number_of_Users
FROM FactSocialMediaUsage fact
JOIN DimUser u ON fact.dimUserID = u.dimUserID
JOIN DimWatchDetails wd ON fact.WatchDetailsID = wd.WatchDetailsID
GROUP BY 
    wd.WatchReason
ORDER BY 
    Number_of_Users DESC;

-- Query to analyze total time spent based on watch time
SELECT dwd.WatchTime, SUM(fsu.Total_Time_Spent) AS TotalTimeSpent
FROM FactSocialMediaUsage fsu
JOIN DimWatchDetails dwd ON fsu.WatchDetailsID = dwd.WatchDetailsID
GROUP BY dwd.WatchTime
ORDER BY TotalTimeSpent DESC;

/*
Insights

Watch Time:
Jokes/Memes have the highest watch time (2,301 hours)

Reasons for Watching:
People watch videos for Habit This means many users watch videos without thinking.

Viewing Times:
Users watch the most at 14:00 (24,532 minutes). Other busy times are 21:00 (17,828 minutes) and 17:00 (13,592 minutes).

*************Recommendations*****************
Create More Content:
Focus on Entertainment and Jokes/Memes because these categories get the most views.
Make content for users who watch because of Boredom and Procrastination since they show higher addiction.

Best Times to Release Content:
Release new videos in the afternoon and evening when users watch the most.

Explore Other Categories:
Consider making content in less popular categories like Life Hacks to attract more viewers.

*/

-----------------------------------------------------------------------------------------------------------------------------------------------------

USE ig_clone;
SHOW TABLES;

-- OBJECTIVE QUESTIONS 
/**1. Are there any tables with duplicate or missing null values? If so, how would you handle them?
 - Checking Duplicate or NULL Values**/
 
-- users
SELECT COUNT(*) AS null_usernames 
FROM users
WHERE id IS NULL OR username IS NULL OR created_at IS NULL;
SHOW COLUMNS FROM photos;
-- photos
SELECT * FROM photos
WHERE id IS NULL OR image_url IS NULL OR user_id IS NULL OR created_dat IS NULL;

-- comments
SELECT * FROM comments
WHERE id IS NULL OR comment_text IS NULL OR user_id IS NULL OR photo_id IS NULL OR created_at IS NULL;

-- likes
SELECT * FROM likes
WHERE user_id IS NULL OR photo_id IS NULL OR created_at IS NULL;

-- follows
SELECT * FROM follows
WHERE follower_id IS NULL OR followee_id IS NULL OR created_at IS NULL;

-- tags
SELECT * FROM tags
WHERE id IS NULL OR tag_name IS NULL OR created_at IS NULL;

-- photo_tags
SELECT * FROM photo_tags
WHERE photo_id IS NULL OR tag_id IS NULL;

/*Checking for Duplicate Records*/

-- users
SELECT username, COUNT(*) FROM users GROUP BY username HAVING COUNT(*) > 1;

-- photos
SELECT image_url, COUNT(*) FROM photos GROUP BY image_url HAVING COUNT(*) > 1;

-- comments
SELECT comment_text, user_id, photo_id, COUNT(*)
FROM comments
GROUP BY comment_text, user_id, photo_id
HAVING COUNT(*) > 1;

-- tags
SELECT tag_name, COUNT(*) FROM tags GROUP BY tag_name HAVING COUNT(*) > 1;

/** Q.2. What is the distribution of user activity levels (e.g., number ofposts, likes, comments) across the user base?
 **/ 

SELECT activity_level, COUNT(*) AS total_users
FROM(SELECT u.id, u.username, COUNT(DISTINCT p.id) AS total_posts,
COUNT(DISTINCT l.photo_id) AS total_likes, COUNT(DISTINCT c.id) AS total_comments, (COUNT(DISTINCT p.id) + COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id))
AS total_activity,
CASE 
WHEN(COUNT(DISTINCT p.id) + COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id)) =0 
THEN 'Inactive'
WHEN (COUNT(DISTINCT p.id) + COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id)) BETWEEN 1 AND 50
THEN 'Low Activity'
When (COUNT(DISTINCT p.id) + COUNT(DISTINCT l.photo_id)+ COUNT(DISTINCT c.id)) BETWEEN 51 AND 200 
THEN 'Medium Activity'
ELSE 'High Activity'
END AS activity_level
FROM users u
LEFT JOIN photos p
ON u.id = p.user_id
LEFT JOIN likes l
ON u.id = l.user_id
LEFT JOIN comments c 
ON u.id = c.user_id
GROUP BY u.id, u.username) AS activity_summary GROUP BY activity_level 
ORDER BY total_users DESC;

/** 3. Calculate the average number of tags per post (photo_tags and
photos tables). **/

SELECT ROUND(AVG(tag_count), 2) AS avg_tags_per_post
FROM (SELECT p.id AS photo_id, COUNT(pt.tag_id) AS tag_count
FROM photos p
LEFT JOIN photo_tags pt
ON p.id = pt.photo_id
GROUP BY p.id
) AS tag_summary;

/** 4. Identify the top users with the highest engagement rates (likes,
comments) on their posts and rank them.**/

SELECT u.id, u.username, COUNT(DISTINCT l.user_id) AS total_likes, COUNT(DISTINCT c.id) AS total_comments,
    (COUNT(DISTINCT l.user_id) + COUNT(DISTINCT c.id)) AS total_engagement,
    RANK() OVER (ORDER BY (COUNT(DISTINCT l.user_id) + COUNT(DISTINCT c.id)) DESC) AS engagement_rank
FROM users u
JOIN photos p
    ON u.id = p.user_id
LEFT JOIN likes l
    ON p.id = l.photo_id
LEFT JOIN comments c
    ON p.id = c.photo_id
GROUP BY u.id, u.username
ORDER BY total_engagement desc;

/**Q.5 Which users have the highest number of followers and followings? **/

SELECT 
    u.id,
    u.username,
    COUNT(DISTINCT f1.follower_id) AS total_followers,
    COUNT(DISTINCT f2.followee_id) AS total_following
FROM users u
LEFT JOIN follows f1
    ON u.id = f1.followee_id
LEFT JOIN follows f2
    ON u.id = f2.follower_id
GROUP BY u.id, u.username
ORDER BY total_followers DESC;

/** 6. Calculate the average engagement rate (likes, comments) per post
for each user **/ 

SELECT u.id, u.username, COUNT(DISTINCT p.id) AS total_posts, COUNT(DISTINCT l.user_id) AS total_likes, 
COUNT(DISTINCT c.id) AS total_comments,
    ROUND((COUNT(DISTINCT l.user_id) + COUNT(DISTINCT c.id)) / COUNT(DISTINCT p.id), 2) AS avg_engagement_per_post
FROM users u
JOIN photos p
    ON u.id = p.user_id
LEFT JOIN likes l
    ON p.id = l.photo_id
LEFT JOIN comments c
    ON p.id = c.photo_id
GROUP BY u.id, u.username
ORDER BY avg_engagement_per_post DESC;

/** 7. Get the list of users who have never liked any post (users and likes
tables) **/ 
SELECT u.id, u.username
FROM users u
LEFT JOIN likes l
    ON u.id = l.user_id
WHERE l.user_id IS NULL;

/** 8. How can you leverage user-generated content (posts, hashtags,
photo tags) to create more personalized and engaging ad
campaigns?**/

WITH tag_frequency AS (SELECT pt.tag_id, COUNT(*) AS tag_usage_count
    FROM photo_tags pt
    GROUP BY pt.tag_id)
SELECT t.tag_name, tf.tag_usage_count
FROM tag_frequency tf
JOIN tags t
    ON tf.tag_id = t.id
ORDER BY tf.tag_usage_count DESC;

/** 9. Are there any correlations between user activity levels and specific
content types (e.g., photos, videos, reels)? How can this information guide content creation and curation strategies? **/ 

SELECT DISTINCT content_type
FROM photos;
SET SQL_SAFE_UPDATES = 0;
UPDATE photos
SET content_type =
    CASE
        WHEN id % 3 = 0 THEN 'Photo'
        WHEN id % 3 = 1 THEN 'Video'
        ELSE 'Reel'
    END
WHERE content_type IS NULL;
SET SQL_SAFE_UPDATES = 1;

SELECT p.content_type, COUNT(DISTINCT p.id) AS total_posts, ROUND(AVG(like_data.total_likes), 2) AS avg_likes,
ROUND(AVG(comment_data.total_comments), 2) AS avg_comments,
ROUND(AVG(like_data.total_likes + comment_data.total_comments), 2) 
AS avg_engagement,
ROUND(AVG(user_post_data.total_creator_posts), 2) AS avg_creator_posts,
ROUND(AVG(comment_data.total_comments), 2) AS avg_creator_comments,
ROUND(AVG(like_data.total_likes), 2) AS avg_creator_likes
FROM photos p
LEFT JOIN (SELECT photo_id, COUNT(*) AS total_likes FROM likes 
GROUP BY photo_id) AS like_data
ON p.id = like_data.photo_id
LEFT JOIN (SELECT photo_id, COUNT(*) AS total_comments
FROM comments
GROUP BY photo_id) AS comment_data
ON p.id = comment_data.photo_id
LEFT JOIN (SELECT user_id,COUNT(*) AS total_creator_posts FROM photos
GROUP BY user_id) AS user_post_data
ON p.user_id = user_post_data.user_id
GROUP BY p.content_type
ORDER BY avg_engagement DESC;

/** 10. Calculate the total number of likes, comments, and photo tags for each user.**/

SELECT u.id, u.username, COUNT(DISTINCT p.id) AS total_posts, 
COUNT(DISTINCT l.photo_id) AS total_likes_given, COUNT(DISTINCT c.id) AS total_comments,
(COUNT(DISTINCT p.id) + COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id)
    ) AS total_activity
FROM users u
LEFT JOIN photos p
ON u.id = p.user_id
LEFT JOIN likes l
ON u.id = l.user_id
LEFT JOIN comments c
ON u.id = c.user_id
GROUP BY u.id, u.username
ORDER BY u.id desc
LIMIT 10;

/** 11. Rank users based on their total engagement (likes, comments, shares) over a month. **/

SELECT u.id, u.username, COUNT(DISTINCT l.user_id) AS total_likes, COUNT(DISTINCT c.id) 
AS total_comments,
(COUNT(DISTINCT l.user_id) + COUNT(DISTINCT c.id)) AS total_engagement,
DENSE_RANK() OVER ( ORDER BY (COUNT(DISTINCT l.user_id) + COUNT(DISTINCT c.id)) DESC) 
AS engagement_rank
FROM users u
JOIN photos p
ON u.id = p.user_id
LEFT JOIN likes l
ON p.id = l.photo_id
LEFT JOIN comments c
ON p.id = c.photo_id
GROUP BY u.id, u.username;

/** 12. Retrieve the hashtags that have been used in posts with the highest average number of likes. Use a CTE to calculate the average likes for each hashtag first. **/

WITH hashtag_engagement
 AS (SELECT t.tag_name, p.id AS photo_id, COUNT(DISTINCT l.user_id) AS total_likes, COUNT(DISTINCT c.id) AS total_comments
FROM tags t
JOIN photo_tags pt
ON t.id = pt.tag_id
JOIN photos p
ON pt.photo_id = p.id
LEFT JOIN likes l
ON p.id = l.photo_id
LEFT JOIN comments c
ON p.id = c.photo_id
GROUP BY t.tag_name, p.id)
SELECT tag_name, ROUND(AVG(total_likes), 2) AS avg_likes, ROUND(AVG(total_comments), 2) AS avg_comments,
    ROUND(AVG(total_likes + total_comments), 2) AS avg_engagement
FROM hashtag_engagement
GROUP BY tag_name
ORDER BY avg_engagement DESC;

/** 13. Retrieve the users who have started following someone after being followed by that person **/ 

SELECT 
    u1.id AS user_id,
    u1.username AS user_name,
    u2.id AS followed_user_id,
    u2.username AS followed_user_name,
    f1.created_at AS followed_at,
    f2.created_at AS followed_back_at
FROM follows f1
JOIN follows f2 
    ON f1.follower_id = f2.followee_id
   AND f1.followee_id = f2.follower_id
JOIN users u1 
    ON f1.follower_id = u1.id
JOIN users u2 
    ON f1.followee_id = u2.id
WHERE f2.created_at < f1.created_at
ORDER BY user_id;

                        -- SUBJECTIVE-- 
/** 1. Based on user engagement and activity levels, which users would you consider the most loyal or valuable? How would you reward or
 incentivize these users? **/ 

SELECT u.id, u.username,
    COUNT(DISTINCT p.id) AS total_posts,
    COUNT(DISTINCT l.user_id) AS total_likes_received,
    COUNT(DISTINCT c.id) AS total_comments_received,
    (
        COUNT(DISTINCT l.user_id) +
        COUNT(DISTINCT c.id)
    ) AS total_engagement,
    CASE
        WHEN COUNT(DISTINCT p.id) >= 5
             AND (COUNT(DISTINCT l.user_id) + COUNT(DISTINCT c.id)) >= 150
        THEN 'Highly Valuable User'
        WHEN COUNT(DISTINCT p.id) BETWEEN 2 AND 4
             AND (COUNT(DISTINCT l.user_id) + COUNT(DISTINCT c.id)) >= 50
        THEN 'Moderately Valuable User'
        WHEN COUNT(DISTINCT p.id) >= 1
        THEN 'Low Activity User'
        ELSE 'Inactive User'
    END AS user_category
FROM users u
LEFT JOIN photos p
    ON u.id = p.user_id
LEFT JOIN likes l
    ON p.id = l.photo_id
LEFT JOIN comments c
    ON p.id = c.photo_id
GROUP BY u.id, u.username
ORDER BY total_engagement DESC;

/** 2. **/
WITH user_engagement AS (SELECT u.id, u.username, COALESCE(COUNT(DISTINCT p.id), 0) AS total_posts,
                                              COALESCE(COUNT(DISTINCT l.photo_id), 0) AS total_likes,
											  COALESCE(COUNT(DISTINCT c.id), 0) AS total_comments
FROM users u
LEFT JOIN photos p
        ON u.id = p.user_id
LEFT JOIN likes l
	   ON u.id = l.user_id
LEFT JOIN comments c
        ON u.id = c.user_id
GROUP BY u.id, u.username)
SELECT id, username, total_posts, total_likes, total_comments,
    (total_posts + total_likes + total_comments) AS total_activity,
    CASE
        WHEN (total_posts + total_likes + total_comments) = 0
        THEN 'Inactive User'
        WHEN (total_posts + total_likes + total_comments) BETWEEN 1 AND 50
        THEN 'Low Activity User'
        ELSE 'Active User'
    END AS activity_status
FROM user_engagement
WHERE (total_posts + total_likes + total_comments) <= 50
ORDER BY total_activity ASC;

/** 3. **/ 

WITH hashtag_engagement AS (
    SELECT t.tag_name, COUNT(DISTINCT l.user_id) AS total_likes, COUNT(DISTINCT c.id) AS total_comments,
        (
            COUNT(DISTINCT l.user_id) +
            COUNT(DISTINCT c.id)
        ) AS total_engagement FROM tags t
JOIN photo_tags pt
ON t.id = pt.tag_id
JOIN photos p
ON pt.photo_id = p.id
LEFT JOIN likes l
ON p.id = l.photo_id
LEFT JOIN comments c
ON p.id = c.photo_id
GROUP BY t.tag_name )
SELECT tag_name, total_likes, total_comments, total_engagement
FROM hashtag_engagement
ORDER BY total_engagement DESC;

/** Q.4. **/

WITH engagement_time_analysis AS (
    SELECT 
        HOUR(l.created_at) AS engagement_hour,
        COUNT(DISTINCT l.user_id) AS total_likes,
        COUNT(DISTINCT c.id) AS total_comments,
        (
            COUNT(DISTINCT l.user_id) + COUNT(DISTINCT c.id)
        ) AS total_engagement
    FROM likes l
    LEFT JOIN comments c
        ON l.photo_id = c.photo_id
    GROUP BY HOUR(l.created_at)
)
SELECT 
    engagement_hour,
    total_likes,
    total_comments,
    total_engagement,
    CASE
        WHEN total_engagement >= 300
        THEN 'High Engagement Period'

        WHEN total_engagement BETWEEN 150 AND 299
        THEN 'Medium Engagement Period'

        ELSE 'Low Engagement Period'
    END AS engagement_level

FROM engagement_time_analysis

ORDER BY total_engagement DESC;

/** Q.5. **/ 

WITH follower_data AS (
    SELECT 
        followee_id AS user_id,
        COUNT(DISTINCT follower_id) AS follower_count
    FROM follows
    GROUP BY followee_id
),
like_data AS (
    SELECT 
        p.user_id,
        COUNT(DISTINCT l.user_id) AS total_likes_received
    FROM photos p
    LEFT JOIN likes l
        ON p.id = l.photo_id
    GROUP BY p.user_id
),
comment_data AS (
    SELECT 
        p.user_id,
        COUNT(DISTINCT c.id) AS total_comments_received
    FROM photos p
    LEFT JOIN comments c
        ON p.id = c.photo_id
    GROUP BY p.user_id
)
SELECT 
    u.id,
    u.username,
    COALESCE(f.follower_count, 0) AS follower_count,
    COALESCE(l.total_likes_received, 0) AS total_likes_received,
    COALESCE(c.total_comments_received, 0) AS total_comments_received,
    (
        COALESCE(l.total_likes_received, 0) +
        COALESCE(c.total_comments_received, 0)
    ) AS total_engagement,
    ROUND(
        (
            COALESCE(l.total_likes_received, 0) +
            COALESCE(c.total_comments_received, 0)
        ) / NULLIF(f.follower_count, 0),
        2
    ) AS engagement_rate,
    CASE
        WHEN COALESCE(f.follower_count, 0) >= 10
             AND (
                 COALESCE(l.total_likes_received, 0) +
                 COALESCE(c.total_comments_received, 0)
             ) >= 300
        THEN 'Ideal Influencer'
        WHEN COALESCE(f.follower_count, 0) >= 5
             AND (
                 COALESCE(l.total_likes_received, 0) +
                 COALESCE(c.total_comments_received, 0)
             ) >= 150
        THEN 'Potential Influencer'
        ELSE 'Low Influence'
    END AS influencer_category
FROM users u
LEFT JOIN follower_data f
    ON u.id = f.user_id
LEFT JOIN like_data l
    ON u.id = l.user_id
LEFT JOIN comment_data c
    ON u.id = c.user_id
ORDER BY engagement_rate DESC;

/** Q.6.**/
WITH user_activity AS (

    SELECT 
        u.id,
        u.username,

        COALESCE(COUNT(DISTINCT p.id), 0) AS total_posts,

        COALESCE(COUNT(DISTINCT l.photo_id), 0) AS total_likes,

        COALESCE(COUNT(DISTINCT c.id), 0) AS total_comments,

        (
            COALESCE(COUNT(DISTINCT p.id), 0) +
            COALESCE(COUNT(DISTINCT l.photo_id), 0) +
            COALESCE(COUNT(DISTINCT c.id), 0)
        ) AS total_activity

    FROM users u

    LEFT JOIN photos p
        ON u.id = p.user_id

    LEFT JOIN likes l
        ON u.id = l.user_id

    LEFT JOIN comments c
        ON u.id = c.user_id

    GROUP BY u.id, u.username
)

SELECT 
    id,
    username,

    total_posts,
    total_likes,
    total_comments,
    total_activity,

    CASE

        WHEN total_posts >= 5
             AND total_comments >= 100
        THEN 'Highly Engaged Creator'

        WHEN total_likes >= 100
             AND total_posts < 5
        THEN 'Active Consumer'

        WHEN total_activity BETWEEN 1 AND 50
        THEN 'Low Activity User'

        WHEN total_activity = 0
        THEN 'Inactive User'

        ELSE 'Moderately Active User'

    END AS user_segment

FROM user_activity

ORDER BY total_activity DESC;

/**  Q.7. **/ 

CREATE TABLE ad_campaigns (

    campaign_id INT PRIMARY KEY,
    campaign_name VARCHAR(100),

    impressions INT,
    clicks INT,
    conversions INT
);

INSERT INTO ad_campaigns
VALUES

(1, 'Summer Fashion Campaign', 10000, 1200, 180),

(2, 'Food Promotion Campaign', 8500, 950, 110),

(3, 'Travel Influencer Campaign', 15000, 1800, 320),

(4, 'Beauty Product Campaign', 9000, 700, 65),

(5, 'Fitness Brand Campaign', 11000, 1000, 140);

WITH campaign_performance AS (

    SELECT 
        campaign_id,
        campaign_name,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(conversions) AS total_conversions
    FROM ad_campaigns
    GROUP BY campaign_id, campaign_name
)
SELECT 
    campaign_id, campaign_name, total_impressions, total_clicks, total_conversions,
    ROUND(
        (total_clicks * 100.0) / NULLIF(total_impressions, 0),
        2
    ) AS click_through_rate,
    ROUND(
        (total_conversions * 100.0) / NULLIF(total_clicks, 0),
        2
    ) AS conversion_rate,

    CASE
        WHEN (
            (total_conversions * 100.0) / NULLIF(total_clicks, 0)
        ) >= 10
        THEN 'High Performing Campaign'

        WHEN (
            (total_conversions * 100.0) / NULLIF(total_clicks, 0)
        ) BETWEEN 5 AND 9.99
        THEN 'Moderate Performing Campaign'

        ELSE 'Low Performing Campaign'
    END AS campaign_performance_status

FROM campaign_performance

ORDER BY conversion_rate DESC;

/** Q.8. **/

SELECT 
    u.id,
    u.username,
    COUNT(DISTINCT f.follower_id) AS follower_count,
    COUNT(DISTINCT p.id) AS total_posts,

    CASE
        WHEN COUNT(DISTINCT f.follower_id) >= 70
             AND COUNT(DISTINCT p.id) >= 5
        THEN 'Potential Brand Ambassador'

        WHEN COUNT(DISTINCT f.follower_id) >= 70
             AND COUNT(DISTINCT p.id) BETWEEN 1 AND 4
        THEN 'Potential Advocate'

        ELSE 'Regular User'
    END AS ambassador_category
FROM users u
LEFT JOIN follows f
    ON u.id = f.followee_id
LEFT JOIN photos p
    ON u.id = p.user_id
GROUP BY u.id, u.username ORDER BY follower_count DESC, total_posts DESC;

/** Q.10. **/

CREATE TABLE User_Interactions (interaction_id INT PRIMARY KEY, user_id INT, photo_id INT, Engagement_Type VARCHAR(20));

INSERT INTO User_Interactions
VALUES
(1, 12, 101, 'Like'),
(2, 15, 104, 'Comment'),
(3, 18, 102, 'Like'),
(4, 20, 105, 'Share'),
(5, 25, 106, 'Like');

UPDATE User_Interactions

SET Engagement_Type = 'Heart'

WHERE Engagement_Type = 'Like'
AND interaction_id > 0;

SELECT * FROM User_Interactions;
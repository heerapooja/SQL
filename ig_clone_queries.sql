-- =====================================================================
-- SQL: Social Media (Instagram Clone) Project
-- Author: Pooja Heera
-- Database: ig_clone
-- =====================================================================

USE ig_clone;
-- =====================================================================
-- OBJECTIVE QUESTIONS
-- =====================================================================

-- Question 1: Are there any tables with duplicate or missing/null values?
-- If so, how would you handle them?
-- (Checks the columns that matter most: usernames, image URLs,
--  comment text, duplicate like pairs, duplicate tag names)
SELECT 'users_null_username' AS check_name, COUNT(*) AS issue_count
FROM users WHERE username IS NULL
UNION ALL
SELECT 'users_duplicate_username', COUNT(*)
FROM (SELECT username FROM users GROUP BY username HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'photos_null_image_url', COUNT(*)
FROM photos WHERE image_url IS NULL
UNION ALL
SELECT 'comments_null_comment_text', COUNT(*)
FROM comments WHERE comment_text IS NULL
UNION ALL
SELECT 'likes_duplicate_user_photo_pair', COUNT(*)
FROM (SELECT user_id, photo_id FROM likes GROUP BY user_id, photo_id HAVING COUNT(*) > 1) y
UNION ALL
SELECT 'tags_duplicate_tag_name', COUNT(*)
FROM (SELECT tag_name FROM tags GROUP BY tag_name HAVING COUNT(*) > 1) z;
-- Result on this dataset: every check returns 0 -> no NULLs and no
-- duplicates were found. If any of these had returned a positive
-- number, the fix would be: DELETE duplicate rows keeping the lowest
-- id (or use ROW_NUMBER() OVER(PARTITION BY ...) to find and remove
-- extras), and UPDATE/DELETE rows with NULLs in required columns,
-- or backfill them with a sensible default.


-- Question 2: What is the distribution of user activity levels (number of
-- posts, likes given, comments) across the user base?
SELECT u.id, u.username,
       COUNT(DISTINCT p.id)              AS total_posts,
       COUNT(DISTINCT l.photo_id)        AS total_likes_given,
       COUNT(DISTINCT c.id)              AS total_comments_made
FROM users u
LEFT JOIN photos   p ON p.user_id = u.id
LEFT JOIN likes    l ON l.user_id = u.id
LEFT JOIN comments c ON c.user_id = u.id
GROUP BY u.id, u.username
ORDER BY total_posts DESC;


-- Question 3: Calculate the average number of tags per post
-- (photo_tags and photos tables).
SELECT ROUND(COUNT(pt.tag_id) / COUNT(DISTINCT p.id), 2) AS avg_tags_per_post
FROM photos p
LEFT JOIN photo_tags pt ON pt.photo_id = p.id;


-- Question 4: Identify the top users with the highest engagement rates
-- (likes, comments) on their posts and rank them.
SELECT u.id, u.username,
       COUNT(DISTINCT l.user_id, l.photo_id) AS total_likes_received,
       COUNT(DISTINCT c.id)                  AS total_comments_received,
       (COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id)) AS total_engagement,
       RANK() OVER (
           ORDER BY (COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id)) DESC
       ) AS engagement_rank
FROM users u
JOIN photos p       ON p.user_id = u.id
LEFT JOIN likes l    ON l.photo_id = p.id
LEFT JOIN comments c ON c.photo_id = p.id
GROUP BY u.id, u.username
ORDER BY total_engagement DESC;


-- Question 5: Which users have the highest number of followers and followings?
SELECT u.id, u.username,
       (SELECT COUNT(*) FROM follows f WHERE f.followee_id = u.id) AS followers_count,
       (SELECT COUNT(*) FROM follows f WHERE f.follower_id = u.id) AS following_count
FROM users u
ORDER BY followers_count DESC, following_count DESC;


-- Question 6: Calculate the average engagement rate (likes, comments)
-- per post for each user.
SELECT u.id, u.username,
       COUNT(DISTINCT p.id)                   AS total_posts,
       COUNT(DISTINCT l.user_id, l.photo_id)   AS total_likes,
       COUNT(DISTINCT c.id)                    AS total_comments,
       ROUND(
         (COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id))/ COUNT(DISTINCT p.id), 2
       ) AS avg_engagement_per_post
FROM users u
JOIN photos p       ON p.user_id = u.id
LEFT JOIN likes l    ON l.photo_id = p.id
LEFT JOIN comments c ON c.photo_id = p.id
GROUP BY u.id, u.username
ORDER BY avg_engagement_per_post DESC;


-- Question 7: Get the list of users who have never liked any post
-- (users and likes tables).
SELECT u.id, u.username
FROM users u
LEFT JOIN likes l ON l.user_id = u.id
WHERE l.user_id IS NULL;


-- Question 8: How can you leverage user-generated content (posts, hashtags,
-- photo tags) to create more personalized and engaging ad campaigns?
-- Supporting query: find the most-used hashtags, which are strong
-- candidates for hashtag-based/targeted ad campaigns.
SELECT t.tag_name, COUNT(pt.photo_id) AS times_used
FROM tags t
JOIN photo_tags pt ON pt.tag_id = t.id
GROUP BY t.tag_name
ORDER BY times_used DESC;


-- Question 9: Are there any correlations between user activity levels and
-- specific content types (photos, videos, reels)? How can this
-- inform content creation and curation strategies?
-- NOTE: This schema only stores a single "photos" table with no
-- content-type/media-type column (no video or reel flag exists), so
-- this exact correlation cannot be computed from the given data.
-- The query below shows the closest available proxy: how activity
-- (posts) relates to a user's total engagement, which is a stand-in
-- until a media_type column is added.
SELECT u.id, u.username,
       COUNT(DISTINCT p.id) AS total_posts,
       (COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id)) AS total_engagement
FROM users u
JOIN photos p       ON p.user_id = u.id
LEFT JOIN likes l    ON l.photo_id = p.id
LEFT JOIN comments c ON c.photo_id = p.id
GROUP BY u.id, u.username
ORDER BY total_posts DESC;


-- Question 10: Calculate the total number of likes, comments, and photo tags
-- for each user.
SELECT u.id, u.username,
       COUNT(DISTINCT l.user_id, l.photo_id)   AS total_likes_received,
       COUNT(DISTINCT c.id)                    AS total_comments_received,
       COUNT(DISTINCT pt.photo_id, pt.tag_id)  AS total_photo_tags
FROM users u
LEFT JOIN photos     p  ON p.user_id = u.id
LEFT JOIN likes      l  ON l.photo_id = p.id
LEFT JOIN comments   c  ON c.photo_id = p.id
LEFT JOIN photo_tags pt ON pt.photo_id = p.id
GROUP BY u.id, u.username
ORDER BY total_likes_received DESC;


-- Question 11: Rank users based on their total engagement (likes, comments,
-- shares) over a month.
-- NOTE: this schema has no "shares" table/column, so engagement here
-- = likes + comments. Also, every row in this seed data was inserted
-- with created_at DEFAULT NOW() and no explicit historical date was
-- passed in the INSERT statements, so every timestamp in the table
-- is identical (the moment the .sql file was loaded). That means a
-- "last 30 days" filter cannot separate rows in this specific
-- dataset - the query below is written the way it would be used on
-- a real production table where created_at values are spread out
-- over time.
SELECT u.id, u.username,
       COUNT(DISTINCT l.user_id, l.photo_id) AS likes_last_30_days,
       COUNT(DISTINCT c.id)                  AS comments_last_30_days,
       (COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id)) AS total_engagement,
       RANK() OVER (
           ORDER BY (COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id)) DESC
       ) AS engagement_rank
FROM users u
JOIN photos p ON p.user_id = u.id
LEFT JOIN likes l ON l.photo_id = p.id
    AND l.created_at >= (SELECT MAX(created_at) FROM likes) - INTERVAL 30 DAY
LEFT JOIN comments c ON c.photo_id = p.id
    AND c.created_at >= (SELECT MAX(created_at) FROM comments) - INTERVAL 30 DAY
GROUP BY u.id, u.username
ORDER BY total_engagement DESC;


-- Question 12: Retrieve the hashtags that have been used in posts with the
-- highest average number of likes. Use a CTE to calculate the
-- average likes for each hashtag first.
WITH tag_likes AS (
    SELECT t.id AS tag_id, t.tag_name, p.id AS photo_id,
           COUNT(l.user_id) AS like_count
    FROM tags t
    JOIN photo_tags pt ON pt.tag_id = t.id
    JOIN photos p       ON p.id = pt.photo_id
    LEFT JOIN likes l   ON l.photo_id = p.id
    GROUP BY t.id, t.tag_name, p.id
),
avg_tag_likes AS (
    SELECT tag_id, tag_name, ROUND(AVG(like_count), 2) AS avg_likes
    FROM tag_likes
    GROUP BY tag_id, tag_name
)
SELECT tag_name, avg_likes
FROM avg_tag_likes
ORDER BY avg_likes DESC;


-- Question 13: Retrieve the users who have started following someone after
-- being followed by that person.
-- NOTE: same timestamp limitation as Q11 - every row in the follows
-- table was also inserted with an identical created_at value in this
-- seed data, so "who followed back later" cannot be determined from
-- timestamps here. The query below returns every mutual/reciprocal
-- follow pair (A follows B AND B follows A); on a real table with
-- proper historical timestamps, adding "AND f1.created_at >
-- f2.created_at" (as commented below) would correctly filter this
-- down to only the users who followed back *after* being followed.
SELECT f1.follower_id AS user_id,
       f1.followee_id AS followed_user_id,
       f2.created_at  AS was_followed_at,
       f1.created_at  AS followed_back_at
FROM follows f1
JOIN follows f2
    ON f1.follower_id = f2.followee_id
   AND f1.followee_id = f2.follower_id
WHERE f1.follower_id < f1.followee_id
-- AND f1.created_at > f2.created_at   -- uncomment on a table with real historical timestamps
;

-- =====================================================================
-- SUBJECTIVE QUESTIONS
-- =====================================================================

-- Question 1 Based on user engagement and activity levels, 
-- which users would you consider the most loyal or valuable? 
-- How would you reward or incentivize these users?

SELECT u.id, u.username,
  COUNT(DISTINCT p.id) AS total_posts,
  (COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id)) AS total_engagement,
  ROUND(
   (COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id)) / COUNT(DISTINCT p.id),2
  ) AS avg_engagement_per_post
FROM users u
JOIN photos p ON p.user_id = u.id
LEFT JOIN likes l ON l.photo_id = p.id
LEFT JOIN comments c ON c.photo_id = p.id
GROUP BY u.id, u.username
ORDER BY total_engagement DESC
LIMIT 10;

-- Question 2
-- For inactive users, what strategies would you recommend to re-engage them and encourage them to start posting or engaging again?

SELECT
  SUM(CASE WHEN l.user_id IS NULL THEN 1 ELSE 0 END) AS never_liked,
  SUM(CASE WHEN l.user_id IS NOT NULL THEN 1 ELSE 0 END) AS has_liked
FROM (
  SELECT DISTINCT u.id, l2.user_id
  FROM users u
  LEFT JOIN likes l2 ON l2.user_id = u.id
) l;

-- Question 3
-- Which hashtags or content topics have the highest engagement rates? How can this information guide content strategy and ad campaigns?

WITH tag_likes AS (
    SELECT t.id AS tag_id, t.tag_name, p.id AS photo_id,
           COUNT(l.user_id) AS like_count
    FROM tags t
    JOIN photo_tags pt ON pt.tag_id = t.id
    JOIN photos p ON p.id = pt.photo_id
    LEFT JOIN likes l ON l.photo_id = p.id
    GROUP BY t.id, t.tag_name, p.id
),
avg_tag_likes AS (
    SELECT tag_id, tag_name, ROUND(AVG(like_count), 2) AS avg_likes
    FROM tag_likes
    GROUP BY tag_id, tag_name
)
SELECT tag_name, avg_likes
FROM avg_tag_likes
ORDER BY avg_likes DESC
LIMIT 8;

-- Question 5
-- Based on follower counts and engagement rates, which users would be ideal candidates for influencer marketing campaigns? 
-- How would you approach and collaborate with these influencers?

SELECT u.id, u.username,
  (SELECT COUNT(*) FROM follows f WHERE f.followee_id = u.id) AS followers_count,
  COALESCE((
    SELECT (COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id))
    FROM photos p
    LEFT JOIN likes l ON l.photo_id = p.id
    LEFT JOIN comments c ON c.photo_id = p.id
    WHERE p.user_id = u.id
  ), 0) AS total_engagement
FROM users u
ORDER BY followers_count DESC, total_engagement DESC;

-- Question 6
-- Based on user behavior and engagement data, how would you segment the user base for 
-- targeted marketing campaigns or personalized recommendations?

SELECT
  CASE
    WHEN following_count = 0 AND posts = 0 THEN 'Ghost Accounts'
    WHEN following_count = 0 AND posts > 0 THEN 'Active Creators'
    ELSE 'Community Accounts'
  END AS segment,
  COUNT(*) AS num_users
FROM (
  SELECT u.id,
    (SELECT COUNT(*) FROM follows f WHERE f.follower_id = u.id) AS following_count,
    (SELECT COUNT(*) FROM photos p WHERE p.user_id = u.id) AS posts
  FROM users u
) x
GROUP BY segment
ORDER BY num_users DESC;

-- Question 8
-- How can you use user activity data to identify potential brand ambassadors or 
-- advocates who could help promote Instagram's initiatives or events?

WITH eng AS (
  SELECT u.id, u.username,
    (COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id)) AS total_engagement,
    RANK() OVER (ORDER BY (COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id)) DESC) AS eng_rank
  FROM users u JOIN photos p ON p.user_id = u.id
  LEFT JOIN likes l ON l.photo_id = p.id
  LEFT JOIN comments c ON c.photo_id = p.id
  GROUP BY u.id, u.username
),
avgpost AS (
  SELECT u.id,
    ROUND((COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id)) / COUNT(DISTINCT p.id), 2) AS avg_eng_per_post,
    RANK() OVER (
      ORDER BY (COUNT(DISTINCT l.user_id, l.photo_id) + COUNT(DISTINCT c.id)) / COUNT(DISTINCT p.id) DESC
    ) AS avgpost_rank
  FROM users u JOIN photos p ON p.user_id = u.id
  LEFT JOIN likes l ON l.photo_id = p.id
  LEFT JOIN comments c ON c.photo_id = p.id
  GROUP BY u.id
)
SELECT eng.username, eng.total_engagement, avgpost.avg_eng_per_post,
       eng.eng_rank, avgpost.avgpost_rank
FROM eng
JOIN avgpost ON avgpost.id = eng.id
WHERE eng.eng_rank <= 15 AND avgpost.avgpost_rank <= 15
ORDER BY eng.eng_rank;



-- Question 10: Assuming there's a "User_Interactions" table tracking user
-- engagements, how would you update the "Engagement_Type" column to
-- change all instances of "Like" to "Heart"?

-- NOTE: This table does not exist in the ig_clone schema - this is a
-- hypothetical table described in the question, so this query is
-- illustrative only and is not run against the ig_clone database.
UPDATE User_Interactions
SET Engagement_Type = 'Heart'
WHERE Engagement_Type = 'Like';



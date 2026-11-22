// Запит 1. Фільми жанру «Thriller» із середнім рейтингом вище 4.0
MATCH (:Genre {name: 'Thriller'})<-[:HAS_GENRE]-(m:Movie)<-[r:RATED]-(:User)
WITH m, avg(r.rating) AS avgRating, count(r) AS numRatings
WHERE avgRating > 4.0 AND numRatings >= 50
RETURN m.title AS title,
       round(avgRating, 3) AS avgRating,
       numRatings
ORDER BY avgRating DESC, numRatings DESC;

// Запит 2. Користувачі, які поставили оцінку 5 більш ніж 50 фільмам
MATCH (u:User)-[r:RATED]->(:Movie)
WHERE r.rating = 5
WITH u, count(r) AS fiveStarCount
WHERE fiveStarCount > 50
RETURN u.userId AS userId, u.gender AS gender, u.age AS ageGroup,
       fiveStarCount
ORDER BY fiveStarCount DESC, userId;

// Запит 3. Фільми, які обидва користувачі (userId=1 і userId=2) оцінили високо (рейтинг ≥ 4)
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User {userId: 2})
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN m.title AS title,
       r1.rating AS user1Rating,
       r2.rating AS user2Rating
ORDER BY user1Rating + user2Rating DESC, title;

// Запит 4. Жанри, чиї фільми стабільно отримують високі оцінки
MATCH (g:Genre)<-[:HAS_GENRE]-(:Movie)<-[r:RATED]-(:User)
WITH g,
     avg(r.rating)   AS avgRating,
     count(r)        AS numRatings,
     stDev(r.rating) AS stdDev,
     sum(CASE WHEN r.rating >= 4 THEN 1 ELSE 0 END) AS highCount
WHERE numRatings >= 1000
RETURN g.name AS genre,
       round(avgRating, 3) AS avgRating,
       numRatings,
       round(stdDev, 3) AS stdDev,
       round(100.0 * highCount / numRatings, 1) AS pctHigh
ORDER BY avgRating DESC;

// Запит 5. Рекомендація «користувачі зі схожими смаками також дивилися»
MATCH (target:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(other:User)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND other <> target
WITH target, other, count(m) AS sharedLikes
ORDER BY sharedLikes DESC, other.userId
LIMIT 25
MATCH (other)-[r3:RATED]->(rec:Movie)
WHERE r3.rating >= 4 AND NOT (target)-[:RATED]->(rec)
RETURN rec.title AS recommendation,
       count(DISTINCT other) AS recommenders,
       round(avg(r3.rating), 2) AS avgNeighbourRating
ORDER BY recommenders DESC, avgNeighbourRating DESC
LIMIT 10;

// Запит 6. Найкоротший ланцюжок зв'язку між двома користувачами через спільні фільми
MATCH (a:User {userId: 1}), (b:User {userId: 2})
MATCH p = shortestPath((a)-[:RATED*..10]-(b))
RETURN length(p) AS hops,
       [n IN nodes(p) | coalesce(n.title, 'User ' + toString(n.userId))] AS chain;

MATCH (a:User {userId: 4}), (b:User {userId: 47})
MATCH p = shortestPath((a)-[:RATED*..10]-(b))
RETURN length(p) AS hops,
       [n IN nodes(p) | coalesce(n.title, 'User ' + toString(n.userId))] AS chain;

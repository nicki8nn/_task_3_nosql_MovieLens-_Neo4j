// Крок 1. Вузли з аномально великою кількістю ребер (топ-20)
MATCH (n)
WITH n, COUNT { (n)--() } AS degree
RETURN labels(n)[0] AS label,
       coalesce(n.title, n.name, 'User ' + toString(n.userId)) AS node,
       degree
ORDER BY degree DESC
LIMIT 20;

// Розподіл ступенів по лейблах
MATCH (n)
WITH labels(n)[0] AS label, COUNT { (n)--() } AS degree
RETURN label,
       count(*) AS nodes,
       round(avg(degree), 1) AS avgDegree,
       percentileDisc(degree, 0.5)  AS medianDegree,
       percentileDisc(degree, 0.99) AS p99Degree,
       max(degree) AS maxDegree
ORDER BY maxDegree DESC;

// Кількість супервузлів: ступінь > 10 x медіана лейбла
MATCH (n)
WHERE n:Movie OR n:User
WITH labels(n)[0] AS label, n, COUNT { (n)--() } AS degree
WITH label, collect({n: n, degree: degree}) AS rows,
     percentileDisc(degree, 0.5) AS median
UNWIND rows AS row
WITH label, median, row
WHERE row.degree > 10 * median
RETURN label, median, count(*) AS supernodes, max(row.degree) AS maxDegree;

// Жанри: кількість фільмів і оцінок за 2 хопи
MATCH (g:Genre)
RETURN g.name AS genre,
       COUNT { (g)<-[:HAS_GENRE]-(:Movie) } AS movies,
       COUNT { (g)<-[:HAS_GENRE]-(:Movie)<-[:RATED]-(:User) } AS ratingsBehind
ORDER BY ratingsBehind DESC;

// PROFILE: супервузол vs звичайний фільм
PROFILE
MATCH (m:Movie {title: 'American Beauty (1999)'})<-[r:RATED]-(:User)
RETURN m.title, count(r) AS ratings, avg(r.rating) AS avgRating;

PROFILE
MATCH (m:Movie {title: 'Basquiat (1996)'})<-[r:RATED]-(:User)
RETURN m.title, count(r) AS ratings, avg(r.rating) AS avgRating;

PROFILE
MATCH (m:Movie {title: 'American Beauty (1999)'})<-[:RATED]-(u:User)-[:RATED]->(other:Movie)
RETURN count(*) AS paths;

// Стратегія 3: денормалізація
CALL apoc.periodic.iterate(
  "MATCH (m:Movie) RETURN m",
  "OPTIONAL MATCH (m)<-[r:RATED]-()
   WITH m, count(r) AS cnt, avg(r.rating) AS avgR
   SET m.ratingCount = cnt, m.avgRating = avgR",
  {batchSize: 500, parallel: false}
);

CALL apoc.periodic.iterate(
  "MATCH (u:User) RETURN u",
  "SET u.ratingCount = COUNT { (u)-[:RATED]->() }",
  {batchSize: 1000, parallel: false}
);

CREATE INDEX movie_rating_count IF NOT EXISTS FOR (m:Movie) ON (m.ratingCount);

PROFILE
MATCH (:Genre {name: 'Thriller'})<-[:HAS_GENRE]-(m:Movie)
WHERE m.avgRating > 4.0 AND m.ratingCount >= 50
RETURN m.title, round(m.avgRating, 3) AS avgRating, m.ratingCount
ORDER BY avgRating DESC;

// Стратегія 4: фільтр до входу в супервузол
PROFILE
MATCH (target:User {userId: 1})-[r1:RATED]->(m:Movie)
WHERE r1.rating >= 4 AND m.ratingCount <= 1000
MATCH (m)<-[r2:RATED]-(other:User)
WHERE r2.rating >= 4 AND other <> target
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

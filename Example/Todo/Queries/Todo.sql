selectTodos:
SELECT * FROM todo
ORDER BY created;

insertTodo:
INSERT INTO todo (name) VALUES (?) RETURNING id;

toggleTodo:
UPDATE todo
SET completed = CASE WHEN completed IS NULL THEN unixepoch() ELSE NULL END
WHERE id = ?;

updateTodo:
UPDATE todo SET name = ?
WHERE id = ?;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

DROP TABLE IF EXISTS comments CASCADE;
DROP TABLE IF EXISTS tasks CASCADE;
DROP TABLE IF EXISTS project_members CASCADE;
DROP TABLE IF EXISTS projects CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS users CASCADE;

CREATE TABLE users (
                       user_id        BIGSERIAL PRIMARY KEY,
                       email          VARCHAR(255) NOT NULL UNIQUE,
                       password_hash  TEXT NOT NULL,
                       first_name     VARCHAR(100) NOT NULL,
                       last_name      VARCHAR(100) NOT NULL,
                       role           VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'user'))
);

CREATE TABLE orders (
                        order_id       BIGSERIAL PRIMARY KEY,
                        client_name    VARCHAR(255) NOT NULL,
                        title          VARCHAR(255) NOT NULL,
                        description    TEXT,
                        budget         NUMERIC(12, 2),
                        status         VARCHAR(30) NOT NULL CHECK (status IN ('new', 'in_progress', 'completed', 'cancelled')),
                        created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE projects (
                          project_id     BIGSERIAL PRIMARY KEY,
                          order_id       BIGINT NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT,
                          title          VARCHAR(255) NOT NULL,
                          description    TEXT,
                          status         VARCHAR(30) NOT NULL CHECK (status IN ('planned', 'active', 'done', 'archived')),
                          created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                          created_by     BIGINT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT
);

CREATE TABLE project_members (
                                 project_member_id BIGSERIAL PRIMARY KEY,
                                 project_id        BIGINT NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
                                 user_id           BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
                                 role_in_project   VARCHAR(50) NOT NULL CHECK (role_in_project IN ('manager', 'developer', 'designer', 'tester', 'analyst')),
                                 joined_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                 CONSTRAINT uq_project_member UNIQUE (project_id, user_id)
);

CREATE TABLE tasks (
                       task_id           BIGSERIAL PRIMARY KEY,
                       project_id        BIGINT NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
                       assignee_user_id  BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
                       title             VARCHAR(255) NOT NULL,
                       description       TEXT,
                       status            VARCHAR(30) NOT NULL CHECK (status IN ('todo', 'in_progress', 'review', 'done')),
                       priority          VARCHAR(20) NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
                       due_date          DATE,
                       created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,


                       search_vector     tsvector GENERATED ALWAYS AS (
                           setweight(to_tsvector('russian', coalesce(title, '')), 'A') ||
                           setweight(to_tsvector('russian', coalesce(description, '')), 'B')
                           ) STORED
);

CREATE TABLE comments (
                          comment_id        BIGSERIAL PRIMARY KEY,
                          task_id           BIGINT NOT NULL REFERENCES tasks(task_id) ON DELETE CASCADE,
                          author_user_id    BIGINT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
                          content           TEXT NOT NULL,
                          created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Индексы для внешних ключей
CREATE INDEX idx_projects_order_id ON projects(order_id);
CREATE INDEX idx_projects_created_by ON projects(created_by);

CREATE INDEX idx_project_members_project_id ON project_members(project_id);
CREATE INDEX idx_project_members_user_id ON project_members(user_id);

CREATE INDEX idx_tasks_project_id ON tasks(project_id);
CREATE INDEX idx_tasks_assignee_user_id ON tasks(assignee_user_id);

CREATE INDEX idx_comments_task_id ON comments(task_id);
CREATE INDEX idx_comments_author_user_id ON comments(author_user_id);

-- Индексы для часто используемых фильтров / сортировок
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_projects_status ON projects(status);

CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_priority ON tasks(priority);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);
CREATE INDEX idx_tasks_created_at ON tasks(created_at);

-- Полнотекстовый индекс
CREATE INDEX idx_tasks_search_vector ON tasks USING GIN (search_vector);

-- Триграммные индексы по двум текстовым атрибутам
CREATE INDEX idx_tasks_title_trgm
    ON tasks USING GIN (title gin_trgm_ops);

CREATE INDEX idx_tasks_description_trgm
    ON tasks USING GIN (description gin_trgm_ops);

INSERT INTO users (email, password_hash, first_name, last_name, role) VALUES
                                                                          ('admin@taskflow.ru', 'hash_admin', 'Илья', 'Альманов', 'admin'),
                                                                          ('ivanov@taskflow.ru', 'hash_ivanov', 'Иван', 'Иванов', 'user'),
                                                                          ('petrova@taskflow.ru', 'hash_petrova', 'Анна', 'Петрова', 'user'),
                                                                          ('sidorov@taskflow.ru', 'hash_sidorov', 'Максим', 'Сидоров', 'user'),
                                                                          ('smirnova@taskflow.ru', 'hash_smirnova', 'Елена', 'Смирнова', 'user'),
                                                                          ('kozlov@taskflow.ru', 'hash_kozlov', 'Олег', 'Козлов', 'user'),
                                                                          ('orlova@taskflow.ru', 'hash_orlova', 'Мария', 'Орлова', 'user');

INSERT INTO orders (client_name, title, description, budget, status) VALUES
                                                                         ('ООО Альфа', 'Разработка CRM-системы', 'Необходимо разработать CRM для отдела продаж и службы поддержки клиентов', 500000.00, 'in_progress'),
                                                                         ('ИП Вектор', 'Корпоративный сайт', 'Создание корпоративного сайта с каталогом услуг, новостями и формой обратной связи', 120000.00, 'new'),
                                                                         ('ООО ЛогистикПро', 'Аналитический модуль заказов', 'Разработка модуля аналитики для поиска заказов, отчетов и контроля KPI', 300000.00, 'in_progress'),
                                                                         ('ООО СеверСофт', 'Мобильное приложение склада', 'Разработка приложения для учета товаров и быстрых операций на складе', 450000.00, 'completed');

INSERT INTO projects (order_id, title, description, status, created_by) VALUES
                                                                            (1, 'CRM для Альфа', 'Автоматизация клиентов, сделок, звонков и обращений', 'active', 1),
                                                                            (2, 'Сайт Вектор', 'Публичный корпоративный сайт компании с SEO-оптимизацией', 'planned', 1),
                                                                            (3, 'Аналитика ЛогистикПро', 'Отчетность, поиск заказов, фильтрация и аналитические панели', 'active', 1),
                                                                            (4, 'Склад СеверСофт', 'Проект мобильного учета товаров и операций перемещения', 'done', 1);

INSERT INTO project_members (project_id, user_id, role_in_project) VALUES
                                                                       (1, 1, 'manager'),
                                                                       (1, 2, 'developer'),
                                                                       (1, 3, 'designer'),
                                                                       (1, 4, 'tester'),

                                                                       (2, 1, 'manager'),
                                                                       (2, 3, 'designer'),
                                                                       (2, 5, 'developer'),

                                                                       (3, 1, 'manager'),
                                                                       (3, 2, 'developer'),
                                                                       (3, 4, 'analyst'),
                                                                       (3, 6, 'developer'),

                                                                       (4, 1, 'manager'),
                                                                       (4, 5, 'developer'),
                                                                       (4, 7, 'tester');

INSERT INTO tasks (project_id, assignee_user_id, title, description, status, priority, due_date) VALUES
                                                                                                     (1, 2, 'Разработка модуля авторизации', 'Реализовать безопасную авторизацию пользователей по email и паролю с защитой от перебора', 'in_progress', 'high', '2026-04-10'),
                                                                                                     (1, 3, 'Создание интерфейса карточки клиента', 'Спроектировать и сверстать страницу клиента с историей обращений и быстрым поиском контактов', 'todo', 'medium', '2026-04-12'),
                                                                                                     (1, 4, 'Тестирование регистрации пользователей', 'Проверить сценарии регистрации, валидации полей и обработку ошибок', 'todo', 'medium', '2026-04-13'),
                                                                                                     (1, 2, 'Исправление ошибок поиска клиента', 'Исправить некорректный поиск клиента по фамилии, названию компании и номеру телефона', 'todo', 'high', '2026-04-14'),
                                                                                                     (1, 6, 'Оптимизация поиска карточек клиентов', 'Ускорить поиск карточек клиента в CRM и уменьшить время ответа при фильтрации', 'todo', 'high', '2026-04-15'),

                                                                                                     (2, 5, 'Верстка главной страницы сайта', 'Создать адаптивную верстку главной страницы корпоративного сайта', 'todo', 'high', '2026-04-09'),
                                                                                                     (2, 3, 'Дизайн страницы услуг', 'Подготовить макет страницы услуг и секции преимуществ компании', 'in_progress', 'medium', '2026-04-08'),
                                                                                                     (2, 5, 'Реализация формы обратной связи', 'Разработать форму обратной связи и обработку заявок пользователей', 'todo', 'medium', '2026-04-11'),

                                                                                                     (3, 2, 'Поиск заказов по ключевым словам', 'Реализовать полнотекстовый поиск заказов и задач по русскоязычным поисковым запросам', 'in_progress', 'critical', '2026-04-05'),
                                                                                                     (3, 4, 'Анализ производительности запросов', 'Подготовить EXPLAIN ANALYZE для поисковых запросов и оптимизировать индексы', 'todo', 'high', '2026-04-06'),
                                                                                                     (3, 2, 'Фильтрация аналитических отчетов', 'Сделать фильтрацию отчетов по дате, статусу, проекту и исполнителю', 'todo', 'medium', '2026-04-11'),
                                                                                                     (3, 6, 'Поддержка частичного поиска', 'Добавить быстрый поиск по началу слова, по фрагменту текста и по неполному совпадению', 'todo', 'critical', '2026-04-07'),
                                                                                                     (3, 2, 'Поисковая строка аналитики', 'Сделать единую поисковую строку для поиска заказа, клиента и задачи', 'review', 'high', '2026-04-08'),
                                                                                                     (3, 6, 'Релевантная сортировка результатов', 'Отсортировать результаты поиска по релевантности и весу совпадения в заголовке', 'todo', 'high', '2026-04-12'),
                                                                                                     (3, 4, 'Проверка морфологии русского языка', 'Проверить, что поиск находит слова заказ, заказы, заказов и заказами', 'todo', 'high', '2026-04-09'),
                                                                                                     (3, 2, 'Индексирование поисковых полей', 'Создать GIN-индексы для полнотекстового поиска и триграммного поиска', 'done', 'high', '2026-04-04'),

                                                                                                     (4, 5, 'Инвентаризация остатков', 'Реализовать экран инвентаризации товаров и остатков на складе', 'done', 'medium', '2026-03-20'),
                                                                                                     (4, 7, 'Тестирование поиска товаров', 'Проверить поиск товаров по названию, артикулу и части слова', 'done', 'medium', '2026-03-21'),
                                                                                                     (4, 5, 'Фильтрация складских операций', 'Добавить фильтрацию приходов, списаний и перемещений по дате', 'done', 'low', '2026-03-22'),
                                                                                                     (4, 7, 'Проверка похожих названий товаров', 'Оценить точность поиска при похожих и частично совпадающих названиях', 'done', 'low', '2026-03-23');

INSERT INTO comments (task_id, author_user_id, content) VALUES
                                                            (1, 1, 'Нужно использовать JWT и блокировку после нескольких неудачных попыток'),
                                                            (4, 1, 'Обязательно проверь поиск по частичному вводу фамилии'),
                                                            (9, 1, 'Для морфологии русского языка используй конфигурацию russian'),
                                                            (10, 4, 'Сравни планы до и после индексов'),
                                                            (12, 2, 'Для частичного поиска используем расширение pg_trgm'),
                                                            (14, 1, 'Совпадение в title должно иметь больший вес, чем совпадение в description'),
                                                            (15, 4, 'Покажи примеры словоформ: заказ, заказов, заказами'),
                                                            (16, 2, 'После создания индексов нужно повторно проверить EXPLAIN ANALYZE');


-- Сколько строк в таблицах
SELECT 'users' AS table_name, COUNT(*) AS rows_count FROM users
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'projects', COUNT(*) FROM projects
UNION ALL
SELECT 'project_members', COUNT(*) FROM project_members
UNION ALL
SELECT 'tasks', COUNT(*) FROM tasks
UNION ALL
SELECT 'comments', COUNT(*) FROM comments
ORDER BY table_name;

-- Запрос 1. Полнотекстовый поиск по словам "поиск заказов"
SELECT
    task_id,
    title,
    description,
    ts_rank(search_vector, websearch_to_tsquery('russian', 'поиск заказов')) AS rank
FROM tasks
WHERE search_vector @@ websearch_to_tsquery('russian', 'поиск заказов')
ORDER BY rank DESC, task_id;


-- Запрос 2. Должен находить: заказ, заказы, заказов, заказами
SELECT
    task_id,
    title,
    description,
    ts_rank(search_vector, plainto_tsquery('russian', 'заказы')) AS rank
FROM tasks
WHERE search_vector @@ plainto_tsquery('russian', 'заказы')
ORDER BY rank DESC, task_id;

-- Запрос 3. Префиксный полнотекстовый поиск
SELECT
    task_id,
    title,
    description,
    ts_rank(search_vector, to_tsquery('russian', 'поиск:* & заказ:*')) AS rank
FROM tasks
WHERE search_vector @@ to_tsquery('russian', 'поиск:* & заказ:*')
ORDER BY rank DESC, task_id;

-- Запрос 4. Быстрый поиск по частичному совпадению в начале слова
SELECT
    task_id,
    title,
    description
FROM tasks
WHERE title ILIKE 'поис%'
   OR description ILIKE 'поис%'
ORDER BY task_id;

-- Запрос 5. Поиск похожих строк по similarity
SELECT
    task_id,
    title,
    description,
    GREATEST(
            similarity(title, 'поиск'),
            similarity(description, 'поиск')
    ) AS trigram_rank
FROM tasks
WHERE title % 'поиск'
   OR description % 'поиск'
ORDER BY trigram_rank DESC, task_id;

-- Запрос 6. Комбинированный поиск:
SELECT
    task_id,
    title,
    description,
    ts_rank(search_vector, websearch_to_tsquery('russian', 'поиск заказов')) AS fts_rank,
    GREATEST(
            similarity(title, 'поиск'),
            similarity(description, 'поиск')
    ) AS trigram_rank
FROM tasks
WHERE search_vector @@ websearch_to_tsquery('russian', 'поиск заказов')
   OR title % 'поиск'
   OR description % 'поиск'
ORDER BY
    fts_rank DESC NULLS LAST,
    trigram_rank DESC NULLS LAST,
    task_id;

-- EXPLAIN 1. Полнотекстовый поиск
EXPLAIN ANALYZE
SELECT
    task_id,
    title,
    description,
    ts_rank(search_vector, websearch_to_tsquery('russian', 'поиск заказов')) AS rank
FROM tasks
WHERE search_vector @@ websearch_to_tsquery('russian', 'поиск заказов')
ORDER BY rank DESC, task_id;

-- EXPLAIN 2. Морфология русского языка
EXPLAIN ANALYZE
SELECT
    task_id,
    title,
    description,
    ts_rank(search_vector, plainto_tsquery('russian', 'заказы')) AS rank
FROM tasks
WHERE search_vector @@ plainto_tsquery('russian', 'заказы')
ORDER BY rank DESC, task_id;

-- EXPLAIN 3. Префиксный полнотекстовый поиск
EXPLAIN ANALYZE
SELECT
    task_id,
    title,
    description,
    ts_rank(search_vector, to_tsquery('russian', 'поиск:* & заказ:*')) AS rank
FROM tasks
WHERE search_vector @@ to_tsquery('russian', 'поиск:* & заказ:*')
ORDER BY rank DESC, task_id;

-- EXPLAIN 4. Триграммный поиск через ILIKE
EXPLAIN ANALYZE
SELECT
    task_id,
    title,
    description
FROM tasks
WHERE title ILIKE 'поис%'
   OR description ILIKE 'поис%'
ORDER BY task_id;

-- EXPLAIN 5. Триграммный поиск через similarity
EXPLAIN ANALYZE
SELECT
    task_id,
    title,
    description,
    GREATEST(
            similarity(title, 'поиск'),
            similarity(description, 'поиск')
    ) AS trigram_rank
FROM tasks
WHERE title % 'поиск'
   OR description % 'поиск'
ORDER BY trigram_rank DESC, task_id;

-- EXPLAIN 6. Комбинированный поиск
EXPLAIN ANALYZE
SELECT
    task_id,
    title,
    description,
    ts_rank(search_vector, websearch_to_tsquery('russian', 'поиск заказов')) AS fts_rank,
    GREATEST(
            similarity(title, 'поиск'),
            similarity(description, 'поиск')
    ) AS trigram_rank
FROM tasks
WHERE search_vector @@ websearch_to_tsquery('russian', 'поиск заказов')
   OR title % 'поиск'
   OR description % 'поиск'
ORDER BY
    fts_rank DESC NULLS LAST,
    trigram_rank DESC NULLS LAST,
    task_id;

-- Explain 1: https://explain.tensor.ru/archive/explain/f16639bbe3673424243215f7accc8958:0:2026-03-31
-- Explain 2: https://explain.tensor.ru/archive/explain/78cda20b31614ec0a3f111dbda33fe9c:0:2026-03-31
-- Explain 3: https://explain.tensor.ru/archive/explain/b2d3a5341794b83e61c828e4ec4dd082:0:2026-03-31
-- Explain 4: https://explain.tensor.ru/archive/explain/ced99c796b7e4af79114f5aa145ba46a:0:2026-03-31
-- Explain 5: https://explain.tensor.ru/archive/explain/c19688bfde367d4b626542ce6db5e5d5:0:2026-03-31
-- Explain 6: https://explain.tensor.ru/archive/explain/a8a8113d1b97dea8c83b4fcaa2b0492f:0:2026-03-31
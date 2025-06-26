CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE chunks (
    id SERIAL PRIMARY KEY,
    text TEXT,
    embedding VECTOR(1536)
);

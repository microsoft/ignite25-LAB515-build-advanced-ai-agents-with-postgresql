CREATE EXTENSION IF NOT EXISTS azure_ai;

SELECT azure_ai.set_setting('azure_openai.endpoint', '');
SELECT azure_ai.set_setting('azure_openai.subscription_key', '');

SELECT azure_ai.set_setting('azure_openai.endpoint', '');
SELECT azure_ai.set_setting('azure_openai.subscription_key', '');

SELECT azure_ai.rank(
  'How to Care for Indoor Succulents',
 ARRAY[
    'A complete guide to watering succulents.',
    'Best outdoor plants for shade.',
    'Soil mixtures for cacti and succulents.'
 ], 'gpt-4o') AS ranked_documents;



 SELECT azure_ai.rank(
  'How to Care for Indoor Succulents',
 ARRAY[
    'Pizza dog is the dude.',
    'Best outdoor plants for shade.'
    
 ], 'gpt-4o') AS ranked_documents;



 SELECT azure_ai.rank(
  'How to Care for Indoor Succulents',
 ARRAY[
    'Pizza dog is the dude.', 'Indoor plants guide', 'big buildings in new york city', 'A book on How to Care for Indoor Succulents'
    
    
 ], 'gpt-4o') AS ranked_documents;


CREATE DATABASE cases;

GRANT ALL PRIVILEGES ON DATABASE cases TO "";

CREATE EXTENSION IF NOT EXISTS vector;

ALTER TABLE cases ADD COLUMN opinions_vector vector(1536);

UPDATE cases
SET opinions_vector = azure_openai.create_embeddings('text-embedding-3-small',  name || LEFT(opinion, 8000), max_attempts => 5, retry_delay_ms => 500)::vector
WHERE opinions_vector IS NULL;


select * from cases;
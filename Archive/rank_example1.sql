-- // Step 1: Find top 60 cases using vector similarity search //
WITH vector_candidates AS (
    SELECT cases.id as case_id, cases.name AS case_name, cases.opinion,
           ROW_NUMBER() OVER (ORDER BY opinions_vector <=> azure_openai.create_embeddings('text-embedding-3-small', 'water leaking in my clients apartment')::vector) as rank_order
    FROM cases
    ORDER BY opinions_vector <=> azure_openai.create_embeddings('text-embedding-3-small', 'water leaking in my clients apartment')::vector
    LIMIT 40
),

-- // Step 2: Use azure_ai.rank() directly on the candidates //
ranked_results AS (
    SELECT 
        case_id, 
        case_name, 
        opinion,
        rank_order,
        azure_ai.rank(
            'water leaking in my clients apartment', 
            ARRAY[opinion], 
            'gpt-4o'
        ) as ranking_result
    FROM vector_candidates
)

-- // Step 3: Extract and order by ranking scores //
SELECT 
    case_id,
    case_name,
    opinion,
    ranking_result
FROM ranked_results
ORDER BY rank_order
LIMIT 10;
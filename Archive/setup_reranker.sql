-- These SQL commands are used to set up the Azure AI integration for semantic relevance scoring in a PostgreSQL database.
-- The first command sets the Azure OpenAI API key, which is required for authentication with the Azure OpenAI service.
-- The second command sets the Azure ML scoring endpoint, which is the URL of the Azure Machine Learning service that will be used for scoring.
select azure_ai.set_setting('azure_ml.scoring_endpoint','{ENDPOINT}');
select azure_ai.set_setting('azure_ml.endpoint_key', '{KEY}');

-- This function is used to call the Azure ML service for semantic relevance scoring.
-- It takes a query and an integer n as input, generates a JSON object with pairs of query and opinion text,
CREATE OR REPLACE FUNCTION semantic_relevance(query TEXT, n INT)
RETURNS jsonb AS $$
DECLARE
    json_pairs jsonb;
	result_json jsonb;
BEGIN
	json_pairs := generate_json_pairs(query, n);
	result_json := azure_ml.invoke(
				json_pairs,
				deployment_name=>'bge-v2-m3-1',
				timeout_ms => 180000);
	RETURN (
		SELECT result_json as result
	);
END $$ LANGUAGE plpgsql;

-- This function generates a JSON object with pairs of query and opinion text.
-- It uses the `cases` table to retrieve the opinions and their IDs, ordered by their similarity to the query.
CREATE OR REPLACE FUNCTION generate_json_pairs(query TEXT, n INT)
RETURNS jsonb AS $$
BEGIN
    RETURN (
        SELECT jsonb_build_object(
            'pairs', 
            jsonb_agg(
                jsonb_build_array(query, LEFT(text, 800))
            )
        ) AS result_json
        FROM (
            SELECT id, opinion AS text
		    FROM cases
		    ORDER BY opinions_vector <=> azure_openai.create_embeddings('text-embedding-3-small', query)::vector
		    LIMIT n
        ) subquery
    );
END $$ LANGUAGE plpgsql;
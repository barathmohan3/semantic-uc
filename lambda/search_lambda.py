import os, json, psycopg2
from openai import OpenAIEmbeddings

db_conn = psycopg2.connect(
    host=os.environ['DB_HOST'],
    user=os.environ['DB_USER'],
    password=os.environ['DB_PASSWORD'],
    dbname='vectorsearch'
)

def embed(query):
    from openai import OpenAI
    openai.api_key = os.environ['OPENAI_API_KEY']
    return OpenAIEmbeddings().embed_query(query)

def lambda_handler(event, context):
    body = json.loads(event["body"])
    query = body['query']
    vector = embed(query)

    cur = db_conn.cursor()
    cur.execute("""
        SELECT text FROM chunks ORDER BY embedding <-> %s LIMIT 5
    """, (vector,))
    results = cur.fetchall()

    return {
        "statusCode": 200,
        "body": json.dumps([r[0] for r in results])
    }

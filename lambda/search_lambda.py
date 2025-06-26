import os
import json
import psycopg2
from openai import OpenAI

def lambda_handler(event, context):
    query = json.loads(event["body"])["query"]
    client = OpenAI(api_key=os.environ['OPENAI_API_KEY'])
    embedding = client.embeddings.create(input=query, model="text-embedding-ada-002").data[0].embedding

    conn = psycopg2.connect(
        host=os.environ['DB_HOST'],
        user=os.environ['DB_USER'],
        password=os.environ['DB_PASSWORD'],
        dbname='vectorsearch'
    )
    cur = conn.cursor()
    cur.execute("SELECT content FROM documents ORDER BY embedding <-> %s LIMIT 3", (embedding,))
    rows = cur.fetchall()
    cur.close()
    conn.close()

    return {
        "statusCode": 200,
        "body": json.dumps({"results": [r[0] for r in rows]})
    }

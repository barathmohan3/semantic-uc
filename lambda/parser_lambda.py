import boto3
import os
import psycopg2
from PyPDF2 import PdfReader
from openai import OpenAI

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    bucket = event['bucket']
    key = event['key']

    # Download PDF
    local_path = f'/tmp/{key.split("/")[-1]}'
    s3.download_file(bucket, key, local_path)

    # Extract text
    reader = PdfReader(local_path)
    full_text = "\n".join([page.extract_text() or "" for page in reader.pages])
    chunks = [full_text[i:i+500] for i in range(0, len(full_text), 500)]

    # OpenAI embeddings
    client = OpenAI(api_key=os.environ['OPENAI_API_KEY'])
    embeddings = [client.embeddings.create(input=chunk, model="text-embedding-ada-002").data[0].embedding for chunk in chunks]

    # Store in PostgreSQL
    conn = psycopg2.connect(
        host=os.environ['DB_HOST'],
        user=os.environ['DB_USER'],
        password=os.environ['DB_PASSWORD'],
        dbname='vectorsearch'
    )
    cur = conn.cursor()
    cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
    cur.execute("CREATE TABLE IF NOT EXISTS documents (id serial PRIMARY KEY, content text, embedding vector(1536));")

    for chunk, vector in zip(chunks, embeddings):
        cur.execute("INSERT INTO documents (content, embedding) VALUES (%s, %s)", (chunk, vector))

    conn.commit()
    cur.close()
    conn.close()

    return {"status": "uploaded"}

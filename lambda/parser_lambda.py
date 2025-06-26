import boto3, os, psycopg2
from openai import OpenAIEmbeddings
import fitz  # PyMuPDF

db_conn = psycopg2.connect(
    host=os.environ['DB_HOST'],
    user=os.environ['DB_USER'],
    password=os.environ['DB_PASSWORD'],
    dbname='vectorsearch'
)

def parse_pdf(path):
    doc = fitz.open(path)
    return " ".join(page.get_text() for page in doc)

def chunk_text(text, chunk_size=500):
    words = text.split()
    return [" ".join(words[i:i+chunk_size]) for i in range(0, len(words), chunk_size)]

def embed(chunk):
    from openai import OpenAI
    openai.api_key = os.environ['OPENAI_API_KEY']
    return OpenAIEmbeddings().embed_query(chunk)

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    download_path = f"/tmp/{key}"
    s3.download_file(bucket, key, download_path)

    text = parse_pdf(download_path)
    chunks = chunk_text(text)
    vectors = [embed(c) for c in chunks]

    cur = db_conn.cursor()
    for c, v in zip(chunks, vectors):
        cur.execute("INSERT INTO chunks (text, embedding) VALUES (%s, %s)", (c, v))
    db_conn.commit()

    return {"statusCode": 200, "body": "Success"}
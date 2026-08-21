import chromadb
from chromadb import Documents, EmbeddingFunction
from google import genai
from decouple import config
class G(EmbeddingFunction):
 def __call__(self, input: Documents):
  client = genai.Client(api_key=config('GEMINI_API_KEY'))
  response = client.models.embed_content(model='gemini-embedding-001', contents=input)
  return [e.values for e in response.embeddings]
client=chromadb.PersistentClient(path='chroma_test')
collection=client.get_or_create_collection('test', embedding_function=G())
collection.upsert(ids=['1'], documents=['Teste'], metadatas=[{'a':1}])
print('Success')

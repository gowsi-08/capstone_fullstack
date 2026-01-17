import os

class Config:
    MONGO_URL = "mongodb+srv://gowsalyaanantharaj:gowsimongodb@cluster1.zh9gr.mongodb.net/?retryWrites=true&w=majority&appName=Cluster1"
    DB_NAME = 'findmyway'
    MAX_CONTENT_LENGTH = 100 * 1024 * 1024
    PORT = int(os.environ.get('PORT', 5000))
    DEBUG = True

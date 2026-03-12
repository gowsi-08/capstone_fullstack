import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    MONGO_URL = os.environ.get('MONGO_URL', 'mongodb+srv://gowsalyaanantharaj:gowsimongodb@cluster1.zh9gr.mongodb.net/?retryWrites=true&w=majority&appName=Cluster1')
    DB_NAME = os.environ.get('DB_NAME', 'findmyway')
    MAX_CONTENT_LENGTH = 100 * 1024 * 1024
    PORT = int(os.environ.get('PORT', 5000))
    DEBUG = os.environ.get('DEBUG', 'True').lower() == 'true'
    SECRET_KEY = os.environ.get('SECRET_KEY', 'findmyway-secret-key-change-in-production')
    ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', 'admin@admin.com')
    ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', 'KCETADMIN')

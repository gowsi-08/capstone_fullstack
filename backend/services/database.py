from pymongo import MongoClient
import gridfs
from config import Config

class DatabaseService:
    def __init__(self):
        self.client = MongoClient(Config.MONGO_URL)
        self.db = self.client[Config.DB_NAME]
        self.fs = gridfs.GridFS(self.db)

db_service = DatabaseService()
db = db_service.db
fs = db_service.fs

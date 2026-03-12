from flask import Flask
from flask_cors import CORS
from dotenv import load_dotenv
from config import Config
from routes.api import api_bp

# Load environment variables from .env file
load_dotenv()

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)
    
    # Initialize Extensions
    CORS(app)
    
    # Register Blueprints
    app.register_blueprint(api_bp)
    
    return app

app = create_app()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=Config.PORT, debug=Config.DEBUG)

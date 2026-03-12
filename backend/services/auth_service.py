from services.database import db
from config import Config
import hashlib

class AuthService:
    """Handles user authentication against MongoDB."""

    def __init__(self):
        self._ensure_users_exist()

    def _hash_password(self, password):
        return hashlib.sha256(password.encode('utf-8')).hexdigest()

    def _ensure_users_exist(self):
        """Create student users 22ucs001-22ucs180 and admin if they don't exist."""
        try:
            existing_count = db.users.count_documents({})
            if existing_count >= 181:
                print("✅ Users already seeded.")
                return

            print("🔄 Seeding users into MongoDB...")

            # Clear and re-seed
            db.users.delete_many({})

            users = []

            # Admin user
            users.append({
                'username': Config.ADMIN_EMAIL,
                'password': self._hash_password(Config.ADMIN_PASSWORD),
                'role': 'admin',
                'display_name': 'Admin'
            })

            # Student users: 22ucs001 to 22ucs180
            for i in range(1, 181):
                username = f"22ucs{i:03d}"
                users.append({
                    'username': username,
                    'password': self._hash_password(username),  # password = username
                    'role': 'student',
                    'display_name': f"Student {username.upper()}"
                })

            db.users.insert_many(users)
            # Create index on username for fast lookups
            db.users.create_index('username', unique=True)
            print(f"✅ Seeded {len(users)} users (1 admin + 180 students)")

        except Exception as e:
            print(f"⚠️ Error seeding users: {e}")

    def authenticate(self, username, password):
        """Authenticate user. Returns user dict or None."""
        hashed = self._hash_password(password)
        user = db.users.find_one({
            'username': username.strip().lower(),
            'password': hashed
        })
        if user:
            return {
                'username': user['username'],
                'role': user['role'],
                'display_name': user['display_name']
            }
        return None

auth_service = AuthService()

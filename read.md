Here is a comprehensive, step-by-step guide on how to set up and run this full-stack project (Flutter + Python/Flask) on a completely fresh Windows computer. 

This guide covers everything from the initial software installations to starting the actual application.

---

### Step 1: Download & Install Prerequisites
Before touching the code, you need to install the fundamental tools required for this project.

1. **Git**
   - **Download:** [Git for Windows](https://git-scm.com/download/win)
   - **Setup:** Run the installer and click "Next" through the default options. This allows you to clone the repository to your new PC.

2. **Python 3.11** (Backend)
   - **Download:** [Python 3.11.x](https://www.python.org/downloads/release/python-3119/) (Scroll down to Windows installer 64-bit).
   - **Setup:** ⚠️ **CRITICAL:** On the very first screen of the installer, check the box that says **"Add python.exe to PATH"** before clicking Install.

3. **Android Studio** (Frontend / Android Emulator)
   - **Download:** [Android Studio](https://developer.android.com/studio)
   - **Setup:** Run the installer with default settings. Once installed, open it and follow the initial setup wizard to install the Android SDK, Android SDK Command-line Tools, and Android Emulator.

4. **Flutter SDK** (Frontend)
   - **Download:** [Flutter Windows SDK](https://docs.flutter.dev/get-started/install/windows/desktop)
   - **Setup:** 
     1. Extract the downloaded zip file and place the `flutter` folder somewhere permanent (e.g., `C:\src\flutter`).
     2. Open your Windows Start menu, search for "Environment Variables", and click "Edit the system environment variables".
     3. Click the "Environment Variables..." button.
     4. Under "User variables", find `Path`, select it, and click "Edit" -> "New".
     5. Add the path to the flutter bin folder (e.g., `C:\src\flutter\bin`). Click OK on all windows.

5. **Visual Studio Code** (Code Editor)
   - **Download:** [VS Code](https://code.visualstudio.com/)
   - **Setup:** Install standard extensions from the Extensions tab on the left:
     - "Python" (by Microsoft)
     - "Flutter" (by Dart Code)
     - "Dart" (by Dart Code)

---

### Step 2: Finalize Flutter Configuration
Now we need to make sure Flutter recognizes Android Studio.

1. Open a terminal (Command Prompt or PowerShell) and run:
   ```bash
   flutter doctor
   ```
2. It might complain about Android licenses. If so, run this command and press `y` to accept all the licenses:
   ```bash
   flutter doctor --android-licenses
   ```
3. Run `flutter doctor` again. Everything essential (Flutter, Android toolchain, Android Studio) should now have a green checkmark.

---

### Step 3: Clone the Repository
Open a terminal where you want to store your project and run:
```bash
git clone <your-repository-url>
cd capstone
```

---

### Step 4: Setup and Run the Backend (Python/Flask)
The backend uses Python and connects to a MongoDB database (the MongoDB URL is already defined in your [.env](cci:7://file:///c:/Gowsi/capstone/backend/.env:0:0-0:0) and [config.py](cci:7://file:///c:/Gowsi/capstone/backend/config.py:0:0-0:0) files).

1. Open a terminal and navigate to the backend folder:
   ```bash
   cd backend
   ```
2. Create a virtual environment to isolate the Python packages:
   ```bash
   python -m venv venv
   ```
3. Activate the virtual environment:
   ```bash
   venv\Scripts\activate
   ```
   *(You should now see [(venv)](cci:1://file:///c:/Gowsi/capstone/frontend/lib/main.dart:12:0-20:1) at the beginning of your terminal prompt).*
4. Install all the required backend dependencies:
   ```bash
   pip install -r requirements.txt
   ```
5. Run the server:
   ```bash
   python app.py
   ```
   *(If successful, you will see output saying the Flask server is running on `http://0.0.0.0:5000`)*.

---

### Step 5: Setup and Run the Frontend (Flutter)
The frontend app is built using Flutter. 

*(Note: Currently, your app is hardcoded to connect to your live Render backend `https://capstone-server-yadf.onrender.com`. If you want to test with the local Python backend you just started, open [frontend/lib/api_service.dart](cci:7://file:///c:/Gowsi/capstone/frontend/lib/api_service.dart:0:0-0:0), find `const bool useProduction = true;` on **Line 13**, and change it to `false`).*

1. Open a **new** terminal (keep the backend one running) and navigate to the frontend folder:
   ```bash
   cd frontend
   ```
2. Fetch the Flutter packages for the project:
   ```bash
   flutter pub get
   ```
3. Open Android Studio and launch a Virtual Device (Emulator):
   - Open Android Studio -> Click "More Actions" (or the three dots) -> "Virtual Device Manager".
   - Create a device (e.g., Pixel 7) and click the Play "▶" button to start the emulator.
4. Once the emulator is running, go back to your terminal inside the `frontend` folder and run the app:
   ```bash
   flutter run
   ```

### You're Done! 🎉
You should now have the Python backend running in one terminal, and the Flutter app running on your Android Emulator, capable of communicating with each other.
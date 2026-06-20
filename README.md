SmartShield

Not everyone can afford a cybersecurity analyst, but everyone should have access to one.

SmartShield is an Android mobile security app built with Flutter, designed to protect users — especially elderly people — from digital scams, malicious files, and privacy-invasive apps. It combines real malware detection, AI-powered permission analysis, and scam-pattern recognition in a single, easy-to-understand interface.


Why SmartShield Exists

Elderly users are frequently targeted by scams that exploit a lack of technical knowledge — fake "bank statement" APKs, apps requesting excessive permissions, or hidden software quietly accessing personal data. SmartShield exists to give non-technical users a clear, honest answer to the question: "Is this safe?" — without requiring them to understand permissions, file hashes, or Android internals themselves.


Features


Real Malware Scanning — Files in Downloads, WhatsApp, Telegram, and Bluetooth folders are checked against VirusTotal's 70+ antivirus engines via their public API.
AI Permission Monitor — An AI chatbot (powered by Groq/Llama 3.3) explains, in plain English, what permissions installed apps have and whether anything looks suspicious. Distinguishes user-installed apps from built-in system services to avoid false alarms, and remembers conversation context across a chat session.
Quarantine & Scam Detection — Suspicious files trigger a clear warning screen rather than opening directly. Files requesting SMS + Accessibility + Call Log permissions together (a common banking-trojan pattern) are flagged specifically.
Threat Monitor — Detects hidden apps (no launcher icon) with sensitive permissions, active device admin apps, and active accessibility services that could be used for spying.
Junk File Scanner — Finds temporary files, leftover APK installers, and unusually large files taking up space.
Scan History — Every completed scan is saved with timestamp, files checked, and files flagged, viewable in a full history screen.
Bluetooth Connection Alerts — Notifies the user when a new Bluetooth device connects to their phone, so unexpected connections aren't missed.
Light & Dark Theme — Full theme support with theme-aware branding, persisted across sessions.
Cinematic Splash Intro — Plays on launch with the app's mission statement.



Tech Stack

LayerTechnologyApp frameworkFlutter / DartNative AndroidKotlin (MainActivity.kt) — permission inspection, accessibility/device admin checks, Bluetooth broadcast receiverMalware scanningVirusTotal Public API v3AI chatbotGroq API (Llama 3.3 70B)Local persistenceshared_preferencesNotificationsflutter_local_notificationsVideovideo_playerMarkdown renderingflutter_markdown


Project Structure

lib/
├── functions/
│   ├── permissions.dart       # Permission request helpers
│   └── virustotal.dart        # VirusTotal API integration
├── screens/
│   ├── splash_screen.dart     # Intro video + tagline
│   ├── files_screen.dart      # Suspicious files list
│   ├── junk_screen.dart       # Junk file scanner UI
│   ├── permission_chat_screen.dart  # AI permission monitor
│   ├── quarantine_screen.dart # Flagged files list
│   ├── threat_warning_screen.dart   # Block/warn screen for risky files
│   ├── threats_screen.dart    # Hidden apps / device admin / accessibility monitor
│   └── about_screen.dart      # App info and mission statement
├── services/
│   └── auto_scan_service.dart # Background auto-scan for new downloads
├── theme_colors.dart
├── models.dart                 # ScanController, ScanItem, JunkFile, Risk
└── main.dart

android/app/src/main/kotlin/.../MainActivity.kt
# Native permission inspection, AppOpsManager usage checks,
# hidden app / device admin / accessibility service detection,
# Bluetooth connection broadcast receiver


Getting Started

Prerequisites


Flutter SDK
An Android device or emulator
A free VirusTotal API key
A free Groq API key


Setup


Clone the repository:


   git clone https://github.com/jaysonxdev/smart-shield.git
   cd smart-shield


Install dependencies:


   flutter pub get


Create your local environment file from the example:


   cp .env.example .env


Open .env and add your real API keys:


   GROQ_API_KEY=your_groq_key_here
   VIRUSTOTAL_API_KEY=your_virustotal_key_here

.env is gitignored and will never be committed — keep your keys here, not in source code.


Run the app:


   flutter run


Important Notes


VirusTotal's free tier is rate-limited to 4 requests/minute. SmartShield respects this with a ~15.5s delay between file checks during scans — this is intentional, not a performance bug, and avoids the API key being banned.
The AI chatbot requires internet access (Groq API) but does not depend on any local machine or server.
This project does not implement true app sandboxing/isolation (would require Android Work Profile / device-owner level access, out of scope for this build). Suspicious files are instead intercepted with a clear warning screen before they can be opened.
Network-level attack detection (e.g., WiFi intrusion detection) is intentionally out of scope — it requires enterprise-grade packet inspection beyond what a standard Android app can reasonably implement. Bluetooth connection awareness is implemented instead as an honest, achievable alternative.



Security

A manual security review was conducted on file-handling logic, covering symlink traversal, path injection, and credential storage. No path traversal or symlink-following vulnerabilities were found. Defense-in-depth path containment checks were added before file deletion regardless. API keys are loaded from a gitignored .env file via flutter_dotenv, never hardcoded in source.


Author

Jayson Savio Patrick G
Final Year College Project

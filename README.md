# 🛡️ BGGuard — Module + App (All-in-One)

Red Magic 11 Pro (Android 16) এর জন্য। একটা zip flash করলেই module + app দুটোই ইন্সটল হবে।

---

## 📲 কীভাবে বানাবেন (৫ ধাপ)

### ধাপ ১ — GitHub এ নতুন repo বানান
github.com → **New repository** → নাম `BGGuard` → **Public** → Create

### ধাপ ২ — সব ফাইল আপলোড করুন
নতুন repo → **"uploading an existing file"** → এই ZIP এর **ভেতরের সব ফাইল/ফোল্ডার** drag করুন → **Commit changes**

### ধাপ ৩ — Build চালান (এক ক্লিক)
**Actions** ট্যাব → **"Build BGGuard Module"** → **Run workflow** বাটন → আবার **Run workflow**

### ধাপ ৪ — ডাউনলোড করুন (৩-৫ মিনিট পর)
সবুজ ✅ আসলে → **Releases** → **`BGGuard-Module.zip`** ডাউনলোড করুন

### ধাপ ৫ — Flash করুন
1. SukiSU Ultra → **Install from storage** → `BGGuard-Module.zip` সিলেক্ট
2. **Reboot** করুন
3. **BGGuard app আপনাআপনি ইন্সটল হয়ে যাবে** ✅
4. App খুলুন → root দিন → apps টিক দিন → Save

---

## 📂 এই Project এর গঠন

```
├── app/              ← Android app source code (Kotlin)
├── module/           ← Magisk module ফাইল
│   ├── customize.sh  ← flash এর সময় APK install করে
│   ├── service.sh    ← background protection daemon
│   ├── system/bin/   ← bgmon, bgconfig
│   └── ...
└── .github/workflows/build.yml  ← auto-build
```

Workflow যা করে: APK build → module/ এর ভেতরে APK রাখে → পুরোটা zip করে → Release এ দেয়।

---

## ⚙️ কমান্ড (Termux)

```sh
su -c "sh /data/local/tmp/bgmon"      # Live monitor
su -c "sh /data/local/tmp/bgconfig"   # Terminal থেকে whitelist সেট
```

App থেকেও whitelist সেট করা যায় (সহজ)।

---

## 🔧 সমস্যা হলে

**App auto-install হয়নি?**
→ একবার reboot দিন, boot এর ৫০ সেকেন্ড পর install হবে

**App এ root চায়?**
→ SukiSU Ultra তে BGGuard কে root grant করুন

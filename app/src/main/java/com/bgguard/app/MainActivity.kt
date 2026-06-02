package com.bgguard.app

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import com.bgguard.app.databinding.ActivityMainBinding
import com.topjohnwu.superuser.Shell
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var adapter: AppAdapter
    private var allApps = listOf<AppInfo>()
    private var showSystem = false

    companion object {
        const val CONF_PATH = "/data/adb/bgguard/whitelist.conf"
        init {
            // libsu config
            Shell.enableVerboseLogging = false
            Shell.setDefaultBuilder(
                Shell.Builder.create()
                    .setFlags(Shell.FLAG_MOUNT_MASTER)
                    .setTimeout(20)
            )
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        adapter = AppAdapter { app, checked ->
            app.whitelisted = checked
        }
        binding.recyclerView.layoutManager = LinearLayoutManager(this)
        binding.recyclerView.adapter = adapter

        binding.btnSave.setOnClickListener { saveWhitelist() }
        binding.btnRefresh.setOnClickListener { loadApps() }
        binding.switchSystem.setOnCheckedChangeListener { _, checked ->
            showSystem = checked
            applyFilter(binding.searchBox.text.toString())
        }

        binding.searchBox.addTextChangedListener(object : android.text.TextWatcher {
            override fun afterTextChanged(s: android.text.Editable?) {
                applyFilter(s.toString())
            }
            override fun beforeTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
            override fun onTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
        })

        checkRootAndLoad()
    }

    private fun checkRootAndLoad() {
        binding.statusText.text = "Root চেক করা হচ্ছে..."
        CoroutineScope(Dispatchers.IO).launch {
            val rootOk = Shell.getShell().isRoot
            withContext(Dispatchers.Main) {
                if (rootOk) {
                    binding.statusText.text = "✅ Root OK — apps লোড হচ্ছে..."
                    loadApps()
                } else {
                    binding.statusText.text = "❌ Root permission পাওয়া যায়নি!"
                    Toast.makeText(this@MainActivity,
                        "SukiSU Ultra তে root grant করুন", Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    private fun loadApps() {
        binding.statusText.text = "⏳ Apps লোড হচ্ছে..."
        CoroutineScope(Dispatchers.IO).launch {
            // Read current whitelist
            val current = readWhitelist()

            val pm = packageManager
            val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
            val list = packages.mapNotNull { ai ->
                try {
                    val isSystem = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                    AppInfo(
                        label = pm.getApplicationLabel(ai).toString(),
                        packageName = ai.packageName,
                        icon = pm.getApplicationIcon(ai),
                        whitelisted = current.contains(ai.packageName),
                        isSystem = isSystem
                    )
                } catch (e: Exception) { null }
            }.sortedWith(compareByDescending<AppInfo> { it.whitelisted }
                .thenBy { it.label.lowercase() })

            allApps = list
            withContext(Dispatchers.Main) {
                val wlCount = list.count { it.whitelisted }
                binding.statusText.text = "✅ ${list.size} apps | Whitelisted: $wlCount"
                applyFilter(binding.searchBox.text.toString())
            }
        }
    }

    private fun applyFilter(query: String) {
        val q = query.trim().lowercase()
        val filtered = allApps.filter { app ->
            (showSystem || !app.isSystem || app.whitelisted) &&
            (q.isEmpty() || app.label.lowercase().contains(q) ||
             app.packageName.lowercase().contains(q))
        }
        adapter.submit(filtered)
    }

    private fun readWhitelist(): Set<String> {
        val result = Shell.cmd("cat $CONF_PATH 2>/dev/null").exec()
        return result.out
            .map { it.trim() }
            .filter { it.isNotEmpty() && !it.startsWith("#") }
            .toSet()
    }

    private fun saveWhitelist() {
        val selected = allApps.filter { it.whitelisted }.map { it.packageName }
        binding.statusText.text = "💾 Save হচ্ছে..."
        CoroutineScope(Dispatchers.IO).launch {
            // Build the file content
            val sb = StringBuilder()
            sb.append("# BGGuard Whitelist\n")
            sb.append("# auto-generated by BGGuard app\n#\n")
            selected.forEach { sb.append("$it\n") }

            // Encode to base64 to avoid any shell-escaping problems (newlines, special chars)
            val b64 = android.util.Base64.encodeToString(
                sb.toString().toByteArray(Charsets.UTF_8),
                android.util.Base64.NO_WRAP
            )

            Shell.cmd("mkdir -p /data/adb/bgguard").exec()
            // Decode base64 and write atomically
            val res = Shell.cmd(
                "echo '$b64' | base64 -d > $CONF_PATH.tmp && mv $CONF_PATH.tmp $CONF_PATH"
            ).exec()

            // Signal daemon to reload whitelist
            Shell.cmd(
                "pid=\$(cat /data/adb/bgguard/service.pid 2>/dev/null); " +
                "[ -n \"\$pid\" ] && kill -HUP \$pid 2>/dev/null; true"
            ).exec()

            withContext(Dispatchers.Main) {
                if (res.isSuccess) {
                    binding.statusText.text = "✅ Saved! ${selected.size} apps protected"
                    Toast.makeText(this@MainActivity,
                        "✅ ${selected.size} টি app whitelist করা হলো", Toast.LENGTH_SHORT).show()
                } else {
                    binding.statusText.text = "❌ Save ব্যর্থ — root grant করুন"
                    Toast.makeText(this@MainActivity,
                        "Save ব্যর্থ — root access দরকার", Toast.LENGTH_LONG).show()
                }
            }
        }
    }
}

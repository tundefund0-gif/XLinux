package com.xlinux.terminal

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.NetworkInterface

class SshForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "xlinux_ssh"
        const val NOTIFICATION_ID = 5
        const val EXTRA_PORT = "port"
        var isRunning = false
            private set
        var currentPort = 8022
            private set

        fun start(context: Context, port: Int = 8022) {
            val intent = Intent(context, SshForegroundService::class.java).apply { putExtra(EXTRA_PORT, port) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent) else context.startService(intent)
        }

        fun stop(context: Context) { context.stopService(Intent(context, SshForegroundService::class.java)) }

        fun getDeviceIps(): List<String> {
            val ips = mutableListOf<String>()
            try {
                val interfaces = NetworkInterface.getNetworkInterfaces() ?: return ips
                for (iface in interfaces) {
                    if (iface.isLoopback || !iface.isUp) continue
                    for (addr in iface.inetAddresses) {
                        if (addr.isLoopbackAddress) continue
                        val host = addr.hostAddress ?: continue
                        if (host.contains("%")) continue
                        ips.add(host)
                    }
                }
            } catch (_: Exception) {}
            return ips
        }
    }

    private var sshdProcess: Process? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var monitorThread: Thread? = null

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onCreate() { super.onCreate(); createNotificationChannel() }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val port = intent?.getIntExtra(EXTRA_PORT, 8022) ?: 8022
        currentPort = port
        startForeground(NOTIFICATION_ID, buildNotification("Starting SSH on port $port..."))
        if (isRunning) { updateNotification("SSH running on port $port"); return START_STICKY }
        acquireWakeLock()
        startSshd(port)
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        monitorThread?.interrupt(); monitorThread = null
        sshdProcess?.destroyForcibly(); sshdProcess = null
        releaseWakeLock(); super.onDestroy()
    }

    private fun startSshd(port: Int) {
        if (sshdProcess?.isAlive == true) return
        isRunning = true

        monitorThread = Thread {
            try {
                val filesDir = applicationContext.filesDir.absolutePath
                val nativeLibDir = applicationContext.applicationInfo.nativeLibraryDir
                val pm = ProcessManager(filesDir, nativeLibDir)

                val bm = BootstrapManager(applicationContext, filesDir, nativeLibDir)
                try { bm.setupDirectories() } catch (_: Exception) {}
                try { bm.writeResolvConf() } catch (_: Exception) {}

                val resolvContent = getSystemDnsContent()
                try { File(filesDir, "config/resolv.conf").apply { parentFile?.mkdirs(); writeText(resolvContent) } } catch (_: Exception) {}
                try { File(filesDir, "rootfs/ubuntu/etc/resolv.conf").apply { parentFile?.mkdirs(); writeText(resolvContent) } } catch (_: Exception) {}

                val sshCommand = "echo 'root:xlinux' | chpasswd 2>/dev/null; " +
                    "sed -i 's/#ListenAddress.*/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config 2>/dev/null || echo 'ListenAddress 0.0.0.0' >> /etc/ssh/sshd_config 2>/dev/null; " +
                    "sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null; " +
                    "mkdir -p /var/run/sshd 2>/dev/null; " +
                    "/usr/sbin/sshd -D -e -p $port"

                var restartCount = 0
                val maxRestarts = 50

                while (restartCount <= maxRestarts && isRunning) {
                    sshdProcess = pm.startProotProcess(sshCommand)
                    updateNotification(when (restartCount) { 0 -> "SSH running on port $port"; else -> "SSH restarted ($restartCount)" })

                    val stderrReader = BufferedReader(InputStreamReader(sshdProcess!!.errorStream))
                    Thread {
                        try { stderrReader.readLines().forEach { android.util.Log.w("XLinux-SSH", it) } } catch (_: Exception) {}
                    }.start()

                    val exitCode = sshdProcess!!.waitFor()
                    if (!isRunning) break

                    restartCount++
                    if (restartCount <= maxRestarts) {
                        val delay = when { restartCount <= 3 -> 2000L; restartCount <= 10 -> 3000L; else -> 5000L }
                        updateNotification("SSH exited ($exitCode), restarting...")
                        Thread.sleep(delay)
                    } else {
                        isRunning = false
                        updateNotification("SSH stopped after $maxRestarts restarts")
                        stopSelf()
                    }
                }
            } catch (e: Exception) {
                isRunning = false
                updateNotification("SSH error: ${e.message?.take(80)}")
                android.util.Log.e("XLinux-SSH", "Failed", e)
                stopSelf()
            }
        }.apply { isDaemon = true; start() }
    }

    private fun getSystemDnsContent(): String {
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            val network = cm?.activeNetwork
            val linkProps = network?.let { cm.getLinkProperties(it) }
            val dns = linkProps?.dnsServers
            if (!dns.isNullOrEmpty()) return dns.joinToString("\n") { "nameserver ${it.hostAddress}" } + "\nnameserver 8.8.8.8\n"
        } catch (_: Exception) {}
        return "nameserver 8.8.8.8\nnameserver 8.8.4.4\n"
    }

    private fun acquireWakeLock() { releaseWakeLock(); val pm = getSystemService(Context.POWER_SERVICE) as PowerManager; wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "XLinux::SSH").apply { acquire(24 * 60 * 60 * 1000L) } }
    private fun releaseWakeLock() { try { wakeLock?.let { if (it.isHeld) it.release() } } catch (_: Exception) {}; wakeLock = null }
    private fun createNotificationChannel() { if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) { val ch = NotificationChannel(CHANNEL_ID, "XLinux SSH", NotificationManager.IMPORTANCE_LOW).apply { description = "SSH server" }; getSystemService(NotificationManager::class.java).createNotificationChannel(ch) } }
    private fun buildNotification(text: String): Notification { val pi = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE); val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CHANNEL_ID) else @Suppress("DEPRECATION") Notification.Builder(this); return b.setContentTitle("XLinux SSH").setContentText(text).setSmallIcon(android.R.drawable.ic_lock_lock).setContentIntent(pi).setOngoing(true).build() }
    private fun updateNotification(text: String) { try { getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, buildNotification(text)) } catch (_: Exception) {} }
}

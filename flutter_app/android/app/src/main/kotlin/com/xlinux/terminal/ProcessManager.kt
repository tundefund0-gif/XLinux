package com.xlinux.terminal

import android.os.Build
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

class ProcessManager(
    private val filesDir: String,
    private val nativeLibDir: String
) {
    private val rootfsDir get() = "$filesDir/rootfs/ubuntu"
    private val tmpDir get() = "$filesDir/tmp"
    private val homeDir get() = "$filesDir/home"
    private val configDir get() = "$filesDir/config"
    private val libDir get() = "$filesDir/lib"

    companion object {
        const val FAKE_KERNEL_RELEASE = "6.17.0-PRoot-Distro"
        const val FAKE_KERNEL_VERSION = "#1 SMP PREEMPT_DYNAMIC Fri, 10 Oct 2025 00:00:00 +0000"

        // Termux paths — proven to work on restrictive devices
        const val TERMUX_PROOT = "/data/data/com.termux/files/usr/bin/proot"
        const val TERMUX_LOADER = "/data/data/com.termux/files/usr/libexec/proot/loader"
        const val TERMUX_LOADER32 = "/data/data/com.termux/files/usr/libexec/proot/loader32"
        const val TERMUX_LIBTALLOC = "/data/data/com.termux/files/usr/lib/libtalloc.so.2"
    }

    private var resolvedProot = ""
    private var resolvedLoader = ""
    private var resolvedLoader32 = ""
    private var resolvedLibtalloc = ""

    /**
     * Resolve proot + loaders. Priority:
     * 1. Termux's binaries (proven to work on Xiaomi Android 15)
     * 2. nativeLibraryDir (may fail on noexec devices)
     */
    fun getProotPath(): String {
        if (resolvedProot.isNotEmpty()) return resolvedProot
        resolveProotBinaries()
        return resolvedProot
    }

    private fun resolveProotBinaries() {
        // 1. Termux's binaries — actually work on restrictive devices
        val termuxProot = File(TERMUX_PROOT)
        if (termuxProot.exists() && termuxProot.length() > 1000) {
            resolvedProot = TERMUX_PROOT
            resolvedLoader = if (File(TERMUX_LOADER).exists()) TERMUX_LOADER else ""
            resolvedLoader32 = if (File(TERMUX_LOADER32).exists()) TERMUX_LOADER32 else ""
            resolvedLibtalloc = if (File(TERMUX_LIBTALLOC).exists()) TERMUX_LIBTALLOC else ""
            android.util.Log.d("ProcessManager", "Using Termux proot: $resolvedProot")
            return
        }

        // 2. nativeLibraryDir fallback
        val nativeProot = File(nativeLibDir, "libproot.so")
        if (nativeProot.exists() && nativeProot.length() > 1000) {
            resolvedProot = nativeProot.absolutePath
            val nLoader = File(nativeLibDir, "libprootloader.so")
            val nLoader32 = File(nativeLibDir, "libprootloader32.so")
            resolvedLoader = if (nLoader.exists()) nLoader.absolutePath else ""
            resolvedLoader32 = if (nLoader32.exists()) nLoader32.absolutePath else ""
            android.util.Log.d("ProcessManager", "Using nativeLib proot: $resolvedProot")
            return
        }

        android.util.Log.e("ProcessManager", "No proot binary found!")
        resolvedProot = "$nativeLibDir/libproot.so"
    }

    private fun prootEnv(): Map<String, String> {
        val env = mutableMapOf<String, String>()
        env["PROOT_TMP_DIR"] = tmpDir

        // Loader paths
        env["PROOT_LOADER"] = if (resolvedLoader.isNotEmpty()) resolvedLoader else "$nativeLibDir/libprootloader.so"
        env["PROOT_LOADER_32"] = if (resolvedLoader32.isNotEmpty()) resolvedLoader32 else "$nativeLibDir/libprootloader32.so"

        // LD_LIBRARY_PATH — include Termux's lib dir for libtalloc
        val ldPaths = mutableListOf<String>()
        if (resolvedLibtalloc.isNotEmpty()) {
            ldPaths.add(File(resolvedLibtalloc).parent ?: "")
        }
        ldPaths.add(libDir)
        ldPaths.add(nativeLibDir)
        ldPaths.add("/data/data/com.termux/files/usr/lib")
        env["LD_LIBRARY_PATH"] = ldPaths.distinct().joinToString(":")

        return env
    }

    private fun ensureResolvConf() {
        val content = "nameserver 8.8.8.8\nnameserver 8.8.4.4\n"
        try {
            val resolvFile = File(configDir, "resolv.conf")
            if (!resolvFile.exists() || resolvFile.length() == 0L) {
                resolvFile.parentFile?.mkdirs()
                resolvFile.writeText(content)
            }
        } catch (_: Exception) {}
        try {
            val rootfsResolv = File(rootfsDir, "etc/resolv.conf")
            if (!rootfsResolv.exists() || rootfsResolv.length() == 0L) {
                rootfsResolv.parentFile?.mkdirs()
                rootfsResolv.writeText(content)
            }
        } catch (_: Exception) {}
    }

    private fun commonProotFlags(): List<String> {
        ensureResolvConf()
        val prootPath = getProotPath()
        val procFakes = "$configDir/proc_fakes"
        val sysFakes = "$configDir/sys_fakes"

        val flags = mutableListOf(
            prootPath,
            "--link2symlink",
            "-L",
            "--kill-on-exit",
            "--rootfs=$rootfsDir",
            "--cwd=/root",
            "--bind=/dev",
            "--bind=/dev/urandom:/dev/random",
            "--bind=/proc",
            "--bind=/sys",
        )

        // Only bind /proc/self/fd if readable (may be blocked on Android 15)
        try {
            if (File("/proc/self/fd").canRead()) {
                flags.addAll(listOf(
                    "--bind=/proc/self/fd:/dev/fd",
                    "--bind=/proc/self/fd/0:/dev/stdin",
                    "--bind=/proc/self/fd/1:/dev/stdout",
                    "--bind=/proc/self/fd/2:/dev/stderr",
                ))
            }
        } catch (_: Exception) {}

        flags.addAll(listOf(
            "--bind=$procFakes/loadavg:/proc/loadavg",
            "--bind=$procFakes/stat:/proc/stat",
            "--bind=$procFakes/uptime:/proc/uptime",
            "--bind=$procFakes/version:/proc/version",
            "--bind=$procFakes/vmstat:/proc/vmstat",
            "--bind=$procFakes/cap_last_cap:/proc/sys/kernel/cap_last_cap",
            "--bind=$procFakes/max_user_watches:/proc/sys/fs/inotify/max_user_watches",
            "--bind=$procFakes/fips_enabled:/proc/sys/crypto/fips_enabled",
            "--bind=$sysFakes/empty:/sys/fs/selinux",
            "--bind=$tmpDir:/tmp",
            "--bind=${File(configDir, "resolv.conf").absolutePath}:/etc/resolv.conf",
            "--sysvipc"
        ))

        return flags
    }

    private fun buildInstallCommand(command: String): List<String> {
        val flags = commonProotFlags().toMutableList()
        flags.addAll(listOf(
            "/usr/bin/env", "-i",
            "HOME=/root", "USER=root", "LANG=C.UTF-8",
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "TERM=xterm-256color", "TMPDIR=/tmp",
            "/bin/bash", "-c", command,
        ))
        return flags
    }

    fun buildGatewayCommand(command: String): List<String> {
        val flags = commonProotFlags().toMutableList()
        val arch = ArchUtils.getArch()
        val machine = when (arch) { "arm" -> "armv7l"; else -> arch }

        flags.add(1, "--change-id=0:0")
        flags.add(2, "--sysvipc")
        val kernelRelease = "\\Linux\\localhost\\$FAKE_KERNEL_RELEASE" +
            "\\$FAKE_KERNEL_VERSION\\$machine\\localdomain\\-1\\"
        flags.add(3, "--kernel-release=$kernelRelease")

        flags.addAll(listOf(
            "/usr/bin/env", "-i",
            "HOME=/root", "USER=root", "LANG=C.UTF-8",
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "TERM=xterm-256color", "TMPDIR=/tmp",
            "/bin/bash", "-c", command,
        ))
        return flags
    }

    fun buildProotCommand(command: String): List<String> = buildInstallCommand(command)

    fun runInProotSync(command: String, timeoutSeconds: Long = 900): String {
        val cmd = buildInstallCommand(command)
        val env = prootEnv()
        val pb = ProcessBuilder(cmd)
        pb.environment().clear()
        pb.environment().putAll(env)
        pb.redirectErrorStream(true)
        val process = pb.start()
        val output = StringBuilder()
        val reader = BufferedReader(InputStreamReader(process.inputStream))
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            val l = line ?: continue
            if (l.contains("proot warning") || l.contains("can't sanitize")) continue
            output.appendLine(l)
        }
        val exited = process.waitFor(timeoutSeconds, java.util.concurrent.TimeUnit.SECONDS)
        if (!exited) { process.destroyForcibly(); throw RuntimeException("Timed out") }
        val exitCode = process.exitValue()
        if (exitCode != 0) throw RuntimeException("Exit $exitCode: ${output.toString().takeLast(3000)}")
        return output.toString()
    }

    fun startProotProcess(command: String): Process {
        val cmd = buildGatewayCommand(command)
        val env = prootEnv()
        val pb = ProcessBuilder(cmd)
        pb.environment().clear()
        pb.environment().putAll(env)
        pb.redirectErrorStream(false)
        return pb.start()
    }
}

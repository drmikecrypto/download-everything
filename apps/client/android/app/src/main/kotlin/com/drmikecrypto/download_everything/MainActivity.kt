package com.drmikecrypto.download_everything

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.CookieManager
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "com.drmikecrypto.download_everything/ytdlp"
    private val cookiesChannelName = "com.drmikecrypto.download_everything/cookies"
    private val progressChannelName = "com.drmikecrypto.download_everything/ytdlp_progress"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var progressSink: EventChannel.EventSink? = null
    private var initialized = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, progressChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressSink = events
                }

                override fun onCancel(arguments: Any?) {
                    progressSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, cookiesChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCookies" -> {
                        val url = call.argument<String>("url") ?: "https://www.instagram.com/"
                        try {
                            val cm = CookieManager.getInstance()
                            cm.setAcceptCookie(true)
                            result.success(cm.getCookie(url))
                        } catch (t: Throwable) {
                            Log.e(TAG, "getCookies failed", t)
                            result.error("COOKIES_FAILED", t.fullMessage(), null)
                        }
                    }
                    "clearCookies" -> {
                        try {
                            val cm = CookieManager.getInstance()
                            cm.removeAllCookies {
                                cm.flush()
                                result.success(null)
                            }
                        } catch (t: Throwable) {
                            Log.e(TAG, "clearCookies failed", t)
                            result.error("COOKIES_FAILED", t.fullMessage(), null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> executor.execute {
                        try {
                            ensureNativeReady()
                            mainHandler.post { result.success(null) }
                        } catch (t: Throwable) {
                            Log.e(TAG, "yt-dlp initialize failed", t)
                            mainHandler.post {
                                result.error("INIT_FAILED", t.fullMessage(), null)
                            }
                        }
                    }

                    "analyze" -> {
                        val url = call.argument<String>("url")
                        val cookiesPath = call.argument<String>("cookiesPath")
                        if (url.isNullOrBlank()) {
                            result.error("BAD_ARGS", "url is required", null)
                            return@setMethodCallHandler
                        }
                        executor.execute {
                            try {
                                ensureNativeReady()
                                val request = YoutubeDLRequest(url)
                                applyCommonOptions(request, url, cookiesPath)
                                request.addOption("--dump-single-json")
                                request.addOption("--socket-timeout", "30")
                                val response = YoutubeDL.getInstance().execute(request)
                                mainHandler.post { result.success(response.out) }
                            } catch (t: Throwable) {
                                Log.e(TAG, "yt-dlp analyze failed", t)
                                mainHandler.post {
                                    result.error("ANALYZE_FAILED", t.fullMessage(), null)
                                }
                            }
                        }
                    }

                    "download" -> {
                        val url = call.argument<String>("url")
                        val format = call.argument<String>("format") ?: "best"
                        val outTemplate = call.argument<String>("outTemplate")
                        val cookiesPath = call.argument<String>("cookiesPath")
                        if (url.isNullOrBlank() || outTemplate.isNullOrBlank()) {
                            result.error("BAD_ARGS", "url and outTemplate are required", null)
                            return@setMethodCallHandler
                        }
                        executor.execute {
                            try {
                                ensureNativeReady()
                                val request = YoutubeDLRequest(url)
                                applyCommonOptions(request, url, cookiesPath)
                                request.addOption("-f", format)
                                request.addOption("--newline")
                                request.addOption("--merge-output-format", "mp4")
                                request.addOption("-o", outTemplate)
                                YoutubeDL.getInstance().execute(request) { progress, _, _ ->
                                    mainHandler.post {
                                        progressSink?.success(
                                            mapOf("progress" to progress.toDouble()),
                                        )
                                    }
                                }
                                val outFile = findOutputFile(outTemplate)
                                    ?: throw IllegalStateException("Output file not found")
                                mainHandler.post { result.success(outFile.absolutePath) }
                            } catch (t: Throwable) {
                                Log.e(TAG, "yt-dlp download failed", t)
                                mainHandler.post {
                                    result.error("DOWNLOAD_FAILED", t.fullMessage(), null)
                                }
                            }
                        }
                    }

                    "version" -> executor.execute {
                        try {
                            ensureNativeReady()
                            val version = YoutubeDL.getInstance().version(applicationContext)
                            mainHandler.post { result.success(version) }
                        } catch (t: Throwable) {
                            Log.e(TAG, "yt-dlp version failed", t)
                            mainHandler.post {
                                result.error("VERSION_FAILED", t.fullMessage(), null)
                            }
                        }
                    }

                    "update" -> executor.execute {
                        try {
                            ensureNativeReady()
                            YoutubeDL.getInstance().updateYoutubeDL(
                                applicationContext,
                                YoutubeDL.UpdateChannel.NIGHTLY,
                            )
                            mainHandler.post { result.success(null) }
                        } catch (t: Throwable) {
                            Log.e(TAG, "yt-dlp update failed", t)
                            mainHandler.post {
                                result.error("UPDATE_FAILED", t.fullMessage(), null)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    @Synchronized
    private fun ensureNativeReady() {
        if (initialized) return
        try {
            initNativeLibs()
        } catch (first: Throwable) {
            Log.w(TAG, "yt-dlp init failed — wiping extract cache and retrying", first)
            wipeYtdlpExtracts()
            try {
                initNativeLibs()
            } catch (second: Throwable) {
                throw IllegalStateException(
                    "Failed to start yt-dlp engine after retry. ${second.fullMessage()}",
                    second,
                )
            }
        }
        initialized = true
        maybeUpdateYtdlpOnce()
    }

    private fun initNativeLibs() {
        try {
            YoutubeDL.getInstance().init(applicationContext)
        } catch (t: Throwable) {
            throw IllegalStateException("YoutubeDL.init failed: ${t.fullMessage()}", t)
        }
        try {
            FFmpeg.getInstance().init(applicationContext)
        } catch (t: Throwable) {
            throw IllegalStateException("FFmpeg.init failed: ${t.fullMessage()}", t)
        }
    }

    private fun wipeYtdlpExtracts() {
        val base = File(applicationContext.noBackupFilesDir, YTDLP_BASE_DIR)
        if (base.exists()) {
            val deleted = base.deleteRecursively()
            Log.i(TAG, "wiped $YTDLP_BASE_DIR (ok=$deleted)")
        }
        // YoutubeDL tracks python package version here; clear so unzip runs again.
        applicationContext
            .getSharedPreferences(YTDLP_PREFS, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
    }

    private fun maybeUpdateYtdlpOnce() {
        val prefs = applicationContext.getSharedPreferences(APP_PREFS, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_YTDLP_UPDATED_ONCE, false)) return
        try {
            YoutubeDL.getInstance().updateYoutubeDL(
                applicationContext,
                YoutubeDL.UpdateChannel.NIGHTLY,
            )
            prefs.edit().putBoolean(KEY_YTDLP_UPDATED_ONCE, true).apply()
            Log.i(TAG, "one-shot yt-dlp update completed")
        } catch (t: Throwable) {
            Log.w(TAG, "one-shot yt-dlp update failed (non-fatal)", t)
        }
    }

    private fun applyCommonOptions(
        request: YoutubeDLRequest,
        url: String,
        cookiesPath: String?,
    ) {
        request.addOption("--no-playlist")
        request.addOption("--no-warnings")
        val isInstagram = url.contains("instagram.com", ignoreCase = true) ||
            url.contains("instagr.am", ignoreCase = true)
        // Custom UA breaks Instagram (empty media / 403); let yt-dlp choose headers there.
        if (!isInstagram) {
            request.addOption("--user-agent", MOBILE_USER_AGENT)
        } else {
            request.addOption("--extractor-args", "instagram:app_id=$INSTAGRAM_APP_ID")
        }
        if (!cookiesPath.isNullOrBlank() && File(cookiesPath).exists()) {
            request.addOption("--cookies", cookiesPath)
        }
    }

    private fun findOutputFile(outTemplate: String): File? {
        val placeholder = File(outTemplate)
        val dir = placeholder.parentFile ?: return null
        val prefix = placeholder.name
            .replace("%(ext)s", "")
            .replace("%(title)s", "")
            .trimEnd('.')
        if (!dir.exists()) return null

        val recentCutoff = System.currentTimeMillis() - 5 * 60 * 1000
        return dir.listFiles()
            ?.filter { it.isFile && it.lastModified() >= recentCutoff }
            ?.filter {
                prefix.isEmpty() ||
                    it.name.startsWith(prefix) ||
                    it.nameWithoutExtension.startsWith(prefix.trimEnd('.'))
            }
            ?.maxByOrNull { it.lastModified() }
    }

    companion object {
        private const val TAG = "DownloadEverything"
        private const val YTDLP_BASE_DIR = "youtubedl-android"
        private const val YTDLP_PREFS = "youtubedl-android"
        private const val APP_PREFS = "download_everything"
        private const val KEY_YTDLP_UPDATED_ONCE = "ytdlp_updated_once"
        private const val INSTAGRAM_APP_ID = "936619743392459"
        private const val MOBILE_USER_AGENT =
            "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"
    }
}

private fun Throwable.fullMessage(maxDepth: Int = 6): String {
    val parts = ArrayList<String>()
    var current: Throwable? = this
    var depth = 0
    while (current != null && depth < maxDepth) {
        val name = current.javaClass.simpleName
        val msg = current.message?.trim().orEmpty()
        parts += if (msg.isEmpty()) name else "$name: $msg"
        current = current.cause
        depth++
    }
    return parts.joinToString(" → ")
}

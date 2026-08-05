package com.drmikecrypto.download_everything

import android.os.Handler
import android.os.Looper
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
    private val progressChannelName = "com.drmikecrypto.download_everything/ytdlp_progress"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var progressSink: EventChannel.EventSink? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> executor.execute {
                        try {
                            YoutubeDL.getInstance().init(applicationContext)
                            FFmpeg.getInstance().init(applicationContext)
                            mainHandler.post { result.success(null) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("INIT_FAILED", e.message, null)
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
                                val request = YoutubeDLRequest(url)
                                request.addOption("--dump-single-json")
                                request.addOption("--no-playlist")
                                request.addOption("--no-warnings")
                                request.addOption("--socket-timeout", "30")
                                if (!cookiesPath.isNullOrBlank() && File(cookiesPath).exists()) {
                                    request.addOption("--cookies", cookiesPath)
                                }
                                val response = YoutubeDL.getInstance().execute(request)
                                mainHandler.post { result.success(response.out) }
                            } catch (e: Exception) {
                                mainHandler.post {
                                    result.error("ANALYZE_FAILED", e.message, null)
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
                                val request = YoutubeDLRequest(url)
                                request.addOption("-f", format)
                                request.addOption("--no-playlist")
                                request.addOption("--no-warnings")
                                request.addOption("--newline")
                                request.addOption("--merge-output-format", "mp4")
                                request.addOption("-o", outTemplate)
                                if (!cookiesPath.isNullOrBlank() && File(cookiesPath).exists()) {
                                    request.addOption("--cookies", cookiesPath)
                                }
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
                            } catch (e: Exception) {
                                mainHandler.post {
                                    result.error("DOWNLOAD_FAILED", e.message, null)
                                }
                            }
                        }
                    }

                    "version" -> executor.execute {
                        try {
                            val version = YoutubeDL.getInstance().version(applicationContext)
                            mainHandler.post { result.success(version) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("VERSION_FAILED", e.message, null)
                            }
                        }
                    }

                    "update" -> executor.execute {
                        try {
                            YoutubeDL.getInstance().updateYoutubeDL(
                                applicationContext,
                                YoutubeDL.UpdateChannel.STABLE,
                            )
                            mainHandler.post { result.success(null) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("UPDATE_FAILED", e.message, null)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
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
            ?.filter { prefix.isEmpty() || it.name.startsWith(prefix) || it.nameWithoutExtension.startsWith(prefix.trimEnd('.')) }
            ?.maxByOrNull { it.lastModified() }
    }
}

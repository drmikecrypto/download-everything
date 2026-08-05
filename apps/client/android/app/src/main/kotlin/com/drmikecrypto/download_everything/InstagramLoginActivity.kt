package com.drmikecrypto.download_everything

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView

/**
 * Native Instagram login WebView. Returns cookie header when sessionid appears.
 * Avoids Flutter webview_flutter (breaks macOS AOT snapshot in CI).
 */
class InstagramLoginActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var webView: WebView? = null
    private var finished = false

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (finished) return
            val cookies = CookieManager.getInstance().getCookie(HOME_URL)
                ?: CookieManager.getInstance().getCookie("https://instagram.com/")
            if (cookies != null && cookies.contains("sessionid=")) {
                finishWithCookies(cookies)
                return
            }
            handler.postDelayed(this, 1000L)
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        CookieManager.getInstance().setAcceptCookie(true)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#0a0a0f"))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }

        val header = TextView(this).apply {
            text = "Sign in once. Your session stays on this device and unlocks posts, reels, and stories."
            setTextColor(Color.parseColor("#a0a0b0"))
            textSize = 13f
            setPadding(48, 36, 48, 36)
        }
        root.addView(
            header,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )

        val webContainer = FrameLayout(this)
        val progress = ProgressBar(this).apply {
            isIndeterminate = true
        }
        val progressParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER,
        )

        val wv = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.cacheMode = WebSettings.LOAD_DEFAULT
            settings.userAgentString = MOBILE_UA
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
            CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
            webChromeClient = WebChromeClient()
            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    progress.visibility = android.view.View.GONE
                    checkCookiesOnce()
                }
            }
        }
        webView = wv
        webContainer.addView(
            wv,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        webContainer.addView(progress, progressParams)
        root.addView(
            webContainer,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f,
            ),
        )
        setContentView(root)
        title = "Connect Instagram"

        wv.loadUrl(LOGIN_URL)
        handler.postDelayed(pollRunnable, 1500L)
    }

    private fun checkCookiesOnce() {
        if (finished) return
        val cookies = CookieManager.getInstance().getCookie(HOME_URL)
            ?: CookieManager.getInstance().getCookie("https://instagram.com/")
        if (cookies != null && cookies.contains("sessionid=")) {
            finishWithCookies(cookies)
        }
    }

    private fun finishWithCookies(cookies: String) {
        if (finished) return
        finished = true
        handler.removeCallbacks(pollRunnable)
        CookieManager.getInstance().flush()
        setResult(
            RESULT_OK,
            Intent().putExtra(EXTRA_COOKIES, cookies),
        )
        finish()
    }

    private fun finishCancelled() {
        if (finished) return
        finished = true
        handler.removeCallbacks(pollRunnable)
        setResult(RESULT_CANCELED)
        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        finishCancelled()
    }

    override fun onDestroy() {
        handler.removeCallbacks(pollRunnable)
        webView?.apply {
            stopLoading()
            destroy()
        }
        webView = null
        super.onDestroy()
    }

    companion object {
        const val EXTRA_COOKIES = "cookies"
        private const val LOGIN_URL = "https://www.instagram.com/accounts/login/"
        private const val HOME_URL = "https://www.instagram.com/"
        private const val MOBILE_UA =
            "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"
    }
}

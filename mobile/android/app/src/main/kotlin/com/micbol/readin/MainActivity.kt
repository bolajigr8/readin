package com.micbol.readin

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.view.KeyEvent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong

/**
 * Native glue for ReadIn:
 *  - volume buttons turn pages            (readin/volume, readin/volume_events)
 *  - files shared / opened from other apps (readin/files, readin/incoming)
 *  - folder scan, "Open with…", share file (readin/files)
 *  - read-aloud notification + controls    (readin/readaloud, readin/readaloud_events)
 */
class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private val counter = AtomicLong(System.currentTimeMillis())

    private var volumeSink: EventChannel.EventSink? = null
    private var interceptVolume = false

    private var incomingSink: EventChannel.EventSink? = null
    private val pendingIncoming = ArrayList<String>()

    private var folderResult: MethodChannel.Result? = null

    companion object {
        private const val REQ_FOLDER = 4201
        private const val REQ_NOTIFICATIONS = 4202
        private val SUPPORTED = setOf(
            "pdf", "epub", "mobi", "azw3", "fb2", "cbz", "cbr",
            "docx", "doc", "odt", "rtf", "xlsx", "xls", "csv",
            "pptx", "ppt", "txt", "md", "html", "htm",
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // ── volume buttons ────────────────────────────────────────────────────
        MethodChannel(messenger, "readin/volume").setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> { interceptVolume = true; result.success(null) }
                "disable" -> { interceptVolume = false; result.success(null) }
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "readin/volume_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { volumeSink = events }
                override fun onCancel(arguments: Any?) { volumeSink = null }
            }
        )

        // ── files ─────────────────────────────────────────────────────────────
        MethodChannel(messenger, "readin/files").setMethodCallHandler { call, result ->
            when (call.method) {
                "takeIncoming" -> {
                    val list = ArrayList(pendingIncoming)
                    pendingIncoming.clear()
                    result.success(list)
                }
                "pickFolder" -> pickFolder(result)
                "openFile" -> openFile(call.argument("path"), call.argument("mime"), result)
                "shareFile" -> shareFile(
                    call.argument("path"), call.argument("mime"), call.argument("text"), result,
                )
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "readin/incoming").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    incomingSink = events
                    flushIncoming()
                }
                override fun onCancel(arguments: Any?) { incomingSink = null }
            }
        )

        // ── read aloud (foreground service + notification) ────────────────────
        MethodChannel(messenger, "readin/readaloud").setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    askNotificationPermission()
                    val i = Intent(this, ReadAloudService::class.java)
                        .setAction(ReadAloudService.ACTION_SHOW)
                        .putExtra("title", call.argument<String>("title") ?: "ReadIn")
                        .putExtra("text", call.argument<String>("text") ?: "")
                        .putExtra("playing", call.argument<Boolean>("playing") ?: false)
                    try {
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SERVICE", e.message, null)
                    }
                }
                "stop" -> {
                    stopService(Intent(this, ReadAloudService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "readin/readaloud_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    ReadAloudBridge.sink = events
                }
                override fun onCancel(arguments: Any?) { ReadAloudBridge.sink = null }
            }
        )

        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    // ── volume keys ───────────────────────────────────────────────────────────

    private fun isVolumeKey(keyCode: Int) =
        keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (interceptVolume && isVolumeKey(keyCode)) {
            if (event.repeatCount == 0) {
                volumeSink?.success(if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) "up" else "down")
            }
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        if (interceptVolume && isVolumeKey(keyCode)) return true
        return super.onKeyUp(keyCode, event)
    }

    // ── incoming files (share sheet / "Open with") ────────────────────────────

    @Suppress("DEPRECATION")
    private fun collectUris(intent: Intent): List<Uri> {
        if (intent.getBooleanExtra("readin_handled", false)) return emptyList()
        val out = LinkedHashSet<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val u = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (u != null) out.add(u)
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val list = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                if (list != null) out.addAll(list)
            }
            Intent.ACTION_VIEW -> {
                val d = intent.data
                if (d != null) out.add(d)
            }
        }
        val clip = intent.clipData
        if (clip != null && intent.action != null && intent.action != Intent.ACTION_MAIN) {
            for (i in 0 until clip.itemCount) {
                val u = clip.getItemAt(i).uri
                if (u != null) out.add(u)
            }
        }
        if (out.isNotEmpty()) intent.putExtra("readin_handled", true)
        return out.toList()
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val uris = collectUris(intent)
        if (uris.isEmpty()) return
        io.execute {
            val paths = uris.mapNotNull { copyToCache(it) }
            main.post {
                pendingIncoming.addAll(paths)
                flushIncoming()
            }
        }
    }

    private fun flushIncoming() {
        val sink = incomingSink ?: return
        if (pendingIncoming.isEmpty()) return
        val list = ArrayList(pendingIncoming)
        pendingIncoming.clear()
        sink.success(list)
    }

    private fun displayName(uri: Uri): String? {
        if (uri.scheme == "content") {
            try {
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                    if (c.moveToFirst()) {
                        val n = c.getString(0)
                        if (!n.isNullOrBlank()) return n
                    }
                }
            } catch (e: Exception) {
                // fall through
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/')
    }

    /** Copies a content/file URI into cache/incoming/<unique>/<original name>. */
    private fun copyToCache(uri: Uri): String? {
        return try {
            val name = (displayName(uri) ?: "file").replace(Regex("[^A-Za-z0-9._ ()-]"), "_")
            val dir = File(cacheDir, "incoming/${counter.incrementAndGet()}")
            dir.mkdirs()
            val dest = File(dir, name)
            val input = contentResolver.openInputStream(uri) ?: return null
            input.use { i -> dest.outputStream().use { o -> i.copyTo(o) } }
            dest.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    // ── folder scan (Storage Access Framework) ────────────────────────────────

    private fun pickFolder(result: MethodChannel.Result) {
        if (folderResult != null) {
            result.error("BUSY", "The folder picker is already open.", null)
            return
        }
        folderResult = result
        @Suppress("DEPRECATION")
        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), REQ_FOLDER)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_FOLDER) return
        val res = folderResult ?: return
        folderResult = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            res.success(ArrayList<String>())
            return
        }
        io.execute {
            val out = ArrayList<String>()
            try {
                walk(tree, DocumentsContract.getTreeDocumentId(tree), 0, out)
            } catch (e: Exception) {
                // return what we have
            }
            main.post { res.success(out) }
        }
    }

    private fun walk(tree: Uri, docId: String, depth: Int, out: MutableList<String>) {
        if (depth > 6 || out.size >= 200) return
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, docId)
        val cols = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        contentResolver.query(children, cols, null, null, null)?.use { c ->
            while (c.moveToNext() && out.size < 200) {
                val id = c.getString(0)
                val name = c.getString(1) ?: continue
                val mime = c.getString(2)
                if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    walk(tree, id, depth + 1, out)
                } else if (SUPPORTED.contains(name.substringAfterLast('.', "").lowercase())) {
                    val u = DocumentsContract.buildDocumentUriUsingTree(tree, id)
                    val p = copyToCache(u)
                    if (p != null) out.add(p)
                }
            }
        }
    }

    // ── "Open with…" and sharing (FileProvider) ───────────────────────────────

    private fun uriFor(path: String): Uri =
        FileProvider.getUriForFile(this, "$packageName.fileprovider", File(path))

    private fun openFile(path: String?, mime: String?, result: MethodChannel.Result) {
        if (path == null) { result.error("ARG", "path is required", null); return }
        try {
            val i = Intent(Intent.ACTION_VIEW)
                .setDataAndType(uriFor(path), mime ?: "*/*")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(Intent.createChooser(i, "Open with").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.error("NO_APP", "No app can open this file.", null)
        } catch (e: Exception) {
            result.error("OPEN", e.message, null)
        }
    }

    private fun shareFile(path: String?, mime: String?, text: String?, result: MethodChannel.Result) {
        if (path == null) { result.error("ARG", "path is required", null); return }
        try {
            val i = Intent(Intent.ACTION_SEND)
                .setType(mime ?: "*/*")
                .putExtra(Intent.EXTRA_STREAM, uriFor(path))
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (!text.isNullOrBlank()) i.putExtra(Intent.EXTRA_TEXT, text)
            startActivity(Intent.createChooser(i, "Share").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
            result.success(true)
        } catch (e: Exception) {
            result.error("SHARE", e.message, null)
        }
    }

    // ── notifications permission (Android 13+) ────────────────────────────────

    private fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33) {
            val perm = Manifest.permission.POST_NOTIFICATIONS
            if (checkSelfPermission(perm) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(perm), REQ_NOTIFICATIONS)
            }
        }
    }
}

package com.example.newbuddy

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.os.Handler
import android.os.Looper
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.AudioFormat
import ai.picovoice.cobra.Cobra
import ai.picovoice.cobra.CobraException
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.nio.ByteBuffer
import java.nio.ByteOrder

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL_NAME = "com.example.newbuddy/cobra_vad"
    private val EVENT_CHANNEL_NAME = "com.example.newbuddy/cobra_vad_events"

    private var cobra: Cobra? = null
    private var eventSink: EventChannel.EventSink? = null
    private val executor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initCobra" -> {
                        try {
                            val accessKey = call.argument<String>("accessKey")!!
                            cobra = Cobra(accessKey)
                            result.success(null)
                        } catch (e: CobraException) {
                            result.error("CobraException", e.message, null)
                        }
                    }
                    "startCobra" -> {
                        startVAD()
                        result.success(null)
                    }
                    "stopCobra" -> {
                        stopVAD()
                        result.success(null)
                    }
                    "process" -> {
                        try {
                            val frame = call.argument<ByteArray>("frame")!!
                            if (cobra != null) {
                                val pcm = ShortArray(frame.size / 2)
                                ByteBuffer.wrap(frame).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(pcm)
                                
                                val voiceProbability = cobra!!.process(pcm)
                                runOnUiThread {
                                    eventSink?.success(voiceProbability)
                                }
                                result.success(null)
                            } else {
                                result.error("CobraNotInitialized", "Cobra engine is not initialized", null)
                            }
                        } catch (e: CobraException) {
                            result.error("CobraException", e.message, null)
                        } catch (e: Exception) {
                            result.error("ProcessError", e.message, null)
                        }
                    }
                    "disposeCobra" -> {
                        cobra?.delete()
                        cobra = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_NAME)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun startVAD() {
        executor.submit(VADCallable())
    }

    private fun stopVAD() {
        isVADRunning.set(false)
    }

    private val isVADRunning = AtomicBoolean(false)

    private inner class VADCallable : Callable<Void?> {
        override fun call(): Void? {
            if (isVADRunning.get()) {
                return null
            }
            isVADRunning.set(true)

            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)
            val bufferSize = cobra!!.frameLength * 2
            val audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                cobra!!.sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )
            audioRecord.startRecording()

            val pcm = ShortArray(cobra!!.frameLength)
            val mainHandler = Handler(Looper.getMainLooper())

            while (isVADRunning.get()) {
                if (audioRecord.read(pcm, 0, pcm.size) == pcm.size) {
                    try {
                        val voiceProbability = cobra!!.process(pcm)
                        mainHandler.post {
                            eventSink?.success(voiceProbability)
                        }
                    } catch (e: CobraException) {
                        mainHandler.post {
                            eventSink?.error("CobraException", e.message, null)
                        }
                    }
                }
            }

            audioRecord.stop()
            audioRecord.release()
            return null
        }
    }
}
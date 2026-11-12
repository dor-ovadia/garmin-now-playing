package com.dor.nowplaying

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.view.View
import java.util.Calendar

/**
 * Approximate picture of the watch face for the design screen. It follows the same
 * layout rules as NowPlayingView.mc, with sample numbers, so colours and switches can be
 * judged before they reach the watch. Fonts differ from the real watch.
 */
class WatchPreviewView(context: Context, private val config: DesignConfig) : View(context) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val box = RectF()

    private val tick = object : Runnable {
        override fun run() {
            invalidate()
            postDelayed(this, 1000)
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        post(tick)
    }

    override fun onDetachedFromWindow() {
        removeCallbacks(tick)
        super.onDetachedFromWindow()
    }

    override fun onMeasure(widthSpec: Int, heightSpec: Int) {
        val size = minOf(MeasureSpec.getSize(widthSpec), (260 * resources.displayMetrics.density).toInt())
        setMeasuredDimension(MeasureSpec.getSize(widthSpec), size)
    }

    override fun onDraw(canvas: Canvas) {
        val d = height.toFloat()          // diameter of the watch
        val cx = width / 2f
        val cy = d / 2f
        val left = cx - d / 2f
        val u = d / 454f                  // one watch pixel
        val now = Calendar.getInstance()
        val second = now.get(Calendar.SECOND)

        paint.style = Paint.Style.FILL
        paint.color = opaque(config[DesignConfig.BACKGROUND])
        canvas.drawCircle(cx, cy, d / 2f, paint)

        val seconds = config.isOn(DesignConfig.SHOW_SECONDS)
        if (seconds) {
            val r = d / 2f - 3 * u
            stroke(0x1F1F1F, 2 * u)
            canvas.drawCircle(cx, cy, r, paint)
            stroke(config[DesignConfig.SECONDS_COLOR], 3 * u)
            box.set(cx - r, cy - r, cx + r, cy + r)
            canvas.drawArc(box, -90f, second * 6f, false, paint)
            paint.style = Paint.Style.FILL
            val angle = Math.toRadians(second * 6.0 - 90)
            canvas.drawCircle(cx + r * Math.cos(angle).toFloat(), cy + r * Math.sin(angle).toFloat(), 5 * u, paint)
        }

        val gaugeRadius = d / 2f - (if (seconds) 22 else 9) * u
        box.set(cx - gaugeRadius, cy - gaugeRadius, cx + gaugeRadius, cy + gaugeRadius)
        drawGauge(canvas, DesignConfig.LEFT_SOURCE, DesignConfig.LEFT_COLOR, 135f, 90f, u)
        drawGauge(canvas, DesignConfig.RIGHT_SOURCE, DesignConfig.RIGHT_COLOR, 45f, -90f, u)

        paint.style = Paint.Style.FILL
        paint.textAlign = Paint.Align.CENTER

        if (config.isOn(DesignConfig.SHOW_HEART)) {
            text(canvas, "\u2665 72", cx, d * 0.16f, 30 * u, config[DesignConfig.HEART_COLOR])
        }
        val time = String.format("%02d:%02d", now.get(Calendar.HOUR_OF_DAY), now.get(Calendar.MINUTE))
        text(canvas, time, cx, d * 0.32f, 110 * u, config[DesignConfig.TIME_COLOR], bold = true)
        if (config.isOn(DesignConfig.SHOW_DATE)) {
            text(canvas, "\u05d2\u05f3 10 \u05e0\u05d5\u05d1", cx, d * 0.485f, 30 * u, config[DesignConfig.DATE_COLOR])
        }
        sample(config[DesignConfig.LEFT_SOURCE])?.let {
            text(canvas, it.first, left + d * 0.30f, d * 0.57f, 26 * u, config[DesignConfig.LEFT_COLOR])
        }
        sample(config[DesignConfig.RIGHT_SOURCE])?.let {
            text(canvas, it.first, left + d * 0.70f, d * 0.57f, 26 * u, config[DesignConfig.RIGHT_COLOR])
        }

        if (config.isOn(DesignConfig.SHOW_BARS)) {
            paint.color = opaque(config[DesignConfig.BARS_COLOR])
            val heights = BAR_HEIGHTS[second % 4]
            for (i in 0 until 4) {
                val x = cx + (-16 + i * 9) * u
                canvas.drawRect(x, d * 0.67f - heights[i] * u, x + 5 * u, d * 0.67f, paint)
            }
        }
        text(canvas, "\u05d9\u05d3\u05e2\u05ea \u05e9\u05d6\u05d4 \u05d6\u05de\u05e0\u05d9", cx, d * 0.73f, 34 * u, config[DesignConfig.TITLE_COLOR], bold = true)
        text(canvas, "\u05d0\u05d9\u05d9\u05dc \u05d2\u05d5\u05dc\u05df", cx, d * 0.815f, 26 * u, 0xAAAAAA)

        if (config.isOn(DesignConfig.SHOW_PROGRESS)) {
            val barWidth = d * 0.34f
            val x = cx - barWidth / 2f
            val y = d * 0.885f
            paint.color = opaque(0x3A3A3A)
            canvas.drawRoundRect(x, y, x + barWidth, y + 4 * u, 2 * u, 2 * u, paint)
            paint.color = opaque(config[DesignConfig.PROGRESS_COLOR])
            canvas.drawRoundRect(x, y, x + barWidth * 0.42f, y + 4 * u, 2 * u, 2 * u, paint)
        }
    }

    private fun drawGauge(canvas: Canvas, sourceKey: String, colorKey: String, start: Float, sweep: Float, u: Float) {
        val value = sample(config[sourceKey]) ?: return
        paint.strokeCap = Paint.Cap.ROUND
        stroke(0x2C2C2A, 11 * u)
        canvas.drawArc(box, start, sweep, false, paint)
        stroke(config[colorKey], 11 * u)
        canvas.drawArc(box, start, sweep * value.second, false, paint)
        paint.strokeCap = Paint.Cap.BUTT
    }

    /** Sample text and fill level for an arc source; null when the arc is switched off. */
    private fun sample(source: Int): Pair<String, Float>? = when (source) {
        DesignConfig.SOURCE_BODY_BATTERY -> "64" to 0.64f
        DesignConfig.SOURCE_STEPS -> (if (config.isOn(DesignConfig.STEPS_IN_K)) "6.2k" else "6214") to 0.62f
        DesignConfig.SOURCE_WATCH_BATTERY -> "81%" to 0.81f
        DesignConfig.SOURCE_FLOORS -> "7" to 0.70f
        DesignConfig.SOURCE_ACTIVE_MINUTES -> "95" to 0.63f
        else -> null
    }

    private fun stroke(color: Int, width: Float) {
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = width
        paint.color = opaque(color)
    }

    private fun text(canvas: Canvas, text: String, x: Float, y: Float, size: Float, color: Int, bold: Boolean = false) {
        paint.style = Paint.Style.FILL
        paint.color = opaque(color)
        paint.textSize = size
        paint.isFakeBoldText = bold
        canvas.drawText(text, x, y - (paint.descent() + paint.ascent()) / 2f, paint)
    }

    private fun opaque(rgb: Int): Int = rgb or (0xFF shl 24)

    private companion object {
        val BAR_HEIGHTS = arrayOf(intArrayOf(12, 19, 9, 15), intArrayOf(17, 10, 19, 11), intArrayOf(9, 16, 13, 19), intArrayOf(19, 12, 16, 9))
    }
}

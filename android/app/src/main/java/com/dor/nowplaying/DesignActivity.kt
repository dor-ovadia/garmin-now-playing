package com.dor.nowplaying

import android.app.Activity
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.Switch
import android.widget.TextView

/**
 * Design screen: every change is shown in the preview at once and sent to the watch
 * about half a second after the last tap.
 */
class DesignActivity : Activity() {

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var config: DesignConfig
    private lateinit var preview: WatchPreviewView
    private lateinit var statusView: TextView
    private lateinit var controls: LinearLayout
    private var density = 1f

    private val sendToWatch = Runnable {
        Status.designResult = "שולח לשעון…"
        GarminLink.sendConfig(config.toMessage())
    }

    private val refreshStatus = object : Runnable {
        override fun run() {
            statusView.text = Status.designResult
            handler.postDelayed(this, 500)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        GarminLink.init(this)
        density = resources.displayMetrics.density
        config = DesignConfig.load(this)

        val pad = dp(16)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad, pad, 0)
        }

        // The preview stays on top while the settings scroll under it.
        preview = WatchPreviewView(this, config)
        root.addView(preview)
        statusView = TextView(this).apply {
            gravity = Gravity.CENTER
            textSize = 13f
            setPadding(0, dp(6), 0, dp(6))
        }
        root.addView(statusView)

        controls = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(ScrollView(this).apply { addView(controls) })
        buildControls()
        setContentView(root)
    }

    override fun onResume() {
        super.onResume()
        handler.post(refreshStatus)
    }

    override fun onPause() {
        handler.removeCallbacks(refreshStatus)
        super.onPause()
    }

    private fun buildControls() {
        controls.removeAllViews()

        section("כללי")
        colors("צבע רקע (כשהמסך ער)", DesignConfig.BACKGROUND, BACKGROUNDS)
        colors("צבע השעה", DesignConfig.TIME_COLOR, ACCENTS)
        toggle("הצג תאריך", DesignConfig.SHOW_DATE)
        colors("צבע התאריך", DesignConfig.DATE_COLOR, ACCENTS)

        section("מד שניות")
        toggle("הצג מד שניות מסביב", DesignConfig.SHOW_SECONDS)
        colors("צבע מד השניות", DesignConfig.SECONDS_COLOR, ACCENTS)

        section("דופק")
        toggle("הצג דופק", DesignConfig.SHOW_HEART)
        colors("צבע הדופק", DesignConfig.HEART_COLOR, ACCENTS)

        section("קשת שמאלית")
        choice("מה להציג", DesignConfig.LEFT_SOURCE)
        colors("צבע", DesignConfig.LEFT_COLOR, ACCENTS)

        section("קשת ימנית")
        choice("מה להציג", DesignConfig.RIGHT_SOURCE)
        colors("צבע", DesignConfig.RIGHT_COLOR, ACCENTS)
        toggle("צעדים בקיצור (6.2k)", DesignConfig.STEPS_IN_K)

        section("מוזיקה")
        colors("צבע שם השיר", DesignConfig.TITLE_COLOR, ACCENTS)
        toggle("הצג עמודות מוזיקה", DesignConfig.SHOW_BARS)
        colors("צבע העמודות", DesignConfig.BARS_COLOR, ACCENTS)
        toggle("הצג מד התקדמות", DesignConfig.SHOW_PROGRESS)
        colors("צבע מד ההתקדמות", DesignConfig.PROGRESS_COLOR, ACCENTS)

        section("")
        controls.addView(Button(this).apply {
            text = "שלח שוב את העיצוב לשעון"
            setOnClickListener { changed() }
        })
        controls.addView(Button(this).apply {
            text = "חזרה לעיצוב המקורי"
            setOnClickListener {
                config.reset()
                buildControls()
                changed()
            }
        })
        controls.addView(View(this), LinearLayout.LayoutParams(1, dp(32)))
    }

    /** Saves, redraws the preview, and sends to the watch once the taps stop. */
    private fun changed() {
        config.save(this)
        preview.invalidate()
        handler.removeCallbacks(sendToWatch)
        handler.postDelayed(sendToWatch, 600)
    }

    private fun section(title: String) {
        controls.addView(TextView(this).apply {
            text = title
            textSize = 18f
            setPadding(0, dp(20), 0, dp(4))
        })
    }

    private fun label(text: String) {
        controls.addView(TextView(this).apply {
            this.text = text
            textSize = 14f
            setPadding(0, dp(10), 0, dp(4))
        })
    }

    private fun toggle(text: String, key: String) {
        controls.addView(Switch(this).apply {
            this.text = text
            textSize = 15f
            isChecked = config.isOn(key)
            setPadding(0, dp(8), 0, dp(8))
            setOnCheckedChangeListener { _, checked ->
                config[key] = if (checked) 1 else 0
                changed()
            }
        })
    }

    private fun choice(text: String, key: String) {
        label(text)
        controls.addView(Spinner(this).apply {
            adapter = ArrayAdapter(this@DesignActivity, android.R.layout.simple_spinner_dropdown_item, SOURCES)
            setSelection(config[key].coerceIn(0, SOURCES.size - 1))
            onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                    if (config[key] == position) return
                    config[key] = position
                    changed()
                }

                override fun onNothingSelected(parent: AdapterView<*>?) = Unit
            }
        })
    }

    /** A row of round colour swatches; the chosen one gets a bright outline. */
    private fun colors(text: String, key: String, palette: IntArray) {
        label(text)
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        val swatches = mutableListOf<View>()
        fun paint() {
            for ((index, swatch) in swatches.withIndex()) {
                val selected = palette[index] == config[key]
                swatch.background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(palette[index] or (0xFF shl 24))
                    setStroke(dp(if (selected) 3 else 1), if (selected) Color.WHITE else Color.GRAY)
                }
            }
        }
        for (color in palette) {
            val swatch = View(this).apply {
                contentDescription = String.format("#%06X", color)
                setOnClickListener {
                    config[key] = color
                    paint()
                    changed()
                }
            }
            swatches.add(swatch)
            row.addView(swatch, LinearLayout.LayoutParams(dp(40), dp(40)).apply { marginEnd = dp(10) })
        }
        paint()
        controls.addView(HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
            addView(row)
        })
    }

    private fun dp(value: Int): Int = (value * density).toInt()

    private companion object {
        // Order must match the SOURCE_* numbers in DesignConfig.
        val SOURCES = listOf("ללא", "Body Battery", "צעדים", "סוללת השעון", "קומות", "דקות פעילות (שבועי)")

        val ACCENTS = intArrayOf(
            0xFFFFFF, 0xCFCFCF, 0xAAAAAA, 0xFF5C6C, 0xFF8A4D, 0xFFB84D, 0xFFE14D,
            0x2ED69A, 0x2EC4D6, 0x4DA3FF, 0xA78BFA, 0xFF7AC0,
        )
        val BACKGROUNDS = intArrayOf(0x000000, 0x101010, 0x0A1428, 0x08201A, 0x180F2A, 0x2A0E12, 0x241A08)
    }
}

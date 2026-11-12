package com.dor.nowplaying

import android.content.Context

/**
 * The watch face design chosen on the phone. Every setting is a small integer
 * (a colour as 0xRRGGBB, a switch as 0/1, a choice as an index) stored under a short key,
 * because that is what travels to the watch.
 *
 * Keys and defaults must match NowPlayingView.mc on the watch.
 */
class DesignConfig private constructor(private val values: MutableMap<String, Int>) {

    operator fun get(key: String): Int = values[key] ?: DEFAULTS.getValue(key)

    operator fun set(key: String, value: Int) {
        values[key] = value
    }

    fun isOn(key: String): Boolean = get(key) != 0

    /** Message for the watch: all settings plus the marker "c" that tells it this is a design. */
    fun toMessage(): Map<String, Any> = DEFAULTS.keys.associateWith<String, Any> { get(it) } + ("c" to 1)

    fun save(context: Context) {
        val editor = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        for (key in DEFAULTS.keys) editor.putInt(key, get(key))
        editor.apply()
    }

    fun reset() {
        values.clear()
    }

    companion object {
        private const val PREFS = "design"

        // Arc sources (what a gauge and the number next to it show).
        const val SOURCE_NONE = 0
        const val SOURCE_BODY_BATTERY = 1
        const val SOURCE_STEPS = 2
        const val SOURCE_WATCH_BATTERY = 3
        const val SOURCE_FLOORS = 4
        const val SOURCE_ACTIVE_MINUTES = 5

        const val BACKGROUND = "bg"
        const val TIME_COLOR = "tc"
        const val SHOW_DATE = "dt"
        const val DATE_COLOR = "dc"
        const val SHOW_HEART = "hr"
        const val HEART_COLOR = "hc"
        const val LEFT_SOURCE = "la"
        const val LEFT_COLOR = "lc"
        const val RIGHT_SOURCE = "ra"
        const val RIGHT_COLOR = "rc"
        const val STEPS_IN_K = "sk"
        const val SHOW_SECONDS = "se"
        const val SECONDS_COLOR = "sc"
        const val SHOW_BARS = "mb"
        const val BARS_COLOR = "mc"
        const val SHOW_PROGRESS = "pb"
        const val PROGRESS_COLOR = "pc"
        const val TITLE_COLOR = "st"

        val DEFAULTS: Map<String, Int> = linkedMapOf(
            BACKGROUND to 0x000000,
            TIME_COLOR to 0xFFFFFF,
            SHOW_DATE to 1,
            DATE_COLOR to 0xAAAAAA,
            SHOW_HEART to 1,
            HEART_COLOR to 0xFF5C6C,
            LEFT_SOURCE to SOURCE_BODY_BATTERY,
            LEFT_COLOR to 0x4DA3FF,
            RIGHT_SOURCE to SOURCE_STEPS,
            RIGHT_COLOR to 0x2ED69A,
            STEPS_IN_K to 1,
            SHOW_SECONDS to 1,
            SECONDS_COLOR to 0xCFCFCF,
            SHOW_BARS to 1,
            BARS_COLOR to 0x2ED69A,
            SHOW_PROGRESS to 1,
            PROGRESS_COLOR to 0xCFCFCF,
            TITLE_COLOR to 0xFFFFFF,
        )

        fun load(context: Context): DesignConfig {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val values = mutableMapOf<String, Int>()
            for ((key, default) in DEFAULTS) {
                if (prefs.contains(key)) values[key] = prefs.getInt(key, default)
            }
            return DesignConfig(values)
        }

        /** A design with nothing customised; used by tests. */
        fun defaults(): DesignConfig = DesignConfig(mutableMapOf())
    }
}

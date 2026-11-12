package com.dor.nowplaying

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DesignConfigTest {

    @Test
    fun messageCarriesEverySettingAndTheDesignMarker() {
        val message = DesignConfig.defaults().toMessage()
        assertEquals(1, message["c"])
        assertEquals(DesignConfig.DEFAULTS.size + 1, message.size)
        assertTrue(message.values.all { it is Int })
    }

    @Test
    fun changedValuesReplaceDefaultsAndResetRestoresThem() {
        val config = DesignConfig.defaults()
        config[DesignConfig.BACKGROUND] = 0x0A1428
        config[DesignConfig.SHOW_SECONDS] = 0
        assertEquals(0x0A1428, config.toMessage()[DesignConfig.BACKGROUND])
        assertEquals(false, config.isOn(DesignConfig.SHOW_SECONDS))
        config.reset()
        assertEquals(0x000000, config[DesignConfig.BACKGROUND])
        assertEquals(true, config.isOn(DesignConfig.SHOW_SECONDS))
    }

    @Test
    fun designMessageCannotBeMistakenForASong() {
        // The watch tells the two apart by the "c" key; a song message never has it.
        val song = TrackState("Song", "Artist", PlayState.PLAYING).toMessage(1794300000L)
        assertEquals(false, song.containsKey("c"))
    }
}

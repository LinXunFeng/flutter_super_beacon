package com.lxf.super_beacon

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

internal class BeaconCooldownTest {
    @Test
    fun suppressesEventsInsideConfiguredWindow() {
        assertTrue(isWithinCooldown(1_000L, 10_999L, 10_000L))
        assertFalse(isWithinCooldown(1_000L, 11_000L, 10_000L))
        assertFalse(isWithinCooldown(0L, 1_000L, 10_000L))
    }
}

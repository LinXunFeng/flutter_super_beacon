package com.lxf.super_beacon

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

internal class IBeaconParserTest {
    @Test
    fun parseManufacturerData_returnsBeaconFields() {
        val data = byteArrayOf(
            0x02,
            0x15,
            0x00,
            0x11,
            0x22,
            0x33,
            0x44,
            0x55,
            0x66,
            0x77,
            0x88.toByte(),
            0x99.toByte(),
            0xAA.toByte(),
            0xBB.toByte(),
            0xCC.toByte(),
            0xDD.toByte(),
            0xEE.toByte(),
            0xFF.toByte(),
            0x00,
            0x0C,
            0x00,
            0x22,
            0xC5.toByte(),
        )

        val beacon = assertNotNull(IBeaconParser.parseManufacturerData(data, 0x1234))

        assertEquals("00112233-4455-6677-8899-AABBCCDDEEFF", beacon.uuid)
        assertEquals(12, beacon.major)
        assertEquals(34, beacon.minor)
        assertEquals(-59, beacon.txPower)
        assertEquals(0x1234, beacon.manufacturerId)
        assertEquals(data.map { it.toInt() and 0xFF }, beacon.manufacturerBytes)
        assertEquals(
            "021500112233445566778899AABBCCDDEEFF000C0022C5",
            beacon.manufacturerHex,
        )
    }
}

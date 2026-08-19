package com.lxf.super_beacon

import java.util.Locale

/** Parsed fields and original bytes from one iBeacon manufacturer payload. */
public data class ParsedBeacon(
    val uuid: String,
    val major: Int,
    val minor: Int,
    val txPower: Int,
    val manufacturerId: Int,
    val manufacturerBytes: List<Int>,
    val manufacturerHex: String,
)

/** Decoder for the standard iBeacon manufacturer-data layout. */
public object IBeaconParser {
    /**
     * Parses [data] when it contains the iBeacon 0x02/0x15 prefix and all
     * required UUID, major, minor, and transmit-power bytes.
     *
     * @return null for missing, truncated, or non-iBeacon data.
     */
    @JvmStatic
    public fun parseManufacturerData(
        data: ByteArray?,
        manufacturerId: Int = 0x004C,
    ): ParsedBeacon? {
        if (data == null || data.size < 23) return null
        if (data[0] != 0x02.toByte() || data[1] != 0x15.toByte()) return null
        val hex = data.copyOfRange(2, 18).joinToString("") {
            "%02X".format(Locale.US, it.toInt() and 0xFF)
        }
        val uuid = "${hex.substring(0, 8)}-${hex.substring(8, 12)}-" +
            "${hex.substring(12, 16)}-${hex.substring(16, 20)}-" +
            hex.substring(20, 32)
        val major = unsignedShort(data[18], data[19])
        val minor = unsignedShort(data[20], data[21])
        return ParsedBeacon(
            uuid = uuid,
            major = major,
            minor = minor,
            txPower = data[22].toInt(),
            manufacturerId = manufacturerId,
            manufacturerBytes = data.map { it.toInt() and 0xFF },
            manufacturerHex = data.toHex(),
        )
    }

    private fun unsignedShort(high: Byte, low: Byte): Int =
        ((high.toInt() and 0xFF) shl 8) or (low.toInt() and 0xFF)
}

internal fun ByteArray.toHex(): String = joinToString("") {
    "%02X".format(Locale.US, it.toInt() and 0xFF)
}

import binary show BIG_ENDIAN
import serial
import serial.protocols.i2c as i2c
import gpio

/// Driver for Si7006-A20 I2C Humidity and Temperature Sensor


/**
Driver for Si7006-A20 I2C Humidity and Temperature Sensor

Example of use:
```
main:
  sda := gpio.Pin 17
  scl := gpio.Pin 16
  bus := i2c.Bus --sda=sda --scl=scl --frequency = 100_000
  sensor_device := bus.device Si7006A20.I2C_ADDRESS
  driver := Si7006A20 sensor_device
  print "Firmware: $driver.firmware"
  print "Serial#: $(%016x driver.serial_number)"
  print "Temperature: $(driver.read_temperature)C"
  print "Humidity: $(driver.read_humidity)%"
```
*/
class Si7006A20:
  device_ /i2c.Device
  static I2C_ADDRESS ::= 0x40

  constructor .device_:

  static FIRMWARE_VERSIONS_ ::= {
    0xff: "Version 1.0",
    0x20: "Version 2.0",
  }

  static POLYNOMIAL_ ::= 0b0011_0001  // x**8 + x**5 + x**4 + 1.

  /// A string describing the firmware version on the sensor.
  firmware -> string:
    // Here and for the serial_number we can't use registers_.read_bytes
    // because that assumes a 1-byte register number, but we have a two-byte
    // register number. Instead simply write the two register bytes and then
    // read a byte of data.
    device_.write #[0x84, 0xb8]
    bytes := device_.read 1
    code := bytes[0]
    return FIRMWARE_VERSIONS_[code] --if_absent:
      "Unknown firmware version: $(%02x code)"

  /**
  A 64 bit serial number for the sensor.  It is an error if the sensor has a
    serial number that indicates it is not an Si7006 sensor.
  */
  serial_number -> int:
    // See comment in the firmware method.
    device_.write #[0xfa, 0x0f]
    bytes1 := device_.read 8
    device_.write #[0xfc, 0xc9]
    bytes2 := device_.read 6
    check_crc_ bytes1 [0] 1
    check_crc_ bytes1 [0, 2] 3
    check_crc_ bytes1 [0, 2, 4] 5
    check_crc_ bytes1 [0, 2, 4, 6] 7
    check_crc_ bytes2 [0, 1] 2
    check_crc_ bytes2 [0, 1, 3, 4] 5
    model := bytes2[0]
    // 00 and 0xff are engineering samples.  Normally we expect this byte of the
    // serial number to be 6.
    if model != 0 and model != 0xff and model != 6: throw "Not a 7006 device"
    return bytes1[0] << 56
         | bytes1[2] << 48
         | bytes1[4] << 40
         | bytes1[6] << 32
         | bytes2[0] << 24
         | bytes2[1] << 16
         | bytes2[3] << 8
         | bytes2[4]

  static check_crc_ bytes/ByteArray offsets/List expected/int:
    ba := ByteArray offsets.size: bytes[offsets[it]]
    calculated := crc_8_ ba POLYNOMIAL_
    if calculated != bytes[expected]: throw "CRC error"

  get_measurement_ reg/int -> int:
    // The device nacks read attempts when the measurement is not
    // ready. This is not compatible with registers_.read_bytes,
    // so we use write and read instead.  Since we don't really
    // know how long it will take, we do exponential backoff until
    // we get a result.
    device_.write #[reg]
    time := 1
    while true:
      sleep --ms=time - 1
      catch:
        bytes := device_.read 3
        check_crc_ bytes [0, 1] 2
        return BIG_ENDIAN.uint16 bytes 0
      time *= 2

  /// The current temperature of the sensor in degrees Celcius
  read_temperature -> float:
    code := get_measurement_ 0xf3
    return ((175.72 * code) / 65536.0) - 46.85

  /// The current relative humidity measured by the sensor in percent.
  read_humidity -> float:
    code := get_measurement_ 0xf5
    return ((125.0 * code) / 65536.0) - 6.0

  /// Currently does nothing.
  on -> none:

  /// Currently does nothing.
  off -> none:

crc_8_ input/ByteArray polynomial/int --initial/int=0 -> int:
  result := initial
  input.do:
    result ^= it
    8.repeat:
      if result & 0x80 != 0:
        result = (result << 1) ^ polynomial
      else:
        result <<= 1
    result &= 0xff
  return result

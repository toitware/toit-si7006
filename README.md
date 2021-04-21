# SI7006

A low level driver for the Si7006-A20 sensor.

This sensor is a combined temperature and humidity sensor.

Documentation is available at
* [data sheet][datasheet]

## Usage
A simple usage example.

``` toit
import fixed_point show *
import gpio
import serial.protocols.i2c as i2c
import si7006 show *

main:
  sda := gpio.Pin 17
  scl := gpio.Pin 16
  bus := i2c.Bus --sda=sda --scl=scl --frequency=100_000
  sensor_device := bus.device Si7006A20.I2C_ADDRESS
  driver := Si7006A20 sensor_device
  print "Firmware: $driver.firmware"
  print "Serial#: $(%016x driver.serial_number)"
  print "Temperature: $(FixedPoint --decimals=1 driver.temperature)C"
  print "Humidity: $(FixedPoint --decimals=1 driver.humidity)%"
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[datasheet]: https://www.silabs.com/documents/public/data-sheets/Si7006-A20.pdf
[tracker]: https://github.com/toitware/toit-si7006/issues

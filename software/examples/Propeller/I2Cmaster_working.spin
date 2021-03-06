{{ I2C Master Driver

Michael Shimniok http://www.bot-thoughts.com

Start: pull SDA low while SCL floating high
Stop: float SCL high while SDA pulled low
Addr: MSB first, 7 bit + R/!W, read ack at 9th clock, data valid on rising edge of SCL
Write: MSB first, 8 bit, read ack at 9th clock, data valid on rising edge of SCL
Read: MSB first, 8 bit, read data on rising SCL, send ack on 9th clock
 
}}
CON
  _clkmode      = xtal1 + pll16x
  _xinfreq      = 5_000_000
  _stack        = 50
  
  scl = 16
  sda = 17

PUB TestIt
  outa[scl]~                    ' SCL low
  outa[sda]~                    ' SDA low                                      
  dira[scl]~                    ' float SCL high
  dira[sda]~                    ' float SDA high
  waitcnt(clkfreq/1 + cnt)
  
  repeat
    Start
    Write(($26<<1)|1)
    Read
    Stop
    waitcnt(clkfreq/1000 + cnt)
    Start
    Write($26<<1)
    Write($42)
    Stop        
    waitcnt(clkfreq/1000 + cnt)
    Start
    Write($26<<1)
    Write($42)
    Start
    Write(($26<<1)|1)
    Read
    Stop        
    waitcnt(clkfreq/1000 + cnt)

PUB Start
  dira[scl]~                    ' float scl high
  dira[sda]~                    ' float sda high
  dira[sda]~~                   ' pull sda low
  dira[scl]~~                   ' pull scl low
   
PUB Stop
  dira[scl]~~                   ' pull scl low
  dira[sda]~~                   ' pull sda low
  dira[scl]~                    ' float scl high
  dira[sda]~                    ' float sda high
   
PUB Write(data):ack
  data <<= 24                   ' shift 8-bit value to MSbyte
  repeat 8
    dira[sda] := ((data<-=1)&1)^1 ' shift out data msb first
    dira[scl]~                  ' float scl high
    dira[scl]~~                 ' pull scl low
  ' ack/nack
  dira[sda]~                    ' float sda high
  dira[scl]~                    ' float scl high
  ack := ina[sda]               ' check ack/nack
  dira[scl]~~                   ' pull scl low
   
PUB Read:value|bit
  dira[sda]~                    ' float sda high
  repeat 8
    dira[scl]~                  ' float scl high
    value<<=1                   ' make room for next bit
    value |= ina[sda]           ' get bit
    dira[scl]~~                 ' pull scl low
  ' ack
  dira[sda]~~                   ' pull sda low 
  dira[scl]~                    ' float scl high
  dira[scl]~~                   ' pull scl low
     
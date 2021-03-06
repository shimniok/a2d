{{
  Title:
    I2C Master
   
  Author:
    Michael Shimniok   http://www.bot-thoughts.com     
   
  Version:
    1.0                         Initial Release
   
  Revision History:
    1.0         08/05/2013      Initial Release    
   
  Object Description:
    A "proper" I²C single master driver written in PASM that correctly
    respects open-drain bus design, clock-stretching, runs at normal (100kHz)
    and fast (400kHz) speeds, gives the author full control over every I²C
    operation, supports any two pins for sda, scl, specified once at init time.
    Requires pull-ups like any correct I²C implementation.
    
  Details:
        Learn about I²C here: http://www.i2c-bus.org/
         
        What do you mean, "proper"?
        ───────────────────────────
        By "proper" I mean honoring the I²C protocol:
         
            The object does not drive the lines
                       http://www.i2c-bus.org/how-i2c-hardware-works/
         
            It supports normal 100kHz and fast mode 400kHz, typical I²C speeds
                       http://www.i2c-bus.org/fastmode/
         
            it honors clock stretching by the slave
                       http://www.i2c-bus.org/clock-stretching/)
         
        You only have to specify sda and scl once. Any two unique pins can
        be used for sda and scl (e.g., 0 and 25)
         
        Quick Start
        ───────────
        init(sda, scl, speed)         Initializes the object/cog
              sda                     Pin number of the SDA line, 0..31
              scl                     Pin number of the SCL line, 0..31
              speed                   Bus speed. 100_000 or 400_000.                   
        FAST                          Returns 400_000
        NORMAL                        Returns 100_000
        start                         Creates start condition on the bus
        stop                          Creates stop condition on the bus
        write(data):ack_recvd         Writes a byte to the bus
              data                    The byte to write
              ack_recvd               Returns 1 if the slave acknowledged, 0 otherwise
        read(send_ack):result         Reads a byte from the bus
              send_ack                Sends an ack if 1, nack if 0
              result                  Returns the data read from the bus
         
        Addressing
        ──────────
        I²C uses 7-bit addressing. After sending a Start, the master transmits
        the 7 bits of the slave address it is trying to reach, then sends a bit
        to indicate whether data will be read or written. It sends a 1 to indicate
        read and 0 for write. When you use Write() to send the slave address, take
        the 7-bit address, left shift 1 for the write address, and add 1 to that for
        the read address. E.g., $26 is the 7-bit address, $4c is the write address
        and $4d is the read address.  
         
        Hardware
        ────────
        I²C devices use open drain sda and scl lines meaning they can either drive the
        line low or leave the line floating, to be pulled high by a pull-up resistor.
        This is a cornerstone of the protocol that enables bus sharing between many
        devices (127) and even multiple masters with ingenious arbitration, as well as
        an equally ingenious 'slow down' signal from the slave, called clock stretching.
         
        So, you'll need pull-up resistors, ~10k for 100kHz and ~2.2k for 400kHz. You
        could use less if rise time is too slow but be careful of sink current limits.
         
            Vcc  Vcc
         ───┐    
         sda├──┻──┼──
         scl├─────┻──
         ───┘
         
        Level Shifting
        ──────────────
        As we all know the Propeller runs at 3.3V. To safely interact with a 5V device
        you can attach your pull-ups to 3.3V which should still be recognized as logic
        high by most devices (check datasheet for Vhi threshold value and be careful
        about long wire). This works so long as the slave devices don't have their own
        pull-ups tied to their 5V rails. You could use a purpose-built I²C level shifter
        IC (or breakout board).
         
        More info: http://ics.nxp.com/support/documents/interface/pdf/an97055.pdf   
         
        Also, you supply scl/sda pins once when initializing. That means that, yes,
        you'll need a cog for every I²C bus you have, but you can place 127 devices
        on the same bus, so who cares?
         
        Additionally the object runs at a near perfect 100kHz when Prop is running
        at 80MHz. It can also run at a near perfect 400kHz. These are standard I²C
        speeds.
         
        Downsides
        ─────────
        Because of slow hub memory access, there are big 50usec pauses between each I²C
        operation. But that's going to be true of any spin/asm mixed code. For sake of
        reference, a typical hardware peripheral on an ATmega or ARM does not pause
        between I²C operations and so throughput will be considerably better. Oh well.
         
        I²C Protocol
        ────────────
        The I²C protocol consists of four basic building blocks:
        Start: pull SDA low while SCL floating high
        Stop: float SCL high while SDA pulled low
        Write: MSB first, 8 bit, read ack at 9th clock, data valid on rising edge of SCL
        Read: MSB first, 8 bit, read data on rising SCL, send ack on 9th clock
         
        I²C is a synchronous serial protocol which simply means that there's a clock
        that tells the slave when to read or write data. Data is read/written on the
        rising edge of SCL:
         
        SDA 
        SCL 
         
        After sending a Start, the master writes the 7-bit address of the slave with
        which it is intending to interact along with a Read/!Write bit, 1 for read,
        0 for write. Next it either writes data or reads data. For writing, calls to
        Write are used and the slave indicates acknowledgement at the 9th rising edge
        of scl after the byte has been sent. For reading, calls to Read are used. The
        master sends an acknowledgement to indicate more data is coming. The master
        sends the ack for all but the last byte. The communication is ended and bus
        released when the master sends a Stop.

        It is also possible for the master to send a repeated Start, used by the master
        to retain control of the bus so that it can write and then immediately read
        data. It's simply a matter of sending another Start after performing the final
        write operation.

        More info here: http://www.i2c-bus.org/repeated-start-condition/
         
}}
CON
  _clkmode      = xtal1 + pll16x
  _xinfreq      = 5_000_000
  _stack        = 50

  NORMAL_MODE   = 100_000
  FAST_MODE     = 400_000

  CMD_START     = 1
  CMD_STOP      = 2
  CMD_WRITE     = 3
  CMD_READ      = 4
  CMD_INIT      = 5

' I²C clock delay time, hand tuned assuming 5MHz crystal
  DELAY_400K    = 21  ' ~400kHz
  DELAY_100K    = 171 ' ~100kHz

VAR
  long param
  
DAT
  cognum long 0

PUB TestIt | val
{{
 Example / test code. Also, if you compile this object standalone, this
 code tests some basic I²C functionality that you can then view with a logic
 analyzer. You can tweak the code and test out various I²C devices.
}}

  Init(16, 17, Normal)
  'Init(16, 17, Fast)
  
  'waitcnt(clkfreq/1 + cnt)

  repeat
    Start                       ' Read two bytes from $26
    if (Write(($26<<1)|1))      ' check ACK
      val := Read(1)            ' Read a 16-byte value, MSbyte first
      val <<= 8
      val |= Read(0)
    Stop
    waitcnt(clkfreq/50 + cnt)

  repeat
    Start                       ' Write value 7 to register 0 
    Write(($26<<1)|1)
    Write(0)
    Write(7)
    Stop

  repeat
    Start                       ' Read one byte from register 3*
    Write($26<<1)               
    Write(3)                    ' Tell the slave what register to use
    Start                       ' Send re-start and read one byte
    Write(($26<<1)|1)
    Read(0)
    Stop        

' * This isn't always how one reads from a particular register. It really depends
'   on the device. But usually the datasheet will clearly spell out the protocol
'   and tell you what all the register are, too.

PUB FAST
{{
 Returns value for fast bus frequency, 400_000 for use with init 
}}
  result := FAST_MODE

PUB NORMAL
{{
 Returns value for normal bus frequency, 100_000 for use with init 
}}
  result := NORMAL_MODE

PUB init(mysda, myscl, myspeed)|fastMode
{{
 Initializes the object.
 mysda   - sda pin number
 myscl   - scl pin number
 myspeed - bus speed, NORMAL_MODE (100_000) or FAST_MODE (400_000)
}}
  if (myspeed == FAST_MODE)
    fastMode := 1
  else
    fastMode := 0
    
  param := CMD_INIT|((myscl & $01f)<<8)|((mysda & $01f)<<16)|(fastMode<<24)

  ifnot (cognum)
    cognum := cognew(@i2crun, @param)
  repeat while (param & $00ff)
  
PUB start
{{
 Send start condition on the bus
}}
  param := CMD_START
  repeat while (param & $00ff)
   
PUB stop
{{
 Send stop condition on the bus
}}
  param := CMD_STOP
  repeat while (param & $00ff)
     
PUB write(mydata):ack_recvd
{{
 Write data to the bus
 mydata -- the 8-bit data to send
 returns -- ack status, 1 if ack received, 0 otherwise
}}
  param := CMD_WRITE|((mydata&$00ff)<<8)
  repeat while (param & $00ff)
  ack_recvd := ((param>>8) & $00ff) ' peel off the lsbyte
   
PUB read(send_ack)
{{
 Read data from the bus
 send_ack -- if 1, an ack is sent by the master, no ack if 0
 returns -- value read from the bus
}}
  param := CMD_READ|((send_ack & $01)<<8)
  repeat while (param & $00ff)
  result := ((param>>8) & $00ff) ' peel off byte 1

DAT 
              org
i2crun        

{{
____________
PASM cmdloop

 Commands and parameters are passed through the cmd 4-byte (32-bit) hub variable
 to improve efficiency.  They are packed with the command in byte 0, p0 in byte 1,
 p1 in byte 2, p3 in byte 3.  When the command is done running, it sets byte 0 of
 the hub parameter to 0 and byte 1 to the return value.
}}
cmdloop       mov ptr, PAR
              rdlong arg, ptr                   ' read packed command
              test arg, #$00ff wz               ' test lsbyte                            
        if_z  jmp cmdloop
        
{{
_____________
PASM whichcmd

 Calls the correct function based on the command passed into arg byte 0
}}
whichcmd      mov retval, #0                    ' clear out return value
              mov cmd, arg                      ' get the command, byte 0
              and cmd, #$00ff                   ' pull out byte
              cmp cmd, #CMD_READ wz
        if_e  jmp #read_byte
              cmp cmd, #CMD_WRITE wz          
        if_e  jmp #write_byte
              cmp cmd, #CMD_START wz          
        if_e  jmp #send_start
              cmp cmd, #CMD_STOP wz          
        if_e  jmp #send_stop
              cmp cmd, #CMD_INIT wz
        if_e  jmp #do_init

done          and retval, #$00ff                ' 1-byte return
              shl retval, #8                    ' move retval into place
              wrlong retval, ptr                ' to tell calling method we're done
              jmp #cmdloop
{{
_______________
PASM send_start

 Sets a start condition on the bus
}}
send_start    andn dira, sda_mask               ' float sda high 
              call #delay
              andn dira, scl_mask               ' float scl high
              waitpeq scl_mask, scl_mask        ' honor clock stretching
              call #delay
              or dira, sda_mask                 ' pull sda low 
              call #delay
              or dira, scl_mask                 ' pull scl low 
              call #delay
              jmp #done
              
{{
______________
PASM send_stop

 Sets a stop condition on the bus
}}
send_stop     or dira, scl_mask                 ' pull scl low 
              call #delay
              or dira, sda_mask                 ' pull sda low 
              call #delay
              andn dira, scl_mask               ' float scl high
              waitpeq scl_mask, scl_mask        ' honor clock stretching
              call #delay
              andn dira, sda_mask               ' float sda high 
              call #delay
              jmp #done

{{
______________
PASM read_byte

 Reads a single byte from the bus and if ack == 1, sends ack, else nack
 The master sends an ACK for each data byte read *except* the last byte to
 let the slave know it's done. The data byte read is returned in retval
 back to spin
}}
              
read_byte     mov ack, arg                      ' get ack, byte 1
              shr ack, #8                       ' shift into place
              and ack, #$00ff                   ' pull out byte
              mov data, #0                      ' clear data
              ' loop 8 bits
              mov i, #8                         ' read 8 bits
rdloop        andn dira, scl_mask               ' float scl high
              waitpeq scl_mask, scl_mask        ' honor clock stretching
              call #delay
              call #delay
              test sda_mask, ina wz             ' check sda (ina must be src!)
        if_nz or data, #1                       ' set bit of data
              shl data, #1                      ' make room for next bit
              or dira, scl_mask                 ' pull scl low
              call #delay
              call #delay
              ' send ack (or don't)
              djnz i, #rdloop             
              cmp ack, #0 wz                    ' if send_ack == true
        if_ne or dira, sda_mask                 ' pull sda low to send ACK
              call #delay
              andn dira, scl_mask               ' float scl high
              waitpeq scl_mask, scl_mask        ' honor clock stretching
              call #delay
              call #delay
              or dira, scl_mask                 ' pull scl low
              call #delay
              call #delay
              andn dira, sda_mask               ' float sda high
              mov retval, data                  ' return data
              jmp #done

{{
_______________
PASM write_byte

 Writes a single byte to the bus. After start is sent, the master sends the
 address (shifted left 1 bit with lsb set to 1 if read, 0 if write) byte.
 Additional writes may follow. For every write (address or otherwise) the
 slave indicates ack by pulling sda low after the 8th byte in time for the
 9th rising scl edge. This value is returned in retval back to spin
}}

write_byte    mov data, arg                     ' unpack data, byte 1
              shr data, #8                      ' shift into place
              and data, #$00ff                  ' pull out byte                   
              ' loop 8 bits
              mov i, #8                         ' send 8 bits                         
wrloop        test data, #%1000_0000 wz         ' test MSB
        if_z  or dira, sda_mask                 ' bit is zero, pull sda low
        if_nz andn dira, sda_mask               ' bit is high, float sda high
              call #delay
              andn dira, scl_mask               ' float scl high
              waitpeq scl_mask, scl_mask        ' honor clock stretching
              call #delay
              call #delay
              or dira, scl_mask                 ' pull scl low
              call #delay
              shl data, #1                      ' shift in next bit
              djnz i, #wrloop                   ' decrement i, loop if > 0         
              ' get ack
              andn dira, sda_mask               ' float sda high
              call #delay
              andn dira, scl_mask               ' float scl high
              waitpeq scl_mask, scl_mask        ' honor clock stretching
              call #delay
              call #delay
              test sda_mask, ina wz             ' check sda for ack/nack
        if_z  mov got_ack, #1                   ' ack received
        if_nz mov got_ack, #0                   ' nack
              or dira, scl_mask                 ' pull scl low
              call #delay
              call #delay
              mov retval, got_ack               ' return ack result
              jmp #done

{{
____________
PASM do_init

 Reads in the scl and sda parameters, packed into bytes 1 and 2, respectively.
 Once it figures out the mask for scl and sda it sets both outa to 0 and dira
 to 0 so that they are both pulled high due to the I²C pull-up resistors.
}}
do_init       mov scl, arg                      ' unpack scl, byte 1
              shr scl, #8                       ' shift into place
              and scl, #$001f                   ' pull out byte 0 (scl)
              mov scl_mask, #1
              shl scl_mask, #16                 ' scl_mask := (1<<scl)
              andn dira, scl_mask               ' float sda high
              andn outa, scl_mask               ' set scl low for pull down  

              mov sda, arg                      ' unpack sda, byte 2
              shr sda, #16                      ' shift into place
              and scl, #$001f                   ' pull out byte 0 (scl)
              mov sda_mask, #1
              shl sda_mask, #17                 ' sda_mask := (1<<sda)
              andn dira, sda_mask               ' float sda high
              andn outa, sda_mask               ' set sda low for pull down

              mov delay_count, arg              ' unpack speed, byte 3
              shr delay_count, #24              ' shift into place
              test delay_count, #$01 wz         ' test bit (true/false)
        if_z  mov delay_count, #DELAY_100K      ' set delay to 100kHz
        if_nz mov delay_count, #DELAY_400K      ' set delay to 400kHz
              jmp #done

{{
__________
PASM delay

 Delay is a loop that delays for a period of time to approximate SCL frequency
 of 100kHz or 400kHz
}}              
delay         mov dcount, cnt
              add dcount, delay_count
              waitcnt dcount, #0
delay_ret     ret

ptr           res       1       ' ptr to input parameters
arg           res       1       ' command, and parameters, packed into 4 bytes
cmd           res       1       ' command to run 
data          res       1       ' data to be written or read
ack           res       1       ' boolean, send ack?
got_ack       res       1       ' boolean, received ack?
scl           res       1       ' pin number for scl
sda           res       1       ' pin number for sda 
retval        res       1       ' return value
scl_mask      res       1       ' mask for scl
sda_mask      res       1       ' mask for sda
dcount        res       1       ' delay counter
delay_count   res       1       ' delay to achieve 100kHz/400kHz speeds   
i             res       1       ' index / counter

{{

Copyright(c) 2013 - Michael Shimniok

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be included in all copies
or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

}}

{trim,strip,katch,bufeq_fast,uint_to_buffer} = require './util'

#=========================================================================

make_line = (x = "") -> "#{x}\n"

#=========================================================================

exports.Encoder = class Encoder

  constructor : (@C) -> 

  #------

  frame : (t) ->
    dash = ("-" for i in [0...5]).join('')
    return {
      begin : make_line(dash + "BEGIN PGP #{t}" + dash)
      end : make_line(dash + "END PGP #{t}" + dash)
    }

  #------

  b64e : (d) ->
    raw = d.toString 'base64'
    w = 64
    parts = for i in [0...raw.length] by w
      end = Math.min(i+w,raw.length)
      raw[i...end]
    make_line parts.join("\n")

  #------

  header : () ->
    (make_line(x) for x in [ 
      "Version: #{@C.header.version}",
      "Comment: #{@C.header.comment}"
    ]).join ''

  #------

  encode : (type, data) ->
    f = @frame type
    f.begin.concat(@header(), make_line(), @b64e(data), formatCheckSum(data), f.end)

#=========================================================================

#
# Make a clearsign header for the first part of the clearsign message.
#
# @param {Object} C the constants object
# @param {String} data the message data, should end with a newline
# @param {String} hasher_name the name of the hash function used for the signature (e.g. 'SHA512')
# @return {String} the framed message
exports.clearsign_header = clearsign = (C, data, hasher_name) ->
  enc = new Encoder C
  f = enc.frame("SIGNED MESSAGE").begin
  f.concat(make_line("Hash: #{hasher_name}"), make_line(), data)

#=========================================================================

exports.encode = encode = (C, type, data) -> (new Encoder C).encode(type, data)

#=========================================================================

#
# Internal function to calculate a CRC-24 checksum over a given string (data)
# @param {Buffer} data Data to create a CRC-24 checksum for
# @return {Integer} The CRC-24 checksum as number
# 
crc_table = [
  0x00000000, 0x00864cfb, 0x018ad50d, 0x010c99f6, 0x0393e6e1, 0x0315aa1a, 0x021933ec, 
  0x029f7f17, 0x07a18139, 0x0727cdc2, 0x062b5434, 0x06ad18cf, 0x043267d8, 0x04b42b23, 
  0x05b8b2d5, 0x053efe2e, 0x0fc54e89, 0x0f430272, 0x0e4f9b84, 0x0ec9d77f, 0x0c56a868, 
  0x0cd0e493, 0x0ddc7d65, 0x0d5a319e, 0x0864cfb0, 0x08e2834b, 0x09ee1abd, 0x09685646, 
  0x0bf72951, 0x0b7165aa, 0x0a7dfc5c, 0x0afbb0a7, 0x1f0cd1e9, 0x1f8a9d12, 0x1e8604e4, 
  0x1e00481f, 0x1c9f3708, 0x1c197bf3, 0x1d15e205, 0x1d93aefe, 0x18ad50d0, 0x182b1c2b, 
  0x192785dd, 0x19a1c926, 0x1b3eb631, 0x1bb8faca, 0x1ab4633c, 0x1a322fc7, 0x10c99f60, 
  0x104fd39b, 0x11434a6d, 0x11c50696, 0x135a7981, 0x13dc357a, 0x12d0ac8c, 0x1256e077, 
  0x17681e59, 0x17ee52a2, 0x16e2cb54, 0x166487af, 0x14fbf8b8, 0x147db443, 0x15712db5, 
  0x15f7614e, 0x3e19a3d2, 0x3e9fef29, 0x3f9376df, 0x3f153a24, 0x3d8a4533, 0x3d0c09c8, 
  0x3c00903e, 0x3c86dcc5, 0x39b822eb, 0x393e6e10, 0x3832f7e6, 0x38b4bb1d, 0x3a2bc40a, 
  0x3aad88f1, 0x3ba11107, 0x3b275dfc, 0x31dced5b, 0x315aa1a0, 0x30563856, 0x30d074ad, 
  0x324f0bba, 0x32c94741, 0x33c5deb7, 0x3343924c, 0x367d6c62, 0x36fb2099, 0x37f7b96f, 
  0x3771f594, 0x35ee8a83, 0x3568c678, 0x34645f8e, 0x34e21375, 0x2115723b, 0x21933ec0, 
  0x209fa736, 0x2019ebcd, 0x228694da, 0x2200d821, 0x230c41d7, 0x238a0d2c, 0x26b4f302, 
  0x2632bff9, 0x273e260f, 0x27b86af4, 0x252715e3, 0x25a15918, 0x24adc0ee, 0x242b8c15, 
  0x2ed03cb2, 0x2e567049, 0x2f5ae9bf, 0x2fdca544, 0x2d43da53, 0x2dc596a8, 0x2cc90f5e, 
  0x2c4f43a5, 0x2971bd8b, 0x29f7f170, 0x28fb6886, 0x287d247d, 0x2ae25b6a, 0x2a641791, 
  0x2b688e67, 0x2beec29c, 0x7c3347a4, 0x7cb50b5f, 0x7db992a9, 0x7d3fde52, 0x7fa0a145, 
  0x7f26edbe, 0x7e2a7448, 0x7eac38b3, 0x7b92c69d, 0x7b148a66, 0x7a181390, 0x7a9e5f6b, 
  0x7801207c, 0x78876c87, 0x798bf571, 0x790db98a, 0x73f6092d, 0x737045d6, 0x727cdc20, 
  0x72fa90db, 0x7065efcc, 0x70e3a337, 0x71ef3ac1, 0x7169763a, 0x74578814, 0x74d1c4ef, 
  0x75dd5d19, 0x755b11e2, 0x77c46ef5, 0x7742220e, 0x764ebbf8, 0x76c8f703, 0x633f964d, 
  0x63b9dab6, 0x62b54340, 0x62330fbb, 0x60ac70ac, 0x602a3c57, 0x6126a5a1, 0x61a0e95a,
  0x649e1774, 0x64185b8f, 0x6514c279, 0x65928e82, 0x670df195, 0x678bbd6e, 0x66872498, 
  0x66016863, 0x6cfad8c4, 0x6c7c943f, 0x6d700dc9, 0x6df64132, 0x6f693e25, 0x6fef72de, 
  0x6ee3eb28, 0x6e65a7d3, 0x6b5b59fd, 0x6bdd1506, 0x6ad18cf0, 0x6a57c00b, 0x68c8bf1c, 
  0x684ef3e7, 0x69426a11, 0x69c426ea, 0x422ae476, 0x42aca88d, 0x43a0317b, 0x43267d80, 
  0x41b90297, 0x413f4e6c, 0x4033d79a, 0x40b59b61, 0x458b654f, 0x450d29b4, 0x4401b042, 
  0x4487fcb9, 0x461883ae, 0x469ecf55, 0x479256a3, 0x47141a58, 0x4defaaff, 0x4d69e604, 
  0x4c657ff2, 0x4ce33309, 0x4e7c4c1e, 0x4efa00e5, 0x4ff69913, 0x4f70d5e8, 0x4a4e2bc6, 
  0x4ac8673d, 0x4bc4fecb, 0x4b42b230, 0x49ddcd27, 0x495b81dc, 0x4857182a, 0x48d154d1, 
  0x5d26359f, 0x5da07964, 0x5cace092, 0x5c2aac69, 0x5eb5d37e, 0x5e339f85, 0x5f3f0673, 
  0x5fb94a88, 0x5a87b4a6, 0x5a01f85d, 0x5b0d61ab, 0x5b8b2d50, 0x59145247, 0x59921ebc, 
  0x589e874a, 0x5818cbb1, 0x52e37b16, 0x526537ed, 0x5369ae1b, 0x53efe2e0, 0x51709df7,
  0x51f6d10c, 0x50fa48fa, 0x507c0401, 0x5542fa2f, 0x55c4b6d4, 0x54c82f22, 0x544e63d9, 
  0x56d11cce, 0x56575035, 0x575bc9c3, 0x57dd8538
]

#-----

createcrc24 = (input) ->
  crc = 0xB704CE
  index = 0;

  while ((input.length - index) > 16)
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index +  0)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index +  1)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index +  2)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index +  3)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index +  4)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index +  5)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index +  6)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index +  7)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index +  8)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index +  9)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index + 10)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index + 11)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index + 12)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index + 13)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index + 14)) & 0xff]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index + 15)) & 0xff]
   index += 16

  for j in [index...input.length]
   crc = (crc << 8) ^ crc_table[((crc >> 16) ^ input.readUInt8(index++)) & 0xff]
  return crc & 0xffffff

#=========================================================================

#
# Calculates a checksum over the given data and returns it base64 encoded
# @param {Buffer} data Data to create a CRC-24 checksum for
# @return {Buffer} Base64 encoded checksum
#
getCheckSum = (data) ->
  c = createcrc24 data
  buf = uint_to_buffer 32, c
  buf[1...4].toString 'base64'

formatCheckSum = (data) ->
  make_line("=" + getCheckSum(data))

# Calculates the checksum over the given data and compares it with the 
# given base64 encoded checksum
# @param {String} data Data to create a CRC-24 checksum for
# @param {String} checksum Base64 encoded checksum
# @return {Boolean} True if the given checksum is correct; otherwise false
#
verifyCheckSum = (data, checksum) -> (getCheckSum(data) is checksum)

#=========================================================================

exports.Message = class Message 

  constructor : ({@body, @type, @comment, @version, @pre, @post}) ->
    @lines = []
    @fields = {}
    @payload = null

  unsplit : (lines) -> lines.join "\n"

  raw : -> @unsplit(@lines)

  finish_unframe : ({pre,post}) ->
    @pre = @unsplit(pre)
    @post = @unsplit(post)
    if @clearsign?
      @clearsign.body = @unsplit(@clearsign.lines)

  make_clearsign : () ->
    @clearsign = 
      headers : {}
      lines : []
      body : null

#=========================================================================

exports.Parser = class Parser

  constructor : (data) ->
    @init data

  init : (data) -> 
    @data = if Buffer.isBuffer data then data.toString('utf8') else data
    @lines = @data.split /\r?\n/
    @checksum = null
    @body = null
    @type = null
    @ret = null
    @last_type = null

  parse : () ->
    @ret = new Message {}
    @unframe()
    @pop_headers()
    @parse_type()
    @strip_empties_in_footer()
    @trim_lines()
    @find_checksum()
    @read_body()
    @check_checksum()
    @ret

  #-----

  # Subclasses can make this smarter.
  parse_type : () -> @ret.type = @ret.fields.type = @type

  #-----

  last_line : () -> @payload[-1...][0]

  #-----

  mparse : () ->
    out = []
    go = true
    while go
      @skip()
      if @lines.length
        obj = @parse()
        out.push obj
        @init obj.post
      else
        go = false
    out

  #-----

  skip : () ->
    while @lines.length
      if @lines[0].match /\S+/ then break
      @lines.shift()

  #-----

  read_body : () ->
    @ret.payload = @payload.join("\n")
    dat = @payload.join ''
    @ret.body = new Buffer dat, 'base64'

  #-----

  check_checksum : () ->
    @ret.fields.checksum = @checksum
    if @checksum? and not verifyCheckSum @ret.body, @checksum
      throw new Error "checksum mismatch"

  #-----

  pop_headers : () ->
    while @payload.length
      l = @payload.shift()
      if (m = l.match /Version: (.*)/) then @ret.version = m[1]
      else if (m = l.match /Comment: (.*)/)? then @ret.comment = m[1]
      else if (not l? or (l.length is 0) or (l.match /^\s+$/)) then break

  #-----

  strip_empties_in_footer : () ->
    @payload.pop() while @last_line()?.match(/^\s*$/)

  #-----

  trim_lines : () ->
    @payload = (trim(p) for p in @payload)

  #-----

  find_checksum : () ->
    @checksum = @payload.pop()[1...] if (l = @last_line())? and l[0] is '='

  #-----

  v_unframe : (pre) -> true

  #-----

  unframe : () ->
    rxx_b = /^(.*)(-{5}BEGIN PGP (.*?)-{5}.*$)/
    rxx_e = /^(.*-{5}END PGP (.*?)-{5})(.*)$/m
    rxx = rxx_b
    payload = []
    stage = 0
    type = null
    ret = null
    go = true
    pre = []
    post = []

    found_pre_std = (l, is_last) -> pre.push l
    found_pre_clearsign = (l, is_last) => @ret.clearsign.lines.push l

    found_pre = found_pre_std

    while @lines.length and go
      line = @lines.shift()
      switch stage
        when -1
          if (m = line.match /^([^:]+): (.*)$/)
            @ret.clearsign.headers[m[1].toLowerCase()] = m[2]
          else if line.length is 0
            stage++
            found_pre = found_pre_clearsign
          else
            throw new Error "Bad line in clearsign header"
          @ret.lines.push line
        when 0
          if (m = line.match rxx_b)?
            found_pre m[1], true
            @ret.lines.push (if @ret.clearsign then line else m[2]) 
            @type = m[3] unless @type?
            @last_type = m[3]
            if m[3] is "SIGNED MESSAGE"
              stage--
              @ret.make_clearsign()
            else
              stage++
          else
            @ret.lines.push line if @ret.clearsign
            found_pre line, false
        when 1
          if (m = line.match rxx_e)
            @ret.lines.push m[1]
            if m[2] isnt @last_type
              throw new Error "type mismatch -- begin #{@last_type} w/ end #{m[1]}"
            stage++
            post = [ m[3] ].concat @lines
            @lines = []
            go = false
          else
            @ret.lines.push line
            payload.push line
    if stage is 0 then throw new Error "no header found"
    else if stage is 1 then throw new Error "no tailer found"
    else
      @payload = payload
      @ret.finish_unframe { pre, post }

#=========================================================================

#
# Decode armor64-ed data, including header framing, checksums, etc.
#
# @param {String} data The data to decode. Alternatively, you can provide
#   a Buffer, and we'll output utf8 string out of it.
# @return {Array<{Error},{Buffer}>} And error or a buffer if success.
#
exports.decode = decode = (data) -> katch () -> (new Parser data).parse()
exports.mdecode = decode = (data) -> katch () -> (new Parser data).mparse()

#=========================================================================


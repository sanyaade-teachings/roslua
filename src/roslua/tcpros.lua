
----------------------------------------------------------------------------
--  tcpros.lua - Lua implementation of TCPROS protocol
--
--  Created: Sat Jul 24 14:02:06 2010 (at Intel Research, Pittsburgh)
--  Copyright  2010  Tim Niemueller [www.niemueller.de]
--
----------------------------------------------------------------------------

-- Licensed under BSD license

module(..., package.seeall)

-- hack for now
package.cpath = ";;/homes/timn/ros/local/roslua/src/roslua/?.so"

require("socket")
require("struct")

TcpRosConnection = { payload = nil, received = false }

function TcpRosConnection:new()
   local o = {}
   setmetatable(o, self)
   self.__index = self

   return o
end


function TcpRosConnection:connect(host, port)
   self.socket = socket.tcp()
   self.socket:connect(host, port)

   local ip, port = self.socket:getsockname()
end


function TcpRosConnection:send_header(fields)
   local s = ""

   for k,v in pairs(fields) do
      local f  = k .. "=" .. v
      local fp = struct.pack("<!4i4", #f) .. f
      s = s .. fp
   end

   self.socket:send(struct.pack("<!4i4", #s) .. s)
end

function TcpRosConnection:receive_header()
   self.header = {}

   local rd = self.socket:receive(4)
   local packet_size = struct.unpack("<!4i4", rd)

   local packet = self.socket:receive(packet_size)
   local i = 1

   while i <= packet_size do
      local field_size
      field_size, i = struct.unpack("<!4i4", packet, i)

      local sub = string.sub(packet, i, i+field_size)
      local eqpos = string.find(sub, "=")
      local k = string.sub(sub, 1, eqpos - 1)
      local v = string.sub(sub, eqpos + 1, field_size)

      self.header[k] = v

      i = i + field_size
   end

   --assert(self.header.type, "Opposite site did not set type")

   return self.header
end

function TcpRosConnection:data_available()
   local selres = socket.select({self.socket}, {}, 0)

   return selres[self.socket] ~= nil
end

function TcpRosConnection:data_received()
   local rv = self.received
   self.received = false
   return rv
end

function TcpRosConnection:receive()
   local packet_size_d = self.socket:receive(4)
   local packet_size = struct.unpack("<!4i4", packet_size_d)

   print("Packet size", packet_size)

   self.payload = self.socket:receive(packet_size)

   local string_size, next_i = struct.unpack("<!4i4", self.payload)
   print("string size", string_size)
   self.payload = string.sub(self.payload, next_i)


   self.received = true
end

function TcpRosConnection:spin()
   if self:data_available() then
      self:receive()
   end
end
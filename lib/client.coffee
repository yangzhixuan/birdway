net = require('net')
clients = []
svr = net.createServer (sock)->
    console.log "connected: " + sock.remoteAddress + ":" + sock.remotePort
    clients.push sock
    sock.on 'data', (data) ->
        console.log "data: " + sock.remoteAddress + ":" + data
        for client in clients
          if client != sock
            client.write(data)
    sock.on 'end', ->
      clients.splice clients.indexOf(sock), 1

svr.listen({port: 9527})

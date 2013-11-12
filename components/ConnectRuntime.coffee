noflo = require 'noflo'

class ConnectRuntime extends noflo.Component
  constructor: ->
    @editor = null
    @runtime = null
    @inPorts =
      editor: new noflo.Port 'object'
      runtime: new noflo.Port 'object'
    @outPorts =
      editor: new noflo.Port 'object'

    @inPorts.editor.on 'data', (@editor) =>
      @connect @editor, @runtime
      if @outPorts.editor.isAttached()
        @outPorts.editor.send @editor
        @outPorts.editor.disconnect()
    @inPorts.runtime.on 'data', (@runtime) =>
      @connect @editor, @runtime

  sendGraph: (runtime, editor) ->
    runtime.sendGraph 'clear',
      baseDir: 'noflo-ui-preview'
    graph = editor.toJSON()
    for name, definition of graph.processes
      runtime.sendGraph 'addnode',
        id: name
        component: definition.component
        metadata: definition.metadata
    for edge in graph.connections
      if edge.src
        runtime.sendGraph 'addedge',
          from:
            node: edge.src.process
            port: edge.src.port
          to:
            node: edge.tgt.process
            port: edge.tgt.port
        continue
      runtime.sendGraph 'addinitial',
        from:
          data: edge.data
        to:
          node: edge.tgt.process
          port: edge.tgt.port

  convertNode: (node) ->
    node.toJSON()
  convertEdge: (edge) ->
    data = edge.toJSON()
    edgeData =
      from:
        node: data.src.process
        port: data.src.port
      to:
        node: data.tgt.process
        port: data.tgt.port
  convertInitial: (iip) ->
    data = iip.toJSON()
    iipData =
      from:
        data: data.data
      to:
        node: data.tgt.process
        port: data.tgt.port

  subscribeEditor: (editor, runtime) ->
    editor.addEventListener 'addnode', (node) =>
      runtime.sendGraph 'addnode', @convertNode node.detail
    , false
    editor.addEventListener 'removenode', (node) =>
      runtime.sendGraph 'removenode', @convertNode node.detail
    , false
    editor.addEventListener 'addedge', (edge) =>
      runtime.sendGraph 'addedge', @convertEdge edge.detail
    , false
    editor.addEventListener 'removeedge', (edge) =>
      runtime.sendGraph 'removeedge', @convertEdge edge.detail
    , false
    editor.addEventListener 'addinitial', (iip) =>
      runtime.sendGraph 'addinitial', @convertInitial iip.detail
    , false
    editor.addEventListener 'removeinitial', (iip) =>
      runtime.sendGraph 'removeinitial', @convertInitial iip.detail
    , false
    # IIP value changes need to be propagated as add+remove
    editor.addEventListener 'iip', (iip) =>
      runtime.sendGraph 'removeinitial', @convertInitial iip.detail
      runtime.sendGraph 'addinitial', @convertInitial iip.detail
    , false

  connect: (editor, runtime) ->
    return unless editor and runtime
    runtime.on 'connected', =>
      # TODO: Read basedir from graph?
      runtime.sendComponent 'list', 'noflo-ui-preview'
      @sendGraph runtime, editor
    @subscribeEditor editor, runtime

    runtime.on 'component', (message) ->
      definition =
        name: message.payload.name
        description: message.payload.description
        icon: message.payload.icon
        inports: []
        outports: []
      for port in message.payload.inPorts
        definition.inports.push
          name: port.id
          type: port.type
          array: port.array
      for port in message.payload.outPorts
        definition.outports.push
          name: port.id
          type: port.type
          array: port.array
      editor.registerComponent definition
    runtime.setParentElement editor.parentNode
    runtime.connect editor.graph.properties.environment

exports.getComponent = -> new ConnectRuntime

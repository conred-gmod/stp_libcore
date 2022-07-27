# STPLib.DirGraph

A common directed graph

```

type .VertexId = nonzero_uint
type .VertexData = any|nil
type .EdgeId = nonzero_uint
type .EdgeData = any|nil

type .TransactionChanges = {
    AddedVertices: table(.VertexId, { Data: .VertexData })
    AddedEdges: table(.EdgeId, {
        From: .VertexId, To: .VertexId,
        Data: .EdgeData
    })

    RemovedVertices: table(.VertexId, true)
    RemovedEdges: table(.EdgeId, true)
    -- Set of edges removed due to vertex removal
    RemovedEdgesCascaded: table(.EdgeId, true)

    DataChangedVertices: table(.VertexId, { Data: .VertexData }),
    DataChangedEdges: table(.EdgeId, { Data: .EdgeData })

    ReattachedEdges: table(.EdgeId, {
        NewFrom: .VertexId|nil,
        NewTo: .VertexId|nil
    })
}

type .GraphView = trait {
    fn :HasVertex(id: .VertexId) -> bool
    fn :HasEdge(id: .EdgeId) -> bool

    fn :GetVertexData(vert: .VertexId) -> .VertexData
    fn :GetEdgeData(edge: .EdgeId) -> .EdgeData

    fn :GetVertices() -> <iterator> -> .VertexId
    fn :GetEdges() -> <iterator> -> edge: .EdgeId, from: .VertexId, to: .VertexId
    fn :GetEdgeVetices(edge: .EdgeId) -> from: .VertexId, to: .VertexId

    readonly .RootGraph: .Graph
    readonly .Parent: .GraphView

    hook :PreTransacionApplied(changes: .TransactionChanges)
}

-- A real graph, stored in memory
fn .NewGraph() -> .Graph

type .Graph = impl(.GraphView) {
    fn :AddVertex(data: .VertexData) -> .VertexId
    -- Returns nil if:
    --    - `(from, to)` pair was already used
    --    - `from` and `to` are equal
    fn :AddEdge(from: .VertexId, to: .VertexId, data: .EdgeData) -> .EdgeId | nil

    fn :RemoveVertex(vert: .VertexId)
    fn :RemoveEdges(edge: .EdgeId)

    fn :SetVertexData(vert: .VertexId, data: .VertexData) -> old_data: .VertexData
    fn :SetEdgeData(edge: .EdgeId, data: .EdgeData) -> old_data: .EdgeData

    -- If `new_to` or `new_from` is nil, this value not changes
    fn :ChangeEdgeVertices(edge: .EdgeId, new_to: .VertexId|nil, new_from: .VertexId|nil) -> old_to: .VertexId, old_from: .VertexId

    -- All modifying functions should be called between these two functions
    fn :StartTransaction()
    -- After this call modifications will be applied
    fn :FinishTransaction()

}

fn .TransactionPreview(base: .GraphView, changes: .TransactionChanges) -> .GraphView

fn .FilterByData(base: .GraphView, params: {
    -- If nil, no vertices are discarded
    -- Function return: true - keep
    VertexPredicate: nil|fn(vert: .VertexData) -> bool

    -- If nil, no edges are discarded
    -- Function return: true - keep
    EdgePredicate: nil|fn(edge: .EdgeData, vert_from: .VertexData, vert_to: .VertexData) -> bool
}) -> .GraphView

fn .ComputeConnectedVertices(base: .GraphView, params: {
    IgnoreEdgeDirection: bool
}) -> .ConenctedVerticesGraphView

type .ConenctedVerticesGraphView = impl(.GraphView) {
    -- Connected vertices include `vert`
    fn :GetConnectedVertices(vert: .VertexId) -> <iterator> -> .VertexId

    fn :AreVerticesConnected(from: .VertexId, to: .VertexId) -> bool

    fn :GetIsolatedSubgraphs() -> <iterator> -> array(.VertexId)
    fn :GetIsolatedSubhraphCount() -> uint
}

fn .MapData(base: .GraphView, params: {
    GetChanged: fn(base: <.base>, changes: .TransactionChanges) -> array(.VertexId)|nil, array(.EdgeId)|nil

    MapVertex: nul|fn(base: <.base>, vertex: .VertexId) -> .VertexData
    MapEdge: nil|fn(base: <.base>, edge: .EdgeId) -> .EdgeData

}) -> .GraphView -- With other .VertexData and/or .EdgeData

fn 

```
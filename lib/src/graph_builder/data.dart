typedef ForceGraphEdgeDataMap = Map;

typedef ForceGraphNodeDataMap = Map;

extension ForceGraphNodeDataExt on ForceGraphNodeDataMap {
  String get id => this['id'] as String;
  List<ForceGraphEdgeDataMap> get edges {
    final rawEdges = this['edges'];
    final edges = <ForceGraphEdgeDataMap>[];
    if (rawEdges is Iterable) {
      for (final edge in rawEdges) {
        edges.add(edge);
      }
    }
    return edges;
  }
}

extension ForceGraphEdgeDataExt on ForceGraphEdgeDataMap {
  String get source => this['source'] as String;
  String get target => this['target'] as String;
  num get similarity => this['similarity'] as num;
}

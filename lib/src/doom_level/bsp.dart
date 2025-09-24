//
// Code translated from C from NanoBSP by Andrew J Apted
//
// Development homepage: https://gitlab.com/andwj/nano_bsp.git
//
//----------------------------------------------------------------------------
//
//  Copyright (c) 2023 Andrew Apted
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//----------------------------------------------------------------------------
//

import 'dart:math';
import 'dart:typed_data';

import 'level.dart';
import 'element.dart';
import '../wad_data.dart';

// this value is a trade-off.  lower values will build nodes faster,
// but higher values allow picking better BSP partitions (and hence
// produce better BSP trees).
const _fastThreshold = 128;
const _distEpsilon = 1.0 / 64;
const _splitCost = 11;
const _subsectorMark = 32768;

typedef _RawSeg = ({ int v1, int v2, int ang, int line, int dir, int ofs });

_RawSeg _readRawSeg(ByteData data) {
  return (
    v1: data.getInt16(0, Endian.little),
    v2: data.getInt16(2, Endian.little),
    ang: data.getInt16(4, Endian.little),
    line: data.getInt16(6, Endian.little),
    dir: data.getInt16(8, Endian.little),
    ofs: data.getInt16(10, Endian.little),
  );
}

typedef _RawSubsector = ({ int count, int first });

_RawSubsector _readRawSubsector(ByteData data) {
  return (count: data.getInt16(0, Endian.little), first: data.getInt16(2, Endian.little));
}

typedef _RawNode = ({
  double x, double y, double dx, double dy, BBox boxRight, BBox boxLeft, int childRight, int childLeft
});

_RawNode _readRawNode(ByteData byteData) {
  const i = 0;
  return (
    x: byteData.getInt16(i, Endian.little) as double,
    y: byteData.getInt16(i + 2, Endian.little) as double,
    dx: byteData.getInt16(i + 4, Endian.little) as double,
    dy: byteData.getInt16(i + 6, Endian.little) as double,
    boxRight: BBox(
      byteData.getInt16(i + 12, Endian.little) as double,
      byteData.getInt16(i + 10, Endian.little) as double,
      byteData.getInt16(i + 14, Endian.little) as double,
      byteData.getInt16(i + 8, Endian.little) as double,
    ),
    boxLeft: BBox(
      byteData.getInt16(i + 20, Endian.little) as double,
      byteData.getInt16(i + 18, Endian.little) as double,
      byteData.getInt16(i + 22, Endian.little) as double,
      byteData.getInt16(i + 16, Endian.little) as double,
    ),
    childRight: byteData.getInt16(i + 24, Endian.little),
    childLeft: byteData.getInt16(i + 26, Endian.little),
  );
}

class BSP {
  void loadFromWad(WadData wadData, int levelIndex, Level level) {
    final (segsLumpIndex, subsectorsLumpIndex, nodesLumpIndex) = (levelIndex + 5, levelIndex + 6, levelIndex + 7);
    if(nodesLumpIndex >= wadData.lumps.length) {
      return;
    }
    if(wadData.lumps[segsLumpIndex].name != 'SEGS' || 
       wadData.lumps[subsectorsLumpIndex].name != 'SSECTORS' ||
       wadData.lumps[nodesLumpIndex].name != 'NODES')
    {
      return;
    }

    final (segLen, subsectorLen, nodeLen) = (12, 4, 28);

    final (numSegs, numSubsectors, numNodes) = (
      wadData.lumps[segsLumpIndex].data.length ~/ segLen,
      wadData.lumps[subsectorsLumpIndex].data.length ~/ subsectorLen,
      wadData.lumps[nodesLumpIndex].data.length ~/ nodeLen
    );

    final (rawSegs, rawSubsectors, rawNodes) = (<_RawSeg>[], <_RawSubsector>[], <_RawNode>[]);
    for(int i = 0; i < numSegs; ++i) {
      rawSegs.add(_readRawSeg(ByteData.sublistView(wadData.lumps[segsLumpIndex].data, i * segLen, segLen)));
    }
    for(int i = 0; i < numSubsectors; ++i) {
      rawSubsectors.add(_readRawSubsector(
        ByteData.sublistView(wadData.lumps[subsectorsLumpIndex].data, i * subsectorLen, subsectorLen)
      ));
    }
    for(int i = 0; i < numNodes; ++i) {
      rawNodes.add(_readRawNode(ByteData.sublistView(wadData.lumps[nodesLumpIndex].data, i * nodeLen, nodeLen)));
    }

    root = _processRawNode(rawSegs, rawSubsectors, rawNodes, rawNodes.length - 1, level, <int>{});
    _takeBSPVertices(level);
  }

  void _takeBSPVertices(Level level) {
    int lastUsedVertexIndex = -1;
    for(int i = level.vertices.length - 1; i >= 0; i--) {
      if(level.vertices[i].linedefs.isNotEmpty) {
        lastUsedVertexIndex = i;
        break;
      }
    }

    if(lastUsedVertexIndex + 1 < level.vertices.length) {
      vertices.addAll(level.vertices.sublist(lastUsedVertexIndex + 1));
      level.vertices.length = lastUsedVertexIndex + 1;
    }
  }

  Seg? _processRawSeg(_RawSeg rawSeg, Level level) {
    if(rawSeg.v1 < 0 || rawSeg.v1 >= level.vertices.length || rawSeg.v2 < 0 || rawSeg.v2 >= level.vertices.length ||
       rawSeg.line < 0 || rawSeg.line >= level.linedefs.length)
    {
      return null;
    }
    final linedef = level.linedefs[rawSeg.line];
    final sidedef = rawSeg.dir == 0 ? linedef.sidedef1 : linedef.sidedef2;
    if(sidedef == null) {
      return null;
    }
    final seg = Seg(
      v1: level.vertices[rawSeg.v1],
      v2: level.vertices[rawSeg.v2],
      linedef: linedef,
      sidedef: sidedef,
    );
    seg.angle = pi * (rawSeg.ang / 32768);
    seg.offset = rawSeg.ofs as double;
    return seg;
  }

  Subsector? _processRawSubsector(_RawSubsector rawSubsector, List<_RawSeg> rawSegs, Level level) {
    if(rawSubsector.count <= 0) {
      return null;
    }
    if(rawSubsector.first < 0 || rawSubsector.first + rawSubsector.count > rawSegs.length) {
      return null;
    }
    final subsector = Subsector();
    for(int i = 0; i < rawSubsector.count; ++i) {
      final seg = _processRawSeg(rawSegs[rawSubsector.first + i], level);
      if(seg != null) {
        subsector.segs.add(seg);
      }
    }
    if(subsector.segs.isEmpty) {
      return null;
    }
    return subsector;
  }

  Node? _processRawNode(
    List<_RawSeg> rawSegs, 
    List<_RawSubsector> rawSubsectors, 
    List<_RawNode> rawNodes, 
    int nodeIndex,
    Level level,
    Set<int> visited
  ) {
    // Recursion protection
    if(visited.contains(nodeIndex)) {
      return null;
    }
    visited.add(nodeIndex);
    final item = rawNodes[nodeIndex];
    final GenericNode? right, left;
    if(item.childRight & _subsectorMark != 0) {
      final subsectorIndex = item.childRight & ~_subsectorMark;
      if(subsectorIndex < 0 || subsectorIndex >= rawSubsectors.length) {
        return null; // invalid, can't go further
      }
      right = _processRawSubsector(rawSubsectors[subsectorIndex], rawSegs, level);
    } else {
      if(item.childRight < 0 || item.childRight >= rawNodes.length) {
        return null;
      }
      right = _processRawNode(rawSegs, rawSubsectors, rawNodes, item.childRight, level, visited);
    }
    if(item.childLeft & _subsectorMark != 0) {
      final subsectorIndex = item.childLeft & ~_subsectorMark;
      if(subsectorIndex < 0 || subsectorIndex >= rawSubsectors.length) {
        return null; // invalid, can't go further
      }
      left = _processRawSubsector(rawSubsectors[subsectorIndex], rawSegs, level);
    } else {
      if(item.childLeft < 0 || item.childLeft >= rawNodes.length) {
        return null;
      }
      left = _processRawNode(rawSegs, rawSubsectors, rawNodes, item.childLeft, level, visited);
    }
    if(left == null || right == null) {
      return null;
    }

    final node = Node(children: (right: right, left: left));
    node.x = item.x;
    node.y = item.y;
    node.dx = item.dx;
    node.dy = item.dy;
    node.bbox = (right: item.boxRight, left: item.boxLeft);
    return node;
  }

  GenericNode? root;
  final vertices = <Vertex>[];
}

class Seg {
  Seg({
    required this.v1,
    required this.v2,
    required this.sidedef,
    required this.linedef,
  });

  void copyFrom(Seg other) {
    v1 = other.v1;
    v2 = other.v2;
    sidedef = other.sidedef;
    linedef = other.linedef;
    angle = other.angle;
    offset = other.offset;
    next = other.next;
  }

  Vertex v1, v2;
  Sidedef sidedef;
  Linedef linedef;
  double angle = 0;
  double offset = 0;

  Seg? next;
}

sealed class GenericNode {}

class Subsector extends GenericNode {
  final segs = <Seg>[];
  Sector get sector => segs[0].sidedef.sector;
}

class Node extends GenericNode {
  Node({ required this.children });

  double x = 0;
  double y = 0;
  double dx = 0;
  double dy = 0;
  ({GenericNode right, GenericNode left}) children;
  var bbox = (right: BBox(), left: BBox());
}

class BBox {
  BBox([
    this.left = double.infinity, 
    this.bottom = double.infinity, 
    this.right = double.negativeInfinity, 
    this.top = double.negativeInfinity
  ]);

  void addPoint(double x, double y) {
    left = min(left, x);
    bottom = min(bottom, y);
    right = max(right, x);
    top = max(top, y);
  }

  (double, double) center() {
    return ((left + right) / 2, (bottom + top) / 2);
  }

  static BBox merge(BBox box1, BBox box2) {
    var out = BBox();
    out.left = min(box1.left, box2.left);
    out.bottom = min(box1.bottom, box2.bottom);
    out.right = max(box1.right, box2.right);
    out.top = max(box1.top, box2.top);
    return out;
  }

  double left;
  double bottom;
  double right;
  double top;
}

BSP bspBuildNodes(Level level) {
  final Seg? list = _createSegs(level);
  final bsp = BSP();
  final _Nanode root = _subdivideSegs(list, bsp);

  final (finalRoot, box) = _writeNode(root, bsp);
  bsp.root = finalRoot;
  
  return bsp;
}

class _Nanode {
  // when non-null, this is actually a leaf of the BSP tree
  Seg? segs;

  // partition line (start coord, delta to end)
  double x = 0, y = 0, dx = 0, dy = 0;

  // right and left children
  _Nanode? right, left;
}

void _calcOffset(Seg seg) {
  final ld = seg.linedef;

  // compute which side of the linedef the seg is on
  int side;
  final dx = ld.vertex2.x - ld.vertex1.x;
  final dy = ld.vertex2.y - ld.vertex1.y;
  if(dx.abs() > dy.abs()) {
    side = (dx < 0) == (seg.v2.x - seg.v1.x < 0) ? 0 : 1;
  } else {
    side = (dy < 0) == (seg.v2.y - seg.v1.y < 0) ? 0 : 1;
  }
  final viewx = side == 1 ? ld.vertex2.x : ld.vertex1.x;
  final viewy = side == 1 ? ld.vertex2.y : ld.vertex1.y;
  seg.offset = sqrt(pow(seg.v1.x - viewx, 2) + pow(seg.v1.y - viewy, 2));
}

BBox _boundingBox(Seg? soup) {
  var bbox = BBox();
  for(Seg? S = soup; S != null; S = S.next) {
    bbox.addPoint(S.v1.x, S.v1.y);
    bbox.addPoint(S.v2.x, S.v2.y);
  }
  return bbox;
}

Seg? _segForLineSide(Level level, int i, int side, Seg? listVar) {
  Linedef ld = level.linedefs[i];
  Sidedef? sidedef = side == 0 ? ld.sidedef1 : ld.sidedef2;
  if(sidedef == null) {
    return null;
  }
  var seg = Seg(
    v1: side == 1 ? ld.vertex2 : ld.vertex1,
    v2: side == 1 ? ld.vertex1 : ld.vertex2,
    sidedef: sidedef,
    linedef: ld,
  );
  seg.angle = atan2(seg.v2.y - seg.v1.y, seg.v2.x - seg.v1.x);

  _calcOffset(seg);

  // link into the list
  seg.next = listVar;
  return seg;
}

Seg? _createSegs(Level level) {
  Seg? list;
  for(int i = 0; i < level.linedefs.length; ++i) {
    list = _segForLineSide(level, i, 0, list);
    list = _segForLineSide(level, i, 1, list);
  }
  return list;
}

_Nanode _createLeaf(Seg? soup) {
  var node = _Nanode();
  node.segs = soup;
  return node;
}

//----------------------------------------------------------------------------

class _NodeEval {
  int left = 0;
  int right = 0;
  int split = 0;
}

int _pointOnSide(double x1, double y1, double x2, double y2, double x, double y) {
  x -= x1;
  y -= y1;

  final dx = x2 - x1;
  final dy = y2 - y1;

  if(dx == 0) {
    if(x < -_distEpsilon) {
      return dy < 0 ? 1 : -1;
    }
    if(x > _distEpsilon) {
      return dy > 0 ? 1 : -1;
    }
    return 0;
  }
  if(dy == 0) {
    if(y < -_distEpsilon) { 
      return dx > 0 ? 1 : -1;
    }
    if(y > _distEpsilon) {
      return dx < 0 ? 1 : -1;
    }
    return 0;
  }

  // note that we compute the distance to the partition along an axis
	// (rather than perpendicular to it), which can give values smaller
	// than the true distance.  for our purposes, that is okay.
  if(dx.abs() >= dy.abs()) {
    final slope = dy / dx;
    y -= x * slope;
    if(y < -_distEpsilon) {
      return dx > 0 ? 1 : -1;
    }
    if(y > _distEpsilon) {
      return dx < 0 ? 1 : -1;
    }
  } else {
    final slope = dx / dy;
    x -= y * slope;
    if(x < -_distEpsilon) { 
      return dy < 0 ? 1 : -1;
    }
    if(x > _distEpsilon) {
      return dy > 0 ? 1 : -1;
    }
  }
  return 0;
}

int _pointOnSegSide(Seg part, double x, double y) {
  return _pointOnSide(part.v1.x, part.v1.y, part.v2.x, part.v2.y, x, y);
}

bool _sameDirection(Seg part, Seg seg) {
  final pdx = part.v2.x - part.v1.x;
  final pdy = part.v2.y - part.v1.y;
  final sdx = seg.v2.x - seg.v1.x;
  final sdy = seg.v2.y - seg.v1.y;
  final n = sdx * pdx + sdy * pdy;
  return n > 0;
}

int _segOnSide(Seg part, Seg seg) {
  if(seg == part) {
    return 1;
  }
  final side1 = _pointOnSegSide(part, seg.v1.x, seg.v1.y);
  final side2 = _pointOnSegSide(part, seg.v2.x, seg.v2.y);

  // colinear?
  if(side1 == 0 && side2 == 0) {
    return _sameDirection(part, seg) ? 1 : -1;
  }

  // splits the seg?
  if(side1 * side2 < 0) {
    return 0;
  }
  return side1 >= 0 && side2 >= 0 ? 1 : -1;
}

//
// Evaluate a seg as a partition candidate, storing the results in `eval`.
// returns true if the partition is viable, false otherwise.
//
(bool, _NodeEval) _evalPartition(Seg part, Seg? soup) {
  var eval = _NodeEval();

  if((part.v2.x - part.v1.x).abs() < 4 * _distEpsilon &&
     (part.v2.y - part.v1.y).abs() < 4 * _distEpsilon)
  {
    return (false, eval);
  }

  for(Seg? S = soup; S != null; S = S.next) {
    final side = _segOnSide(part, S);
    switch(side) {
      case 0:
        eval.split += 1;
      case -1:
        eval.left += 1;
      case 1:
        eval.right += 1;
    }
  }

  // a viable partition either splits something, or has other segs
	// lying on *both* the left and right sides.

  return (eval.split > 0 || (eval.left > 0 && eval.right > 0), eval);
}

Seg? _pickNodeFast(Seg? soup) {
  // use slower method when number of segs is below a threshold
  int count = 0;
  for(Seg? S = soup; S != null; S = S.next) {
    count++;
  }
  if(count < _fastThreshold) {
    return null;
  }

  // determine bounding box of the segs
  final bbox = _boundingBox(soup);

  final (midX, midY) = bbox.center();

  Seg? vertPart;
  double vertDist = 16384;

  Seg? horizPart;
  double horizDist = 16384;

  // find the seg closest to the middle of the bbox
  for(Seg? part = soup; part != null; part = part.next) {
    if(part.v1.x == part.v2.x) {
      double dist = (part.v1.x - midX).abs();
      if(dist < vertDist) {
        vertPart = part;
        vertDist = dist;
      }
    } else if(part.v1.y == part.v2.y) {
      double dist = (part.v1.y - midY).abs();
      if(dist < horizDist) {
        horizPart = part;
        horizDist = dist;
      }
    }
  }

  // check that each partition is viable
  _NodeEval vEval;
  _NodeEval hEval;

  bool vertOK, horizOK;
  if(vertPart != null) {
    (vertOK, vEval) = _evalPartition(vertPart, soup);
  } else {
    (vertOK, vEval) = (false, _NodeEval());
  }
  if(horizPart != null) {
    (horizOK, hEval) = _evalPartition(horizPart, soup);
  } else {
    (horizOK, hEval) = (false, _NodeEval());
  }

  if(vertOK && horizOK) {
    final vertCost = (vEval.left - vEval.right).abs() * 2 + vEval.split * _splitCost;
    final horizCost = (hEval.left - hEval.right).abs() * 2 + hEval.split * _splitCost;

    return horizCost < vertCost ? horizPart : vertPart;
  }

  if(vertOK) {
    return vertPart;
  }
  if(horizOK) {
    return horizPart;
  }
  return null;
}

//
// Evaluate *every* seg in the list as a partition candidate,
// returning the best one, or NULL if none found (which means
// the remaining segs form a subsector).
//
Seg? _pickNodeSlow(Seg? soup) {
  Seg? best;
  int bestCost = 1 << 30;

  for(Seg? part = soup; part != null; part = part.next) {
    final (res, eval) = _evalPartition(part, soup);
    if(res) {
      final cost = (eval.left - eval.right).abs() * 2 + eval.split * _splitCost;
      if(cost < bestCost) {
        best = part;
        bestCost = cost;
      }
    }
  }
  return best;
}

//----------------------------------------------------------------------------

(double, double) _computeIntersection(Seg part, Seg seg) {
  double a, b;
  if(part.v1.x == part.v2.x) {
    // vertical partition
    if(seg.v1.y == seg.v2.y) {
      // horizontal seg
      return (part.v1.x, seg.v1.y);
    }
    a = (seg.v1.x - part.v1.x).abs();
    b = (seg.v2.x - part.v1.x).abs();
  } else if(part.v1.y == part.v2.y) {
    // horizontal partition
    if(seg.v1.x == seg.v2.x) {
      // vertical seg
      return (seg.v1.x, part.v1.y);
    }
    a = (seg.v1.y - part.v1.y).abs();
    b = (seg.v2.y - part.v1.y).abs();
  } else {
    final dx = part.v2.x - part.v1.x;
    final dy = part.v2.y - part.v1.y;

    // compute seg coords relative to partition start
    final x1 = seg.v1.x - part.v1.x;
    final y1 = seg.v1.y - part.v1.y;
    final x2 = seg.v2.x - part.v1.x;
    final y2 = seg.v2.y - part.v1.y;

    if(dx.abs() >= dy.abs()) {
      final slope = dy / dx;
      a = (y1 - x1 * slope).abs();
      b = (y2 - x2 * slope).abs();
    } else {
      final slope = dx / dy;
      a = (x1 - y1 * slope).abs();
      b = (x2 - y2 * slope).abs();
    }
  }
  final along = a / (a + b);
  return (
    seg.v1.x == seg.v2.x ? seg.v1.x : seg.v1.x + (seg.v2.x - seg.v1.x) * along,
    seg.v1.y == seg.v2.y ? seg.v1.y : seg.v1.y + (seg.v2.y - seg.v1.y) * along
  );
}

//
// For segs not intersecting the partition, just move them into the
// correct output list (`lefts` or `rights`).  otherwise split the seg
// at the intersection point, one piece goes left, the other right.
//
(Seg?, Seg?) _splitSegs(Seg part, Seg? soup, Seg? lefts, Seg? rights, BSP bsp) {
  while(soup != null) {
    final S = soup;
    soup = soup.next;
    final where = _segOnSide(part, S);
    if(where < 0) {
      S.next = lefts;
      lefts = S;
      continue;
    }
    if(where > 0) {
      S.next = rights;
      rights = S;
      continue;
    }

    // we must split this seg
    final (ix, iy) = _computeIntersection(part, S);
    bsp.vertices.add(Vertex());
    final iv = bsp.vertices.last;
    iv.x = ix;
    iv.y = iy;
    final T = Seg(v1: iv, v2: S.v2, sidedef:S.sidedef, linedef:S.linedef);
    S.v2 = iv;
    T.angle = S.angle;

    // compute offsets for the split pieces
    _calcOffset(T);
    _calcOffset(S);

    if(_pointOnSegSide(part, S.v1.x, S.v1.y) < 0) {
      S.next = lefts;
      lefts = S;
      T.next = rights;
      rights = S;
    } else {
      S.next = rights;
      rights = S;
      T.next = lefts;
      lefts = T;
    }
  }
  return (lefts, rights);
}

_Nanode _subdivideSegs(Seg? soup, BSP bsp) {
  final part = _pickNodeFast(soup) ?? _pickNodeSlow(soup);
  if(part == null) {
    return _createLeaf(soup);
  }
  final N = _Nanode();
  N.x = part.v1.x;
  N.y = part.v1.y;
  N.dx = part.v2.x - N.x;
  N.dy = part.v2.y - N.y;

	// ensure partitions are a minimum length, since the engine's
	// R_PointOnSide() function has very poor accuracy when the
	// delta is too small, and that WILL BREAK a map.
  const minSize = 64;
  while(N.dx.abs() < minSize && N.dy.abs() < minSize) {
    N.dx *= 2;
    N.dy *= 2;
  }

  // these are the new lists (after splitting)
  Seg? lefts, rights;
  (lefts, rights) = _splitSegs(part, soup, lefts, rights, bsp);
  N.right = _subdivideSegs(rights, bsp);
  N.left = _subdivideSegs(lefts, bsp);
  return N;
}

//----------------------------------------------------------------------------

(GenericNode, BBox) _writeNode(_Nanode N, BSP bsp) {
  final BBox bbox;
  if(N.segs != null) {  // this is a subsector (leaf)
    bbox = _boundingBox(N.segs);
    final subsector = Subsector();
    for(Seg? seg = N.segs; seg != null; seg = seg.next) {
      subsector.segs.add(seg);
    }
    return (subsector, bbox);
  }
  // node
  final (rightChild, rightBBox) = _writeNode(N.right!, bsp);
  final (leftChild, leftBBox) = _writeNode(N.left!, bsp);

  final node = Node(children: (right: rightChild, left: leftChild));
  node.x = N.x;
  node.y = N.y;
  node.dx = N.dx;
  node.dy = N.dy;
  node.bbox = (right: rightBBox, left: leftBBox);
  return (node, BBox.merge(rightBBox, leftBBox));
}

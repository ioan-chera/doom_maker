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

import '../level.dart';
import '../element.dart';

// this value is a trade-off.  lower values will build nodes faster,
// but higher values allow picking better BSP partitions (and hence
// produce better BSP trees).
const fastThreshold = 128;
const distEpsilon = 1.0 / 64;
const splitCost = 11;
const subsectorMark = 32768;

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
    frontsector = other.frontsector;
    backsector = other.backsector;
    next = other.next;
  }

  Vertex v1, v2;
  Sidedef sidedef;
  Linedef linedef;
  double angle = 0;
  double offset = 0;
  Sector? frontsector, backsector;

  Seg? next;
}

class Subsector {
  int numlines = 0;
  int firstline = 0;
  Sector? sector;
}

class Node {
  double x = 0;
  double y = 0;
  double dx = 0;
  double dy = 0;
  List<int> children = [0, 0];
  List<BBox> bbox = [BBox(), BBox()];
}

class BBox {
  double left = double.infinity;
  double bottom = double.infinity;
  double right = double.negativeInfinity;
  double top = double.negativeInfinity;
}

class Nanode {
  // when non-null, this is actually a leaf of the BSP tree
  Seg? segs;

  // final index number of this node / leaf
	int  index = -1;

  // partition line (start coord, delta to end)
  double x = 0, y = 0, dx = 0, dy = 0;

  // right and left children
  Nanode? right, left;
}

class BSP {
  final nodes = <Node>[];
  final subsectors = <Subsector>[];
  final segs = <Seg?>[];  // IOANCH: optional because of technicality
  final vertices = <Vertex>[];

  int nanoSegIndex = 0;
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
    bbox.left = min(bbox.left, S.v1.x);
    bbox.left = min(bbox.left, S.v2.x);
    bbox.bottom = min(bbox.bottom, S.v1.y);
    bbox.bottom = min(bbox.bottom, S.v2.y);

    bbox.right = max(bbox.right, S.v1.x);
    bbox.right = max(bbox.right, S.v2.x);
    bbox.top = max(bbox.top, S.v1.y);
    bbox.top = max(bbox.top, S.v2.y);
  }
  return bbox;
}

BBox _mergeBounds(BBox box1, BBox box2) {
  var out = BBox();
  out.left = min(box1.left, box2.left);
  out.bottom = min(box1.bottom, box2.bottom);
  out.right = max(box1.right, box2.right);
  out.top = max(box1.top, box2.top);
  return out;
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
  seg.frontsector = side == 1 ? ld.sidedef2?.sector : ld.sidedef1?.sector;
  seg.backsector = side == 1 ? ld.sidedef1?.sector : ld.sidedef2?.sector;

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

Nanode _createLeaf(Seg? soup) {
  var node = Nanode();
  node.segs = soup;
  return node;
}

//----------------------------------------------------------------------------

class NodeEval {
  int left = 0;
  int right = 0;
  int split = 0;
}

int _pointOnSide(Seg part, double x, double y) {
  x -= part.v1.x;
  y -= part.v1.y;

  final dx = part.v2.x - part.v1.x;
  final dy = part.v2.y - part.v1.y;

  if(dx == 0) {
    if(x < -distEpsilon) {
      return dy < 0 ? 1 : -1;
    }
    if(x > distEpsilon) {
      return dy > 0 ? 1 : -1;
    }
    return 0;
  }
  if(dy == 0) {
    if(y < -distEpsilon) { 
      return dx > 0 ? 1 : -1;
    }
    if(y > distEpsilon) {
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
    if(y < -distEpsilon) {
      return dx > 0 ? 1 : -1;
    }
    if(y > distEpsilon) {
      return dx < 0 ? 1 : -1;
    }
  } else {
    final slope = dx / dy;
    x -= y * slope;
    if(x < -distEpsilon) { 
      return dy < 0 ? 1 : -1;
    }
    if(x > distEpsilon) {
      return dy > 0 ? 1 : -1;
    }
  }
  return 0;
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
  final side1 = _pointOnSide(part, seg.v1.x, seg.v1.y);
  final side2 = _pointOnSide(part, seg.v2.x, seg.v2.y);

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
(bool, NodeEval) _evalPartition(Seg part, Seg? soup) {
  var eval = NodeEval();

  if((part.v2.x - part.v1.x).abs() < 4 * distEpsilon &&
     (part.v2.y - part.v1.y).abs() < 4 * distEpsilon)
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

  return (eval.split > 0 || (eval.left >0 && eval.right > 0), eval);
}

Seg? _pickNode_Fast(Seg? soup) {
  // use slower method when number of segs is below a threshold
  int count = 0;
  for(Seg? S = soup; S != null; S = S.next) {
    count++;
  }
  if(count < fastThreshold) {
    return null;
  }

  // determine bounding box of the segs
  final bbox = _boundingBox(soup);

  double mid_x = bbox.left / 2 + bbox.right / 2;
  double mid_y = bbox.bottom / 2 + bbox.top / 2;

  Seg? vert_part;
  double vert_dist = 16384;

  Seg? horiz_part;
  double horiz_dist = 16384;

  // find the seg closest to the middle of the bbox
  for(Seg? part = soup; part != null; part = part.next) {
    if(part.v1.x == part.v2.x) {
      double dist = (part.v1.x - mid_x).abs();
      if(dist < vert_dist) {
        vert_part = part;
        vert_dist = dist;
      }
    } else if(part.v1.y == part.v2.y) {
      double dist = (part.v1.y - mid_y).abs();
      if(dist < horiz_dist) {
        horiz_part = part;
        horiz_dist = dist;
      }
    }
  }

  // check that each partition is viable
  NodeEval v_eval;
  NodeEval h_eval;

  bool vert_ok, horiz_ok;
  if(vert_part != null) {
    (vert_ok, v_eval) = _evalPartition(vert_part, soup);
  } else {
    (vert_ok, v_eval) = (false, NodeEval());
  }
  if(horiz_part != null) {
    (horiz_ok, h_eval) = _evalPartition(horiz_part, soup);
  } else {
    (horiz_ok, h_eval) = (false, NodeEval());
  }

  if(vert_ok && horiz_ok) {
    final vert_cost = (v_eval.left - v_eval.right).abs() * 2 + v_eval.split * splitCost;
    final horiz_cost = (h_eval.left - h_eval.right).abs() * 2 + h_eval.split * splitCost;

    return horiz_cost < vert_cost ? horiz_part : vert_part;
  }

  if(vert_ok) {
    return vert_part;
  }
  if(horiz_ok) {
    return horiz_part;
  }
  return null;
}

//
// Evaluate *every* seg in the list as a partition candidate,
// returning the best one, or NULL if none found (which means
// the remaining segs form a subsector).
//
Seg? _pickNode_Slow(Seg? soup) {
  Seg? best;
  int bestCost = 1 << 30;

  for(Seg? part = soup; part != null; part = part.next) {
    final (res, eval) = _evalPartition(part, soup);
    if(res) {
      final cost = (eval.left - eval.right).abs() * 2 + eval.split * splitCost;
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
    T.frontsector = S.frontsector;
    T.backsector = S.backsector;

    // compute offsets for the split pieces
    _calcOffset(T);
    _calcOffset(S);

    if(_pointOnSide(part, S.v1.x, S.v1.y) < 0) {
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

Nanode _subdivideSegs(Seg? soup, BSP bsp) {
  final part = _pickNode_Fast(soup) ?? _pickNode_Slow(soup);
  if(part == null) {
    return _createLeaf(soup);
  }
  final N = Nanode();
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

void _countStuff(Nanode N, BSP bsp) {
  if(N.segs == null) {
    // must recurse first, to ensure root node gets highest index
    _countStuff(N.left!, bsp);
    _countStuff(N.right!, bsp);
    N.index = bsp.nodes.length;
    bsp.nodes.add(Node());
  } else {
    N.index = bsp.subsectors.length;
    bsp.subsectors.add(Subsector());
    for(Seg? seg = N.segs; seg != null; seg = seg.next) {
      bsp.segs.add(null);
    }
  }
}

void _writeSubsector(Nanode N, BSP bsp) {
  Subsector out = bsp.subsectors[N.index];
  out.numlines = 0;
  out.firstline = bsp.nanoSegIndex;
  out.sector = null;  // TODO: determine

  while(N.segs != null) {
    final seg = N.segs!;

    // unlink this seg from the list
    N.segs = seg.next;
    seg.next = null;

    // copy and free it
    bsp.segs[bsp.nanoSegIndex] = Seg(v1: seg.v1, v2: seg.v2, sidedef: seg.sidedef, linedef: seg.linedef);
    bsp.segs[bsp.nanoSegIndex]!.copyFrom(seg);

    bsp.nanoSegIndex++;
    out.numlines++;
  }
}

int _writeNode(Nanode N, BBox bbox, BSP bsp) {
  var index = N.index;
  if(N.segs != null) {
    index |= subsectorMark;
    bbox = _boundingBox(N.segs);
    _writeSubsector(N, bsp);
  } else {
    final Node out = bsp.nodes[N.index];
    out.x = N.x;
    out.y = N.y;
    out.dx = N.dx;
    out.dy = N.dy;

    for(int c = 0; c < 2; ++c) {
      final Nanode child = c == 0 ? N.right! : N.left!;
      out.children[c] = _writeNode(child, out.bbox[c], bsp);
    }
    bbox = _mergeBounds(out.bbox[0], out.bbox[1]);
  }
  return index;
}

BSP bspBuildNodes(Level level) {
  final Seg? list = _createSegs(level);
  final bsp = BSP();
  final Nanode root = _subdivideSegs(list, bsp);
  
  _countStuff(root, bsp);
  _writeNode(root, BBox(), bsp);
  return bsp;
}

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

class Seg {
  Seg({
    required this.v1,
    required this.v2,
    required this.sidedef,
    required this.linedef,
  });

  Vertex v1, v2;
  Sidedef sidedef;
  Linedef linedef;
  double angle = 0;
  double offset = 0;
  Sector? frontsector, backsector;

  Seg? next;
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

class NodeEval {
  int left = 0;
  int right = 0;
  int split = 0;
}

void bspBuildNodes(Level level) {
  Seg? list = _createSegs(level);
  // TODO
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

BBox _boundingBox(Seg? soup) {
  var bbox = BBox();
  for(Seg? S = soup; S != null; S = S.next) {
    bbox.left = min(bbox.left, S.v1.x as double);
    bbox.left = min(bbox.left, S.v2.x as double);
    bbox.bottom = min(bbox.bottom, S.v1.y as double);
    bbox.bottom = min(bbox.bottom, S.v2.y as double);

    bbox.right = max(bbox.right, S.v1.x as double);
    bbox.right = max(bbox.right, S.v2.x as double);
    bbox.top = max(bbox.top, S.v1.y as double);
    bbox.top = max(bbox.top, S.v2.y as double);
  }
  return bbox;
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
  // TODO
}

int _segOnSide(Seg part, Seg seg) {
  if(seg == part) {
    return 1;
  }
  // TODO
}

(bool, NodeEval) _evalPartition(Seg part, Seg? soup) {
  var eval = NodeEval();

  if((part.v2.x - part.v1.x).abs() < 4 * distEpsilon &&
     (part.v2.y - part.v1.y).abs() < 4 * distEpsilon)
  {
    return (false, eval);
  }

  for(Seg? S = soup; S != null; S = S.next) {
    // TODO
  }
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
  // TODO

  // TODO
  return null;
}

Nanode? _subdivideSegs(Seg? soup) {
  // TODO
  return null;
}
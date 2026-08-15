import 'dart:math' as math;
import 'dart:ui';

// The geometry and the timing of a die roll, as pure functions of the widget's
// config and a wall-clock offset. Nothing here reads a clock, and nothing here
// imports fluent_ui — that is deliberate on both counts.
//
// A board mirrors to the external-display isolate and to anonymous web viewers,
// and a mirror is handed a no-op onConfigChanged, so it can never originate a
// value. A die that rolls a 4 in the editor has to roll a 4 everywhere. The roll
// therefore travels as config (face + seed + a wall-clock anchor) in a single
// widgetUpserted, and every screen animates it locally from the same anchor —
// the same trick the stopwatch uses for its elapsed time. Frames are never
// pushed.
//
// Which makes every formula below a contract between devices rather than an
// implementation detail: the presenter runs on the VM and a web viewer runs on
// dart2js, and they must agree bit for bit.

// Model space is the camera's own frame: +x right, +y down (canvas convention),
// +z out of the screen toward the viewer. Half-side is 1; pixels arrive later as
// a single scale factor.
//
// The y-down flip makes the frame visually left-handed, which inverts the visual
// sense of every cross product. That matters exactly once — see [kFaceNormals].

class Vec3 {

  final double x;
  final double y;
  final double z;

  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);

  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);

  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  Vec3 operator -() => Vec3(-x, -y, -z);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) => Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(x * x + y * y + z * z);

  @override
  bool operator ==(Object other) => other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vec3($x, $y, $z)';

}

// A 3x3 rotation, row-major. Hand-rolled rather than Matrix4: the projection
// needs a per-vertex divide against our own camera model anyway, so the 4x4
// machinery would earn nothing, and nine doubles are trivially testable.
class Mat3 {

  final double m00;
  final double m01;
  final double m02;
  final double m10;
  final double m11;
  final double m12;
  final double m20;
  final double m21;
  final double m22;

  const Mat3(this.m00, this.m01, this.m02, this.m10, this.m11, this.m12, this.m20, this.m21, this.m22);

  static const Mat3 identity = Mat3(1, 0, 0, 0, 1, 0, 0, 0, 1);

  static Mat3 rotX(double a) {
    final c = math.cos(a);
    final s = math.sin(a);
    return Mat3(1, 0, 0, 0, c, -s, 0, s, c);
  }

  static Mat3 rotY(double a) {
    final c = math.cos(a);
    final s = math.sin(a);
    return Mat3(c, 0, s, 0, 1, 0, -s, 0, c);
  }

  static Mat3 rotZ(double a) {
    final c = math.cos(a);
    final s = math.sin(a);
    return Mat3(c, -s, 0, s, c, 0, 0, 0, 1);
  }

  Vec3 apply(Vec3 v) => Vec3(
        m00 * v.x + m01 * v.y + m02 * v.z,
        m10 * v.x + m11 * v.y + m12 * v.z,
        m20 * v.x + m21 * v.y + m22 * v.z,
      );

  Mat3 operator *(Mat3 o) => Mat3(
        m00 * o.m00 + m01 * o.m10 + m02 * o.m20,
        m00 * o.m01 + m01 * o.m11 + m02 * o.m21,
        m00 * o.m02 + m01 * o.m12 + m02 * o.m22,
        m10 * o.m00 + m11 * o.m10 + m12 * o.m20,
        m10 * o.m01 + m11 * o.m11 + m12 * o.m21,
        m10 * o.m02 + m11 * o.m12 + m12 * o.m22,
        m20 * o.m00 + m21 * o.m10 + m22 * o.m20,
        m20 * o.m01 + m21 * o.m11 + m22 * o.m21,
        m20 * o.m02 + m21 * o.m12 + m22 * o.m22,
      );

  Mat3 get transposed => Mat3(m00, m10, m20, m01, m11, m21, m02, m12, m22);

  double get determinant =>
      m00 * (m11 * m22 - m12 * m21) - m01 * (m10 * m22 - m12 * m20) + m02 * (m10 * m21 - m11 * m20);

}

// Outward normal of each face, indexed by pip count - 1.
//
// A Western die is right-handed: 1, 2 and 3 run counter-clockwise around their
// shared corner, so with 1 toward the viewer and 2 up, 3 is on the left. Canvas
// y points down, which flips the visual handedness, so the algebraic form of
// that rule reads `n1.cross(n2) == -n3` here rather than `== n3`. There is a
// test for it, because the version that gets this backwards renders a die that
// looks entirely plausible until someone who knows dice looks at it.
const List<Vec3> kFaceNormals = [
  Vec3(0, 0, 1), // 1 — front
  Vec3(0, -1, 0), // 2 — up
  Vec3(-1, 0, 0), // 3 — left
  Vec3(1, 0, 0), // 4 — right
  Vec3(0, 1, 0), // 5 — down
  Vec3(0, 0, -1), // 6 — back
];

// Each face's own frame: [kFaceU] is "right" and [kFaceV] is "down" as seen from
// outside that face, and (u, v, n) is right-handed.
const List<Vec3> kFaceU = [
  Vec3(1, 0, 0),
  Vec3(1, 0, 0),
  Vec3(0, 0, 1),
  Vec3(0, 0, -1),
  Vec3(1, 0, 0),
  Vec3(-1, 0, 0),
];

const List<Vec3> kFaceV = [
  Vec3(0, 1, 0),
  Vec3(0, 0, 1),
  Vec3(0, 1, 0),
  Vec3(0, 1, 0),
  Vec3(0, 0, -1),
  Vec3(0, 1, 0),
];

// Pip positions in each face's own (u, v) frame, both in [-1, 1].
const List<List<Offset>> kPipLayouts = [
  [Offset.zero],
  [Offset(-0.45, -0.45), Offset(0.45, 0.45)],
  [Offset(-0.45, -0.45), Offset.zero, Offset(0.45, 0.45)],
  [Offset(-0.45, -0.45), Offset(0.45, -0.45), Offset(-0.45, 0.45), Offset(0.45, 0.45)],
  [Offset(-0.45, -0.45), Offset(0.45, -0.45), Offset.zero, Offset(-0.45, 0.45), Offset(0.45, 0.45)],
  [
    Offset(-0.45, -0.5),
    Offset(-0.45, 0),
    Offset(-0.45, 0.5),
    Offset(0.45, -0.5),
    Offset(0.45, 0),
    Offset(0.45, 0.5),
  ],
];

const double kPipRadius = 0.15;

// The eight cube corners.
const List<Vec3> kCubeVertices = [
  Vec3(-1, -1, -1),
  Vec3(1, -1, -1),
  Vec3(1, 1, -1),
  Vec3(-1, 1, -1),
  Vec3(-1, -1, 1),
  Vec3(1, -1, 1),
  Vec3(1, 1, 1),
  Vec3(-1, 1, 1),
];

/// The orientation that lands [face] toward the camera: the transpose of that
/// face's own (u, v, n) frame, which maps u -> +x, v -> +y and n -> +z.
///
/// Defining it as the inverse of the pip frame — rather than as six hand-written
/// Euler triples — is what makes every face land the same way up. 1, 4 and 5 are
/// symmetric under a quarter turn and don't care, but 2 and 3 are diagonals and
/// 6 is two columns of three: get the in-plane term wrong and a landed 6 lies on
/// its side. Here it cannot, and one pip-drawing routine serves all six.
Mat3 restRotation(int face) {
  final u = kFaceU[face - 1];
  final v = kFaceV[face - 1];
  final n = kFaceNormals[face - 1];
  return Mat3(u.x, u.y, u.z, v.x, v.y, v.z, n.x, n.y, n.z);
}

// How long a roll takes, on every screen showing it.
const int kDiceRollDurationMs = 1200;

// Camera distance in half-side units. The front face projects at k/(k-1) = 1.29
// and the back at k/(k+1) = 0.82, a 1.57 front-to-back ratio: enough perspective
// to read as a solid without going fisheye. Any k > sqrt(3) keeps every corner in
// front of the camera, which is what makes the perspective divide safe.
const double kCamera = 4.5;

// How far the die is turned away from square-on once it has landed.
//
// Without this a landed die shows exactly one face — geometrically correct, and
// it reads as a flat tile rather than as a cube, which is the one thing this
// widget is for. A face is visible when its normal clears 12.8 degrees (that is
// the `n.z * kCamera > 1` threshold), so both angles are comfortably past it: a
// landed die shows its rolled face plus the top and one side.
//
// The front face still wins [frontFaceOf] by a wide margin — 0.89 against 0.33
// for its nearest rival — which is what keeps the landing guarantee intact.
//
// Both are negative, which is what puts the eye above and to the right of the
// die. Positive angles are just as valid geometrically and show the underside,
// which reads as a die that is falling rather than one that has landed.
const double kPresentYaw = -0.35;
const double kPresentPitch = -0.31;

final Mat3 kPresentation = Mat3.rotY(kPresentYaw) * Mat3.rotX(kPresentPitch);

// Projected half-extent of a die at rest.
//
// Computed from the presentation tilt rather than from the front face alone, and
// the same for all six faces: [restRotation] is one of the cube's own symmetries,
// so it maps the cube onto itself and leaves the silhouette unchanged.
final double kRestExtent = _extentOf(projectedCube(kPresentation));

double _extentOf(List<Offset> projected) {
  var extent = 0.0;
  for (final q in projected) {
    final e = math.max(q.dx.abs(), q.dy.abs());
    if (e > extent) extent = e;
  }
  return extent;
}

// Peak amplitude of the settling rock, in radians. Bounded well under the 45 deg
// at which the front-most face would flip — see [diceOrientation].
const double kWobble = 0.14;

const double kWobbleTurns = 6.0;

// max of p^8 * (1 - p), at p = 8/9. Normalises the envelope so [kWobble] is the
// rock's actual peak rather than an arbitrary coefficient.
const double _wobbleEnvelopePeak = 0.04330493;

/// Milliseconds into the roll, clamped to the roll's own window.
///
/// The anchor is the *presenter's* wall clock and a web viewer reads its own, so
/// an anchor in the future is treated as a roll that already landed rather than
/// one that never starts — otherwise a viewer whose clock runs behind would sit
/// at p = 0 with its ticker spinning until the clock caught up. A null anchor is
/// a die that has never been rolled, which is likewise already at rest: that is
/// what keeps the catalog preview and the registry test from starting a ticker.
int diceElapsedMs(int? rolledAtEpochMs, int nowMs) {
  if (rolledAtEpochMs == null) return kDiceRollDurationMs;
  final elapsed = nowMs - rolledAtEpochMs;
  if (elapsed < 0 || elapsed > kDiceRollDurationMs) return kDiceRollDurationMs;
  return elapsed;
}

/// The die's orientation [elapsedMs] into a roll that lands on [face].
///
/// The landing is a guarantee by construction, not a limit that happens to be
/// reached: past the duration this *is* [restRotation], bit for bit. Before it,
/// everything that has to disappear is written as a multiple of (1 - p), which
/// is exactly 0.0 at p = 1 — which is also why easeOutCubic is spelled out here
/// instead of borrowed from Curves, and why the rock carries its own (1 - p)
/// factor rather than relying on sin(k * pi) to vanish. (It wouldn't: pi is
/// inexact, so sin(3 * pi) is -3.7e-16.)
Mat3 diceOrientation(int face, int rollSeed, int elapsedMs) {
  final rest = kPresentation * restRotation(face);
  if (elapsedMs >= kDiceRollDurationMs) return rest;

  final p = elapsedMs <= 0 ? 0.0 : elapsedMs / kDiceRollDurationMs;
  final r = 1 - p;
  final residual = r * r * r;

  // A short rock as the die settles, weighted to the very end of the roll where
  // the residual spin has already died away and there is something left to see.
  final envelope = kWobble * math.pow(p, 8) * r / _wobbleEnvelopePeak;
  final rockX = envelope * math.sin(2 * math.pi * kWobbleTurns * p);
  final rockZ = envelope * math.sin(2 * math.pi * kWobbleTurns * p + 1.1);

  final spin = spinFor(rollSeed);
  return Mat3.rotZ(residual * spin.z + rockZ) *
      Mat3.rotY(residual * spin.y) *
      Mat3.rotX(residual * spin.x + rockX) *
      rest;
}

/// A deterministic value in [0, 1048572] from a seed and a salt.
///
/// Spelled out rather than delegated to dart:math's seeded Random, which is
/// explicitly allowed to change its stream between Dart releases — the presenter
/// and a web viewer have to tumble the *same* die. Plain arithmetic only, with
/// every intermediate under 2^53: dart2js truncates `&`, `^` and `|` to 32 bits
/// while the VM does not, so a bitwise mixer would quietly diverge across
/// exactly the boundary this has to hold across.
int diceMix(int seed, int salt) {
  var h = (seed.abs() % 1048573) + salt * 7919 + 12345;
  h %= 1048573;
  h = (h * 3571 + 6151) % 1048573;
  // The squaring is the point of this line. Without it every step is affine in
  // the seed, so the whole mixer is — and since rollSeed advances by one per
  // roll, the output would walk by a constant and the tumble would visibly cycle
  // every ten throws. Squaring costs one multiply and stays exact: h is under
  // 2^20, so h * h is under 2^40.
  h = h * h % 1048573;
  h = (h * 8191 + 65537) % 1048573;
  return h;
}

double _unit(int seed, int salt) => diceMix(seed, salt) / 1048572.0;

/// Total angular travel per axis over the roll.
///
/// Deliberately not whole turns: whole turns would put the die at its rest pose
/// at p = 0, so it would show the answer before it had rolled and then snap into
/// a tumble.
Vec3 spinFor(int rollSeed) => Vec3(
      3 * math.pi + 2 * math.pi * _unit(rollSeed, 1),
      2 * math.pi + 2 * math.pi * _unit(rollSeed, 2),
      1 * math.pi + 1 * math.pi * _unit(rollSeed, 3),
    );

/// Perspective projection of a point in half-side units.
Offset projectUnit(Vec3 p) {
  final s = kCamera / (kCamera - p.z);
  return Offset(p.x * s, p.y * s);
}

/// Whether the eye sees the outside of the face whose rotated normal is [n].
///
/// The face plane is n.p == 1 and the eye sits at (0, 0, k), so the eye is
/// outside it exactly when k * n.z > 1. Note `> 1` and not `> 0`: the
/// orthographic test keeps faces that lean toward the camera plane but still
/// face away from the eye *point*, which shows up as a sliver of the wrong face
/// at grazing angles.
///
/// This is the same predicate as "the projected quad winds the right way", but
/// it is the one to use. Screen-space signed area needs a sign convention that
/// y-down inverts — a visually counter-clockwise polygon has a *negative* signed
/// area here — and getting that coin-flip wrong renders an inside-out die that
/// looks almost right. This version has no degenerate case on the silhouette and
/// hands back the normal the shading wants anyway.
bool isFrontFacing(Vec3 n) => n.z * kCamera > 1;

/// Pixels per half-side, so the die exactly fills [halfBox] at rest and never
/// leaves it while tumbling.
///
/// A tumbling cube's bounding box swells to about 1.46x its resting one on all
/// four sides — that is the cube itself, not a toss; a die spinning in place does
/// it. Nothing in the render path clips the overflow (CustomPaint does not, and
/// FittedBox with BoxFit.fill has none of its own), so a die drawn to fill its
/// box at rest would quietly paint over its neighbours for a second on every
/// roll, with no error to notice.
///
/// Reserving the headroom in naturalSize would be worse: naturalSize also drives
/// the hit test, the arrange overlay and the header-bar standoff, so the die
/// would carry a selection box a third larger than itself forever. Shrinking to
/// fit the worst case instead leaves it at 69% of its box at rest.
///
/// So the fit follows the orientation. Containment is then true by construction,
/// the resting size is an exact constant, and the dip to ~68% mid-roll reads as
/// the die being thrown away from the camera and coming back — the toss, for
/// free, with nothing to budget and nothing to clamp.
double fitScale(List<Offset> projected, double halfBox) {
  var extent = kRestExtent;
  for (final q in projected) {
    final e = math.max(q.dx.abs(), q.dy.abs());
    if (e > extent) extent = e;
  }
  return halfBox / extent;
}

/// The eight cube corners under [rotation], projected at unit scale.
List<Offset> projectedCube(Mat3 rotation) => [
      for (final v in kCubeVertices) projectUnit(rotation.apply(v)),
    ];

/// The face showing most directly toward the camera, as a pip count.
int frontFaceOf(Mat3 rotation) {
  var best = 1;
  var bestZ = -2.0;
  for (var i = 0; i < 6; i++) {
    final z = rotation.apply(kFaceNormals[i]).z;
    if (z > bestZ) {
      bestZ = z;
      best = i + 1;
    }
  }
  return best;
}

/// The four projected corners of [faceIndex] (0-based), in order.
///
/// [inset] pulls the corners in within the face's own plane before projecting,
/// so the shrink stays perspective-correct rather than being a screen-space
/// approximation. Drawing the faces inset over a filled silhouette is what gives
/// the die its bevelled edge — and, incidentally, hides the antialiasing hairline
/// that adjacent quads would otherwise leave along every shared edge.
List<Offset> faceQuad(int faceIndex, Mat3 rotation, double scale, {double inset = 0}) {
  final n = kFaceNormals[faceIndex];
  final u = kFaceU[faceIndex];
  final v = kFaceV[faceIndex];
  final e = 1 - inset;
  return [
    for (final (du, dv) in const [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)])
      projectUnit(rotation.apply(n + u * (du * e) + v * (dv * e))) * scale,
  ];
}

// How many segments a pip is drawn with. Past the point of visible faceting on a
// pip a few pixels across.
const int kPipSegments = 16;

/// One pip as a projected polygon in the face's own frame.
///
/// A polygon rather than a circle at the projected centre, because the divide is
/// what turns it into the correct ellipse — foreshortened *and* pushed off-centre
/// on a tilted face. A drawCircle stays circular under every orientation, which
/// is precisely the tell that gives a fake 3D die away.
List<Offset> pipPolygon(int faceIndex, Offset centre, Mat3 rotation, double scale) {
  final n = kFaceNormals[faceIndex];
  final u = kFaceU[faceIndex];
  final v = kFaceV[faceIndex];
  return [
    for (var i = 0; i < kPipSegments; i++)
      () {
        final a = i * 2 * math.pi / kPipSegments;
        final du = centre.dx + kPipRadius * math.cos(a);
        final dv = centre.dy + kPipRadius * math.sin(a);
        return projectUnit(rotation.apply(n + u * du + v * dv)) * scale;
      }(),
  ];
}

// Key light up and to the left, and mostly toward the eye. Weighted toward the
// eye rather than straight down from above because the face the die landed on is
// the one being read: a light directly overhead lights the *top* face brightest
// and leaves the result sitting in half shadow.
const Vec3 kLight = Vec3(-0.30, -0.55, 0.78);

/// Flat-shading factor for a face whose rotated normal is [n].
double shadeOf(Vec3 n) => 0.62 + 0.38 * math.max(0, n.dot(kLight));

/// The seed a roll should carry, given the one before it.
///
/// Always advances, so two rolls in the same millisecond that happen to land the
/// same face still differ. Without that, the new config can equal the old one;
/// isWidgetRuntimeOnlyChange requires old != new, declines it, and the change
/// drops into the undoable branch as an *empty* history entry — reachable just by
/// double-tapping the die.
int nextRollSeed(int current) => (current + 1) % 0x100000;

/// Draws a face. Presenter-only, so an unseeded Random is fine here — only the
/// tumble has to reproduce across devices, and that goes through [diceMix].
int drawFace(math.Random random) => 1 + random.nextInt(6);

/// Draws a value in [min, max] inclusive.
int drawValue(math.Random random, int min, int max) =>
    max <= min ? min : min + random.nextInt(max - min + 1);

// How many values a number die flashes through before settling.
const int kNumberDiceSteps = 14;

// The number die's tile, as a fraction of its box, at rest and at the peak of its
// roll; and how far it rocks. The three are budgeted together so the tile never
// leaves its box — a tilted square reaches (cos + sin) of its half-width, so the
// worst case is kNumberDiceRest * (1 + kNumberDicePop) * (cos t + sin t), and
// there is a test pinning it under 1.
const double kNumberDiceRest = 0.80;
const double kNumberDicePop = 0.12;
const double kNumberDiceTilt = 0.10;
const double kNumberDiceTiltTurns = 3.0;

/// The tile's size (as a fraction of its box) and rock [elapsedMs] into a roll.
///
/// Same discipline as [diceOrientation]: everything that has to be gone at the
/// landing is a multiple of (1 - p), and past the duration the pose is the
/// resting one exactly.
({double scale, double tilt}) numberDicePoseAt(int elapsedMs) {
  if (elapsedMs >= kDiceRollDurationMs) return (scale: kNumberDiceRest, tilt: 0);

  final p = elapsedMs <= 0 ? 0.0 : elapsedMs / kDiceRollDurationMs;
  final r = 1 - p;
  final residual = r * r * r;
  return (
    scale: kNumberDiceRest * (1 + kNumberDicePop * residual),
    tilt: kNumberDiceTilt * residual * math.sin(2 * math.pi * kNumberDiceTiltTurns * p),
  );
}

/// The number showing [elapsedMs] into a roll that lands on [value].
///
/// Integers all the way down — the cycling values are drawn from the seed by step
/// index rather than sampled off a curve — so "lands on value" is exact by
/// construction on every mirror, with no epsilon anywhere.
int numberDiceValueAt(int min, int max, int value, int rollSeed, int elapsedMs) {
  if (elapsedMs >= kDiceRollDurationMs) return value;

  final p = elapsedMs <= 0 ? 0.0 : elapsedMs / kDiceRollDurationMs;
  final r = 1 - p;
  final step = ((1 - r * r * r) * kNumberDiceSteps).floor();
  if (step >= kNumberDiceSteps) return value;

  final span = max - min + 1;
  if (span <= 1) return min;
  return min + diceMix(rollSeed, 17 + step) % span;
}

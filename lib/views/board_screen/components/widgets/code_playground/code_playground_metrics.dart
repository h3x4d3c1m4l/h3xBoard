/// Every dimension the Code Playground lays out with, in canvas units.
///
/// The size is **fixed**, not derived from the content. `ManipulableBoardWidget`
/// reads `naturalSize` before layout and stretches the widget to it with
/// `BoxFit.fill`, so a size that disagrees with what gets built smears the glyphs
/// rather than clipping. A code editor that grew with its line count would change
/// size on every keystroke — so instead the panes are fixed and scroll inside.
///
/// Canvas units, not pixels: the 1920x1080 canvas is scaled into the board, so
/// everything here shrinks by a third or more on a small window. Code at 20 units
/// lands near 13px at a typical scale, which is why it looks oversized written
/// down and reads correctly on a classroom display.
library;

/// Matches the numeric teaching widgets, so the family sits together on a board.
/// At roughly 69 monospace columns it fits the line lengths a lesson actually
/// uses without pushing the widget past half the canvas.
const double kCardWidth = 940;
const double kCardPadH = 24;
const double kCardPadV = 20;
const double kCardRadius = 16;

const double kSectionGap = 14;

/// Language picker on the left, Run/Stop on the right.
const double kToolbarHeight = 56;

/// About sixteen lines of code at the editor's type size. Enough for a worked
/// example without the widget dominating the board; longer programs scroll.
const double kEditorHeight = 440;

/// Input and output share a row, so the widget's height never depends on whether
/// a program happens to use `input()`.
const double kIoHeight = 200;

/// Input takes a third: it is usually a couple of short lines, while output is
/// the thing a class is actually reading.
const int kInputFlex = 1;
const int kOutputFlex = 2;
const double kIoGap = 12;

const double kPanelRadius = 10;
const double kPanelPad = 12;
const double kPanelLabelHeight = 18;
const double kPanelLabelGap = 8;

/// Type sizes, in canvas units.
const double kCodeFontSize = 20;
const double kOutputFontSize = 18;
const double kToolbarFontSize = 15;
const double kLabelFontSize = 12;

const double kCardHeight = kCardPadV * 2 +
    kToolbarHeight +
    kSectionGap +
    kEditorHeight +
    kSectionGap +
    kIoHeight;

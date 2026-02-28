# SynEdit — VCL Styles Support (In Progress)

## Task
Add Delphi VCL styles support to all visual components. Work split across multiple sessions.

## Status
- [x] `Source/SynDWrite.pas` — D2D1ColorF routes through GetSystemColor; ResetRenderTarget nil-safe
- [x] `Source/SynEdit.pas` — TextHint, WhitespaceColor, FGColor, CMStyleChanged
- [x] `Source/SynEditPrintPreview.pas` — GDI paint + CMStyleChanged handler
- [x] `Source/SynAutoCorrectEditor.pas` — GDI separator line
- [x] `Source/SynEditOptionsDialog.pas` — GDI color swatches

## Key Design Note
`StyleServices.GetSystemColor(clWindow)` intentionally stays **light** in Windows11 Modern Dark
(the style keeps text-editing areas white for contrast). Standard `TEdit` gets dark via
`GetStyleColor(scEdit)` in its style hook — SynEdit must do the same.

Fixes in `WhitespaceColor` and `FGColor` use `GetStyleColor(scEdit)` / `GetStyleFontColor(sfEditBoxTextNormal)`
when the stored color is still a system-color constant (`Color < 0`) and a non-system VCL style is active.

## Already styled (no changes needed)
- `SynCompletionProposal.pas` — extensive StyleServices use throughout
- `SynEditScrollBars.pas` — full StyleServices via custom style hook

## Version Guard Rule
VCL Styles introduced in **Delphi XE2 (CompilerVersion 23)**.
All new `StyleServices` call-sites and new `Vcl.Themes` unit additions must be guarded:
```pascal
{$IF CompilerVersion >= 23}
  ... style-aware code ...
{$ELSE}
  ... fallback ...
{$IFEND}
```

---

## Change 1: `Source/SynDWrite.pas` (Core fix — most impact)

This is the most important change. Every Direct2D color in SynEdit passes through `D2D1ColorF()`.
Routing it through `StyleServices.GetSystemColor()` makes the entire editor style-aware in one hit
(background, gutter, gradients, right edge, etc.).

**Add to implementation `uses` block (line ~1549):**
```pascal
{$IF CompilerVersion >= 23}
Vcl.Themes,
{$IFEND}
```

**Update `D2D1ColorF()` (line 1563):**
```pascal
function D2D1ColorF(const AColor: TColor; Opacity: Single): TD2D1ColorF;
var
  RGB: Cardinal;
const
  CScale = 1 / 255;
begin
{$IF CompilerVersion >= 23}
  RGB := ColorToRGB(StyleServices.GetSystemColor(AColor));
{$ELSE}
  RGB := ColorToRGB(AColor);
{$IFEND}
  Result.r := TColors(RGB).R * CScale;
  Result.g := TColors(RGB).G * CScale;
  Result.b := TColors(RGB).B * CScale;
  Result.a := Opacity;
end;
```

---

## Change 2: `Source/SynEdit.pas`

### 2a. TextHint fallback color (line ~3147, inside `PaintTextLines`)
```pascal
// Before:
HintColor := clGray;
// After:
{$IF CompilerVersion >= 23}
HintColor := clGrayText;
{$ELSE}
HintColor := clGray;
{$IFEND}
```
`clGray` is fixed RGB, not a system color. `clGrayText` is a system color resolved by StyleServices.

### 2b. CMStyleChanged handler — flush D2D brush cache on style change

In `private` section of `TCustomSynEdit` (near other CM_ handlers, line ~232):
```pascal
{$IF CompilerVersion >= 23}
procedure CMStyleChanged(var Message: TMessage); message CM_STYLECHANGED;
{$IFEND}
```

In implementation (near other CM/WM handlers):
```pascal
{$IF CompilerVersion >= 23}
procedure TCustomSynEdit.CMStyleChanged(var Message: TMessage);
begin
  // Do NOT call inherited. TWinControl.CMStyleChanged can trigger RecreateWnd
  // via VCL's style hook infrastructure, which creates a new TSynDropTarget and
  // registers it with OLE. If the window is destroyed during app shutdown without
  // WM_DESTROY being dispatched, OLE retains the unreleased IDropTarget reference
  // causing a memory leak. TCustomSynEdit is fully custom-drawn, so inherited
  // would only Invalidate — which we do explicitly below.
  TSynDWrite.ResetRenderTarget;  // clears cached D2D solid brushes
  Invalidate;
end;
{$IFEND}
```

---

## Change 3: `Source/SynEditPrintPreview.pas`
(`Vcl.Themes` already imported unconditionally)

### 3a. Update `PaintPaper()` (lines ~263–308)

| Line | Before | After (inside `{$IF CompilerVersion >= 23}`) |
|------|--------|------|
| ~273 | `Brush.Color := Self.Color` | `Brush.Color := StyleServices.GetSystemColor(Self.Color)` |
| ~275 | `Pen.Color := clBlack` | `Pen.Color := StyleServices.GetSystemColor(clWindowText)` |
| ~298 | `Brush.Color := clDkGray` | `Brush.Color := StyleServices.GetSystemColor(clGrayText)` |

Note: `clBlack` and `clDkGray` are not system color constants so `GetSystemColor` alone wouldn't
remap them — use `clWindowText` and `clGrayText` as the style-aware equivalents.

Each change wrapped individually:
```pascal
{$IF CompilerVersion >= 23}
Brush.Color := StyleServices.GetSystemColor(Self.Color);
{$ELSE}
Brush.Color := Self.Color;
{$IFEND}
```

### 3b. CMStyleChanged handler

In class declaration (protected or private):
```pascal
{$IF CompilerVersion >= 23}
procedure CMStyleChanged(var Message: TMessage); message CM_STYLECHANGED;
{$IFEND}
```

In implementation:
```pascal
{$IF CompilerVersion >= 23}
procedure TSynEditPrintPreview.CMStyleChanged(var Message: TMessage);
begin
  inherited;
  Invalidate;
end;
{$IFEND}
```

---

## Change 4: `Source/SynAutoCorrectEditor.pas`

### 4a. Add to `uses` (line ~38):
```pascal
{$IF CompilerVersion >= 23}
  Vcl.Themes,
{$IFEND}
```

### 4b. Update `FormPaint` separator line (line ~219):
```pascal
{$IF CompilerVersion >= 23}
Pen.Color := StyleServices.GetSystemColor(clWindowText);
{$ELSE}
Pen.Color := clBlack;
{$IFEND}
```

---

## Change 5: `Source/SynEditOptionsDialog.pas`

### 5a. Add to `uses` (line ~37):
```pascal
{$IF CompilerVersion >= 23}
  Vcl.Themes,
{$IFEND}
```

### 5b. Update `FormCreate` color swatch border (line ~536):
```pascal
{$IF CompilerVersion >= 23}
B.Canvas.Pen.Color := StyleServices.GetSystemColor(clWindowText);
{$ELSE}
B.Canvas.Pen.Color := clBlack;
{$IFEND}
```

---

## Verification
1. Compile all packages — zero new warnings/errors
2. Apply a VCL style (e.g. "Windows11 Modern Dark") in a demo app
3. Editor background, gutter, and gradient should match the style's window/button-face colors
4. Print preview background should change with the style
5. AutoCorrect editor separator line visible against styled listbox background
6. Switching styles at runtime causes proper immediate redraw

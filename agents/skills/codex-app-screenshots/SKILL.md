---
name: codex-app-screenshots
description: >
  Use when generating App Store or Google Play marketing screenshots via AI image generation.
  Generates complete screenshot compositions (background, device frame, headline, decorations)
  using Codex image_gen without requiring a web editor or dev server.
  Triggers on: app store screenshots, play store screenshots, marketing screenshots,
  generate app screenshots, codex screenshots, app store images.
  JA: アプリストアスクリーンショット生成, ストア画像生成, マーケティングスクリーンショット
---

# App Store Screenshots Generator (Codex Image Gen)

## Overview

Generate production-quality App Store and Google Play marketing screenshots using
Codex's `image_gen` tool. No Next.js editor, no dev server, no browser required.

This skill replaces the interactive web editor approach with AI image generation:
1. Gather input from user (app info, features, style preference)
2. Construct detailed image generation prompts from design rules + style specs
3. Delegate to Codex via `codex:rescue` for image generation
4. Review, iterate, and resize to exact App Store dimensions

### When to Use This vs the Web Editor Skill

| Scenario | Use this skill |
|----------|----------------|
| Rapid mockup / concept exploration | Yes |
| No screenshots yet, need full compositions | Yes |
| Want AI-generated illustrations / mascots / 3D objects | Yes |
| Need pixel-perfect text positioning | Consider web editor |
| Need to composite real app screenshots into frames | Possible (see Step 4) |

## Core Principle

**Screenshots are advertisements, not documentation.** Every screenshot sells one idea.
You're selling a *feeling*, an *outcome*, or killing a *pain point*.

## Step 1: Gather Input

Ask the user these before generating:

### Required

1. **App name** -- "What's the app called?"
2. **App description** -- "What does the app do? One sentence."
3. **Feature list** -- "List your app's features in priority order. What's the #1 thing?"
4. **Style direction** -- Offer choices:
   - Pick a named deep-spec style (see `style-prompts.md` for index)
   - Describe a custom vibe (warm/organic, dark/moody, clean/minimal, bold/colorful)
   - Reference apps they like the style of
5. **App screenshots** -- "Do you have actual screenshots (PNGs) of your app?"
   - If yes: we'll composite them into generated frames
   - If no: we'll generate representative UI inside the phone frames

### Optional

6. **Target stores** -- Apple App Store, Google Play, or both?
7. **Number of slides** -- Apple allows up to 10, Google Play up to 8
8. **Brand colors / font** -- Custom palette beyond style presets
9. **Localization** -- Which languages? (default: English only)
10. **Additional instructions** -- Anything specific

## Step 2: Select and Load Style

When the user names a style:
1. Read `style-prompts/_QUALITY_BAR.md` first (universal rules)
2. Read the matching deep spec file from `style-prompts/`
3. Extract: palette, typography description, layout rhythm, decoration rules, copy tone

Available styles (see `style-prompts.md` for full index):

| # | Style | Vibe |
|---|-------|------|
| 01 | Retro Rubberhose Mascot | 1930s cartoon, cream + mustard, white-gloved mascot |
| 02 | Moody Curated Dating | Dim lifestyle photography, white serif, exclusive |
| 03 | Paper Sticker Skeuomorphic | Cork-board, paper-cutout, marker handwriting |
| 04 | Dreamy Pastel Couples | Cotton-candy gradient, 3D globe, kawaii |
| 05 | Hand-Drawn Editorial Tasks | Navy + cream + coral, script accent, tilted phones |
| 06 | Glossy 3D K-Beauty Creator | Deep purple gradient, glossy chrome, kawaii ghost |

If the user describes a custom style, fall back to the General Visual Design Principles
(Section 8) and pick the closest named style as a starting reference.

## Step 3: Generate Images via Codex

For each slide, construct a prompt and delegate to Codex.

### Prompt Construction

Each image generation prompt MUST include these layers, in order:

```
1. FORMAT & SIZE
   "Create a high-fidelity raster App Store screenshot at {width}x{height} pixels,
    portrait orientation."

2. COMPOSITION STRUCTURE
   Describe the layout type (hero, device-bottom, device-top, etc.)
   and the spatial arrangement of elements.

3. BACKGROUND
   Exact colors, gradients, textures from the style spec.

4. DEVICE FRAME
   iPhone/Android frame description with exact proportions.
   (See "Device Frame Prompt Specifications" below)

5. SCREEN CONTENT
   What appears inside the phone screen.
   If user has screenshots: "The phone screen displays [description of their app]"
   If no screenshots: describe representative UI.

6. HEADLINE TEXT
   Exact text, positioning, font style, size relative to canvas,
   emphasis word treatment. CRITICAL: spell out the exact text.

7. DECORATIVE ELEMENTS
   Squiggles, stickers, shadows, mascots, etc. from the style spec.

8. WHAT NOT TO DO
   Include 3-5 "do not" rules from the style's "What this style is NOT" section.
```

### Delegation Pattern

Use `codex:rescue` to delegate image generation to Codex:

```
Generate an App Store screenshot with these specifications:

[Constructed prompt from above]

Save the output to: /tmp/app-screenshots/{app-name}/slide-{N}.png
```

### Size Strategy

Codex image_gen supports specific sizes. Generate at the closest supported size,
then resize with ImageMagick in Step 5.

| Target | Generate at | Aspect ratio |
|--------|------------|--------------|
| iPhone (1320x2868) | 1024x1536 | ~1:1.5 (close to 1:2.17, will crop) |
| iPad (2064x2752) | 1024x1536 | Resize needed |
| Android (1080x1920) | 1024x1536 | Close match (9:16 vs 2:3) |
| Feature Graphic (1024x500) | 1536x1024 | Crop to 1024x500 |

**Better approach if API supports custom sizes:** Request exact dimensions directly.
Test with the target size first; fall back to closest supported size if rejected.

### Batch Generation

Generate all slides for a deck in sequence:
1. Generate slide 1 (hero) first -- this sets the visual tone
2. Show to user for approval
3. If approved, generate remaining slides maintaining consistency
4. If not, iterate on slide 1 until the style is right

## Step 4: Compositing Real Screenshots (Optional)

If the user has actual app screenshots and wants them inside the phone frames:

### Option A: Describe and Generate (Recommended)
Describe the app's UI in the prompt so image_gen renders a representative version.
This produces the most cohesive result.

### Option B: Post-Composite with ImageMagick
1. Generate the full screenshot WITHOUT phone screen content (use a solid dark placeholder)
2. Overlay the user's screenshot into the phone frame area using ImageMagick:

```bash
# Calculate phone screen position (based on device-frames.tsx measurements)
# iPhone screen: left=5.08%, top=2.21%, width=89.82%, height=95.59%
# On a 1024x1536 image:
SCREEN_X=$((1024 * 508 / 10000))   # ~52px
SCREEN_Y=$((1536 * 221 / 10000))   # ~34px
SCREEN_W=$((1024 * 8982 / 10000))  # ~920px
SCREEN_H=$((1536 * 9559 / 10000))  # ~1468px

magick composite \
  -geometry "${SCREEN_W}x${SCREEN_H}+${SCREEN_X}+${SCREEN_Y}" \
  user-screenshot.png \
  generated-frame.png \
  output.png
```

### Option C: Codex Image Edit
If Codex supports image editing, provide the generated screenshot and ask it to
replace the phone screen content with the user's actual screenshot.

## Step 5: Resize to App Store Dimensions

After generation, resize to all required export sizes.

### Required Sizes

**iPhone (Apple App Store):**
| Label | Size |
|-------|------|
| 6.9" | 1320 x 2868 |
| 6.5" | 1284 x 2778 |
| 6.3" | 1206 x 2622 |
| 6.1" | 1125 x 2436 |

**iPad (Apple App Store):**
| Label | Size |
|-------|------|
| 13" | 2064 x 2752 |
| 12.9" Pro | 2048 x 2732 |

**Android Phone (Google Play):**
| Label | Size |
|-------|------|
| Phone | 1080 x 1920 |

**Android Tablet (Google Play):**
| Label | Size |
|-------|------|
| 7" Portrait | 1200 x 1920 |
| 7" Landscape | 1920 x 1200 |
| 10" Portrait | 1600 x 2560 |
| 10" Landscape | 2560 x 1600 |

**Feature Graphic (Google Play):**
| Label | Size |
|-------|------|
| Banner | 1024 x 500 |

### Resize Script

```bash
#!/bin/bash
# resize-screenshots.sh -- Resize generated screenshots to all App Store sizes
# Usage: ./resize-screenshots.sh <input-dir> <output-dir> <device>

INPUT_DIR="$1"
OUTPUT_DIR="$2"
DEVICE="${3:-iphone}"

mkdir -p "$OUTPUT_DIR"

case "$DEVICE" in
  iphone)
    SIZES=("1320x2868" "1284x2778" "1206x2622" "1125x2436")
    LABELS=('6.9"' '6.5"' '6.3"' '6.1"')
    ;;
  ipad)
    SIZES=("2064x2752" "2048x2732")
    LABELS=('13"' '12.9"')
    ;;
  android)
    SIZES=("1080x1920")
    LABELS=("phone")
    ;;
  feature-graphic)
    SIZES=("1024x500")
    LABELS=("banner")
    ;;
esac

for file in "$INPUT_DIR"/*.png; do
  base=$(basename "$file" .png)
  for i in "${!SIZES[@]}"; do
    size="${SIZES[$i]}"
    label="${LABELS[$i]}"
    outdir="$OUTPUT_DIR/$size"
    mkdir -p "$outdir"
    magick "$file" -resize "$size^" -gravity center -extent "$size" "$outdir/${base}.png"
    echo "  -> $outdir/${base}.png ($label)"
  done
done
```

Run after generation:
```bash
chmod +x resize-screenshots.sh
./resize-screenshots.sh /tmp/app-screenshots/myapp /tmp/app-screenshots/myapp/export iphone
```

## Step 6: Quality Checks

Run through these before declaring done (from _QUALITY_BAR.md, adapted for image gen):

### Auto-Reject Checks
- [ ] Any text unreadable or garbled? (AI image gen text quality check)
- [ ] Phone smaller than ~65% of canvas height?
- [ ] Empty band wider than ~22% of canvas height?
- [ ] Headline text failing contrast against background?
- [ ] Any illustrated element looking like clipart (flat, no shadow, no texture)?
- [ ] Two adjacent slides using the same layout?
- [ ] Missing decorative elements that the style requires?

### Thumbnail Test (Mandatory)
Mentally shrink each slide to ~220px wide. Answer:
1. What style is this?
2. What does the app do?
3. Why should I tap it?

If you can't answer all three, the slide needs work.

### Text Quality Gate
AI image generation often struggles with text rendering.
If text is garbled or poorly rendered:
1. **Option A**: Regenerate with simplified text (fewer words, larger size)
2. **Option B**: Generate without text, add text overlay via ImageMagick:

```bash
magick generated.png \
  -font "Inter-Bold" -pointsize 96 \
  -fill "#FFFFFF" -gravity North \
  -annotate +0+200 "Your Headline Here" \
  output-with-text.png
```

3. **Option C**: Accept minor imperfections for mockup/concept phase

## Step 7: Iteration

After showing results to the user:
- "Want to adjust the style?" -> Modify prompt, regenerate
- "Change the headline?" -> Update text in prompt, regenerate that slide
- "Different layout?" -> Switch layout type in prompt, regenerate
- "More/fewer decorations?" -> Adjust decoration density in prompt
- "Happy with it?" -> Run resize script, deliver final export bundle

## Visual Design Principles

These rules apply regardless of style. They come from studying the best
App Store screenshots in the wild.

### 1. Background is a designed surface -- never plain white
Use a saturated color block, warm cream/off-white, dark navy, or gradient.
The background must read as intentional, not default.

### 2. Headlines dominate
The headline occupies roughly the top 30-40% of the canvas.
Must be readable at thumbnail size.

### 3. Mixed emphasis inside the headline
One word styled differently: contrast color, italic script, heavier weight,
or hand-drawn underline. Flat single-color headlines look weak.

### 4. Decorative accents are the rule
Hand-drawn squiggles, sparkles, label badges, floating widget chips.
A bare phone on a bare background with a bare headline is amateur output.

### 5. Phone framing varies across the deck
Three common framings:
- Bezelless / minimal frame (modern, legible)
- Tilted floating phone with soft shadow (advertorial)
- Full device with visible bezel, dead-center (editorial, premium)
Mix at least two framings across the deck.

### 6. Proof anchors the hero only
Award badges, press quotes, star counts -- concentrate on slide 1 only.

### 7. Density inside the phone, sparsity outside
Dense product UI inside the phone. One headline + one visual outside.

### 8. Break the phone parade
Every 2-3 slides, drop the phone and use a different hero element:
3D object, lifestyle photo, mascot illustration, typographic feature wall.

### 9. Last slide pattern
Either a feature wall (vertical list of features as big type)
or a phone mosaic (multiple mini-screenshots in a grid).

### 10. Thumbnail test
Shrink to ~160px wide. Can you read the headline? Can you tell what the
app does in under a second?

## Device Frame Prompt Specifications

Use these specifications when describing device frames in image generation prompts.

### iPhone Frame
```
Modern iPhone with slim bezels. The device frame is a dark titanium/space gray
with rounded corners (outer radius ~52-56px at full size). The screen area
fills approximately 90% width and 96% height of the device body. Screen corners
have ~36-42px inner radius. The overall aspect ratio of the device is 1022:2082
(approximately 1:2.04). The phone should occupy 68-82% of the canvas vertical
height. Bottom of the phone may bleed off the canvas edge.
```

### Android Phone Frame
```
Modern Android phone with minimal bezels. Aspect ratio 9:19.5. Dark frame with
subtle metallic gradient (dark gray to near-black). Small centered camera notch
at top (3% width, 1.4% height, circular). Screen area: 93% width, 96% height,
offset 3.5% from left, 2% from top. Rounded corners at 8%/4% (horizontal/vertical).
```

### iPad Frame
```
Modern iPad with uniform thin bezels. Aspect ratio 770:1000. Space gray frame
with subtle metallic finish. Small centered camera dot at top (0.9% width).
Screen area: 92% width, 94.4% height, offset 4% from left, 2.8% from top.
Rounded corners at 5%/3.6%.
```

## Copy Coaching

### Iron Rules
1. **One idea per headline.** Never join two things with "and."
2. **Short, common words.** 1-2 syllables. No jargon.
3. **3-5 words per line.** Readable at thumbnail size.
4. **Line breaks are intentional.**

### Three Approaches
| Type | What it does | Example |
|------|-------------|---------|
| Paint a moment | You picture yourself doing it | "Check your coffee without opening the app." |
| State an outcome | What your life looks like after | "A home for every coffee you buy." |
| Kill a pain | Name a problem and destroy it | "Never waste a great bag of coffee." |

### Narrative Arc
| Slot | Purpose |
|------|---------|
| #1 | Hero / Main Benefit -- the ONLY slide most people see |
| #2 | Differentiator -- what makes the app unique |
| #3 | Ecosystem -- widgets, watch, extensions (skip if N/A) |
| #4+ | Core Features -- one per slide, most important first |
| 2nd-to-last | Trust Signal -- "made for people who [X]" |
| Last | Feature wall or phone mosaic |

### Layout Types
Vary across slides. Never repeat the same layout twice in a row.
- `hero` -- centered headline + bottom-anchored device
- `device-bottom` -- headline top, device bottom
- `device-top` -- device above, caption below
- `two-devices` -- back + front phones layered
- `no-device` -- big standalone headline (use sparingly)
- `split-landscape` -- caption left + device right (tablet landscape)
- `feature-graphic` -- Play Store banner (1024x500)

## Example Prompt (Hand-Drawn Editorial Style, Slide 1)

```
Create a high-fidelity raster App Store marketing screenshot at 1024x1536 pixels,
portrait orientation.

COMPOSITION: Hero layout. Headline occupies the top 35% of the canvas.
A single iPhone is positioned bottom-right, tilted -12 degrees (leaning left),
with its bottom 25% bleeding off the canvas edge.

BACKGROUND: Solid deep navy #1B2336, with a very subtle 3% monochromatic noise
grain overlay for a printed-poster texture. No gradients.

DEVICE FRAME: Modern iPhone with slim dark titanium bezels, rounded corners.
The phone occupies approximately 75% of the canvas height. Warm-tinted soft
drop shadow beneath: rgba(8,12,30,0.55) long shadow + rgba(0,0,0,0.35) contact shadow.

SCREEN CONTENT: Dark mode task list UI (#0E1018 background). Show 4-5 task items
with rounded square checkboxes, white task titles, gray due dates. One checkbox
filled with coral #F26A50 and a white checkmark. A search bar at top with
translucent dark surface.

HEADLINE: Left-aligned, starting 18% from the top, 5% from left edge.
Line 1: "The one" in clean medium-weight sans-serif (Inter Medium style), white #FFFFFF, ~76pt
Line 2: "app that fits" in the same sans-serif, white, ~76pt
Line 3: "your whole day" in warm hand-drawn brush script font (like Caveat Bold),
coral #F26A50, ~84pt, rotated +3 degrees, with a hand-drawn wavy underline
beneath in coral, 5px stroke, round caps, 2-3 gentle waves.

SUBHEADLINE: Below the main headline, 24pt, color #B8C0D3, max width 60% of canvas.
Text: "From quick thoughts on the go to big team projects."

WORDMARK: "TaskApp" in lowercase, top-left corner, white #FFFFFF, 32pt, Inter Medium.

DECORATIONS: Hand-drawn SVG-style doodle elements in coral #F26A50:
- A wavy underline beneath "your whole day" (described above)
- A small 5-point star in coral, upper-right area, ~40px
- A short squiggly curl near the upper-right corner, 3 loops, coral, 4px stroke

DO NOT:
- Do not use gradients on the background (solid color only)
- Do not render the phone upright (must be tilted)
- Do not use serif fonts
- Do not use emojis
- Do not add a CTA button or "Download now" text
- Do not use bright saturated neon colors
- Do not make the headline all-caps
```

## Workflow Summary

```
User: "Generate App Store screenshots for my app"
  |
  v
Step 1: Gather input (app name, features, style)
  |
  v
Step 2: Load style spec (read _QUALITY_BAR.md + style file)
  |
  v
Step 3: For each slide:
  |   a. Construct prompt (format + composition + bg + frame + screen + headline + decorations)
  |   b. Delegate to Codex via codex:rescue
  |   c. Review generated image
  |   d. If text is garbled -> overlay text via ImageMagick OR regenerate
  |   e. Show to user for approval
  |
  v
Step 4 (optional): Composite real screenshots into phone frames
  |
  v
Step 5: Resize to all required App Store dimensions
  |
  v
Step 6: Quality checks (auto-reject list + thumbnail test)
  |
  v
Step 7: Iterate or deliver final bundle
```

## File Output Structure

```
/tmp/app-screenshots/{app-name}/
  raw/                          # Generated images (before resize)
    slide-01-hero.png
    slide-02-differentiator.png
    slide-03-feature.png
    ...
  export/
    ios/
      iphone/
        1320x2868/
          01-hero.png
          02-differentiator.png
          ...
        1284x2778/
          ...
      ipad/
        2064x2752/
          ...
    android/
      phone/
        1080x1920/
          ...
      feature-graphic/
        1024x500/
          ...
```

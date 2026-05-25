// Design token extraction script for browser injection.
// Execute via: cat this-file.js | agent-browser eval --stdin
//
// Returns JSON string with: colors, fonts, spacing, animations, title

(function () {
  function rgbToHex(rgb) {
    if (!rgb || rgb === "transparent") return null;
    if (rgb.startsWith("#")) return rgb;
    const match = rgb.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    if (!match) return null;
    return (
      "#" +
      [match[1], match[2], match[3]]
        .map((x) => parseInt(x).toString(16).padStart(2, "0"))
        .join("")
    );
  }

  const selectors = [
    "body",
    "header",
    "main",
    "footer",
    "nav",
    "section",
    "article",
    "button",
    "a",
    "h1",
    "h2",
    "h3",
    "h4",
    "p",
    "input",
    '[class*="hero"]',
    '[class*="card"]',
    '[class*="btn"]',
    '[class*="nav"]',
    '[class*="footer"]',
    '[class*="header"]',
  ].join(",");

  const els = document.querySelectorAll(selectors);

  // --- Colors ---
  const colorMap = new Map();
  els.forEach((el) => {
    const s = getComputedStyle(el);
    const bg = rgbToHex(s.backgroundColor);
    const fg = rgbToHex(s.color);
    const border = rgbToHex(s.borderColor);
    if (bg) colorMap.set(bg, (colorMap.get(bg) || 0) + 1);
    if (fg) colorMap.set(fg, (colorMap.get(fg) || 0) + 1);
    if (border && border !== bg && border !== fg)
      colorMap.set(border, (colorMap.get(border) || 0) + 1);
  });

  // --- Fonts ---
  const fontMap = new Map();
  els.forEach((el) => {
    const s = getComputedStyle(el);
    const key = JSON.stringify({
      family: s.fontFamily.split(",")[0].trim().replace(/['"]/g, ""),
      weight: s.fontWeight,
      size: s.fontSize,
      lineHeight: s.lineHeight,
    });
    fontMap.set(key, (fontMap.get(key) || 0) + 1);
  });

  // --- Spacing ---
  const container =
    document.querySelector(
      'main, article, [class*="container"], [class*="wrapper"], [class*="content"]',
    ) || document.body;
  const containerStyle = getComputedStyle(container);

  const sections = document.querySelectorAll(
    "section, [class*='section'], main > div",
  );
  const sectionPaddings = [];
  sections.forEach((sec) => {
    const s = getComputedStyle(sec);
    sectionPaddings.push(s.paddingTop, s.paddingBottom);
  });

  // --- Animations (CSS transitions/animations) ---
  const animations = [];
  els.forEach((el) => {
    const s = getComputedStyle(el);
    if (s.transition && s.transition !== "all 0s ease 0s") {
      animations.push({
        element:
          el.tagName.toLowerCase() +
          (el.classList && el.classList[0] ? "." + el.classList[0] : ""),
        type: "css-transition",
        transition: s.transition,
      });
    }
    if (s.animationName && s.animationName !== "none") {
      animations.push({
        element:
          el.tagName.toLowerCase() +
          (el.classList && el.classList[0] ? "." + el.classList[0] : ""),
        type: "css-animation",
        animation: s.animationName,
        duration: s.animationDuration,
        timingFunction: s.animationTimingFunction,
      });
    }
  });

  // --- Animation Libraries Detection ---
  const libraries = [];

  // AOS (Animate On Scroll)
  const aosElements = document.querySelectorAll("[data-aos]");
  if (aosElements.length > 0) {
    const aosTypes = new Set();
    aosElements.forEach((el) => aosTypes.add(el.getAttribute("data-aos")));
    libraries.push({
      name: "AOS",
      count: aosElements.length,
      types: [...aosTypes].slice(0, 5),
    });
  }

  // GSAP / ScrollTrigger
  if (window.gsap || window.ScrollTrigger) {
    libraries.push({ name: "GSAP", detected: true });
  }

  // Framer Motion (React)
  const framerElements = document.querySelectorAll(
    "[data-framer-appear-id], [data-framer-component-type]",
  );
  if (framerElements.length > 0) {
    libraries.push({ name: "Framer Motion", count: framerElements.length });
  }

  // Lottie
  if (
    document.querySelector("lottie-player, [data-lottie], dotlottie-player")
  ) {
    libraries.push({ name: "Lottie", detected: true });
  }

  // Generic scroll-reveal patterns
  const revealPatterns = document.querySelectorAll(
    '[class*="reveal"], [class*="animate-"], [class*="scroll-"], [class*="fade-"], [class*="slide-"], [data-scroll], [data-animate]',
  );
  if (revealPatterns.length > 0 && libraries.length === 0) {
    const classNames = new Set();
    revealPatterns.forEach((el) => {
      [...el.classList]
        .filter((c) => /reveal|animate|scroll|fade|slide/.test(c))
        .forEach((c) => classNames.add(c));
    });
    libraries.push({
      name: "scroll-reveal (generic)",
      count: revealPatterns.length,
      classes: [...classNames].slice(0, 8),
    });
  }

  // @keyframes from stylesheets
  const keyframes = [];
  try {
    [...document.styleSheets].forEach((sheet) => {
      try {
        [...sheet.cssRules].forEach((rule) => {
          if (rule instanceof CSSKeyframesRule) {
            keyframes.push(rule.name);
          }
        });
      } catch (e) {
        // CORS-blocked stylesheets
      }
    });
  } catch (e) {}

  return JSON.stringify({
    colors: [...colorMap.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 15)
      .map(([hex, count]) => ({ hex, count })),
    fonts: [...fontMap.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 8)
      .map(([key, count]) => ({ ...JSON.parse(key), count })),
    spacing: {
      maxWidth: containerStyle.maxWidth,
      padding: containerStyle.padding,
      gap: containerStyle.gap,
      sectionPaddings: [...new Set(sectionPaddings)].slice(0, 4),
    },
    animations: animations.slice(0, 10),
    animationLibraries: libraries,
    keyframes: [...new Set(keyframes)].slice(0, 10),
    title: document.title,
  });
})();

// TransType Web Simulator Logic

const DICTIONARY = {
  sentences: [
    {
      chinese: "今天下午三点在会议室开会",
      pinyin: "jintian xiawu sandian zai huiyishi kaihui",
      candidates: [
        { text: "Meeting in the conference room at 3 PM today.", style: "自然推荐", tone: "natural" },
        { text: "We will have a meeting in the conference room at 3:00 PM this afternoon.", style: "商务正式", tone: "formal" },
        { text: "Let's meet in the conference room at 3pm today.", style: "日常口语", tone: "casual" },
        { text: "3pm conference room meeting today.", style: "精简短语", tone: "concise" }
      ],
      keywords: [
        { word: "今天下午", translations: ["this afternoon", "today afternoon"], pos: "时间状语" },
        { word: "会议室", translations: ["conference room", "meeting room", "boardroom"], pos: "名词" },
        { word: "开会", translations: ["have a meeting", "hold a meeting", "meet"], pos: "动词" }
      ]
    },
    {
      chinese: "请问您明天下午是否有空开个会讨论项目进展",
      pinyin: "qingwen nin mingtian xiawu shifou youkong kaigehui taolun xiangmu jinzhan",
      candidates: [
        { text: "Could you please let me know if you are available tomorrow afternoon for a meeting to discuss project progress?", style: "自然推荐", tone: "natural" },
        { text: "Would you happen to have some time tomorrow afternoon to discuss the latest project progress?", style: "商务专业", tone: "formal" },
        { text: "Are you free to jump on a quick call tomorrow afternoon to go over project progress?", style: "日常口语", tone: "casual" },
        { text: "Available tomorrow afternoon to discuss project progress?", style: "精简短语", tone: "concise" }
      ],
      keywords: [
        { word: "有空", translations: ["available", "free", "have time"], pos: "形容词" },
        { word: "讨论", translations: ["discuss", "go over", "talk through"], pos: "动词" },
        { word: "项目进展", translations: ["project progress", "project updates", "status"], pos: "名词短语" }
      ]
    },
    {
      chinese: "麻烦查收一下附件中的最新文档",
      pinyin: "mafan chashou yixia fujian zhong de zuixin wendang",
      candidates: [
        { text: "Please find attached the latest document for your review.", style: "商务通用", tone: "formal" },
        { text: "Kindly check the attached file for the updated document.", style: "礼貌正式", tone: "formal" },
        { text: "Attached is the latest doc for you!", style: "日常口语", tone: "casual" },
        { text: "See attached for latest document.", style: "精炼通知", tone: "concise" }
      ],
      keywords: [
        { word: "查收", translations: ["find attached", "check", "review"], pos: "动词" },
        { word: "附件", translations: ["attachment", "attached file"], pos: "名词" },
        { word: "最新文档", translations: ["latest document", "updated file"], pos: "名词短语" }
      ]
    },
    {
      chinese: "这个问题我已经修复了，你可以重新拉取代码测试一下",
      pinyin: "zhege wenti wo yijing xiufu le, ni keyi chongxin laqu daima ceshi yixia",
      candidates: [
        { text: "I have fixed this issue, please pull the latest code and test it.", style: "自然推荐", tone: "natural" },
        { text: "This bug has been resolved. You can re-pull the repository and verify the fix.", style: "专业技术", tone: "formal" },
        { text: "Just pushed a fix for this! Pull and give it a spin.", style: "极客口语", tone: "casual" },
        { text: "Issue fixed. Please pull and verify.", style: "精简指令", tone: "concise" }
      ],
      keywords: [
        { word: "修复", translations: ["fix", "resolve", "patch"], pos: "动词" },
        { word: "拉取代码", translations: ["pull the code", "pull the latest changes"], pos: "动词短语" },
        { word: "测试", translations: ["test", "verify", "validate"], pos: "动词" }
      ]
    },
    {
      chinese: "你好",
      pinyin: "nihao",
      candidates: [
        { text: "Hello", style: "自然通用", tone: "natural" },
        { text: "Good day / Greetings", style: "正式礼貌", tone: "formal" },
        { text: "Hi / Hey there", style: "随和日常", tone: "casual" }
      ],
      keywords: [
        { word: "你好", translations: ["hello", "hi", "hey"], pos: "打招呼" }
      ]
    },
    {
      chinese: "谢谢",
      pinyin: "xiexie",
      candidates: [
        { text: "Thank you", style: "标准礼貌", tone: "natural" },
        { text: "Thank you very much / Much obliged", style: "商务正式", tone: "formal" },
        { text: "Thanks / Cheers", style: "随和口语", tone: "casual" }
      ],
      keywords: [
        { word: "谢谢", translations: ["thank you", "thanks", "appreciate it"], pos: "表达感谢" }
      ]
    }
  ],
  vocabulary: [
    { chinese: "需求", pinyin: "xuqiu", english: ["requirement", "demand", "feature request"], pos: "n." },
    { chinese: "方案", pinyin: "fangan", english: ["solution", "proposal", "plan", "scheme"], pos: "n." },
    { chinese: "设计", pinyin: "sheji", english: ["design", "architecture", "layout"], pos: "n./v." },
    { chinese: "开发", pinyin: "kaifa", english: ["develop", "development", "build"], pos: "v./n." },
    { chinese: "测试", pinyin: "ceshi", english: ["test", "testing", "verify", "validate"], pos: "v./n." },
    { chinese: "发布", pinyin: "fabu", english: ["release", "launch", "deploy", "publish"], pos: "v./n." },
    { chinese: "架构", pinyin: "jiagou", english: ["architecture", "framework", "structure"], pos: "n." },
    { chinese: "性能", pinyin: "xingneng", english: ["performance", "capability", "efficiency"], pos: "n." },
    { chinese: "优化", pinyin: "youhua", english: ["optimize", "optimization", "streamline"], pos: "v./n." },
    { chinese: "会议", pinyin: "huiyi", english: ["meeting", "conference", "session"], pos: "n." }
  ]
};

// State
let isHudOpen = false;
let currentCandidates = [];
let selectedIndex = 0;
let activeFilter = "all";
let debounceTimeout = null;

// DOM Elements
const hudOverlay = document.getElementById("transHudOverlay");
const hudInput = document.getElementById("hudInput");
const clearInputBtn = document.getElementById("clearInputBtn");
const candidatesList = document.getElementById("candidatesList");
const vocabDrawer = document.getElementById("vocabDrawer");
const vocabChipsContainer = document.getElementById("vocabChipsContainer");
const targetTextarea = document.getElementById("targetTextarea");
const triggerBtn = document.getElementById("triggerBtn");
const closeHudBtn = document.getElementById("closeHudBtn");
const toast = document.getElementById("toastNotification");
const activeEngineText = document.getElementById("activeEngineText");
const filterTabs = document.querySelectorAll(".filter-tab");
const presetBtns = document.querySelectorAll(".preset-btn");

// Clock update
function updateClock() {
  const now = new Date();
  const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  const timeEl = document.getElementById("currentTime");
  if (timeEl) timeEl.textContent = timeStr;
}
setInterval(updateClock, 1000);
updateClock();

// Toggle HUD
function openHud(prefillQuery = "") {
  isHudOpen = true;
  hudOverlay.classList.add("active");
  if (prefillQuery) {
    hudInput.value = prefillQuery;
  }
  hudInput.focus();
  clearInputBtn.style.display = hudInput.value ? "block" : "none";
  performTranslation(hudInput.value);
}

function closeHud() {
  isHudOpen = false;
  hudOverlay.classList.remove("active");
  targetTextarea.focus();
}

triggerBtn.addEventListener("click", () => openHud());
closeHudBtn.addEventListener("click", () => closeHud());

// Global Hotkeys (Alt + Space or Escape)
window.addEventListener("keydown", (e) => {
  // Option/Alt + Space to toggle HUD
  if (e.altKey && e.code === "Space") {
    e.preventDefault();
    if (isHudOpen) {
      closeHud();
    } else {
      openHud();
    }
    return;
  }

  // Inside HUD keyboard navigation
  if (isHudOpen) {
    if (e.key === "Escape") {
      e.preventDefault();
      closeHud();
      return;
    }

    if (e.key === "ArrowDown") {
      e.preventDefault();
      moveSelection(1);
      return;
    }

    if (e.key === "ArrowUp") {
      e.preventDefault();
      moveSelection(-1);
      return;
    }

    if (e.key === "Enter") {
      e.preventDefault();
      commitCurrentSelection();
      return;
    }

    // Number keys 1-7 for direct candidate selection
    if (/^[1-7]$/.test(e.key) && currentCandidates.length > 0) {
      const idx = parseInt(e.key, 10) - 1;
      if (idx < currentCandidates.length) {
        e.preventDefault();
        commitCandidate(currentCandidates[idx]);
        return;
      }
    }
  }
});

// Clear button
clearInputBtn.addEventListener("click", () => {
  hudInput.value = "";
  clearInputBtn.style.display = "none";
  performTranslation("");
  hudInput.focus();
});

// Input handling with debounce
hudInput.addEventListener("input", (e) => {
  const query = e.target.value;
  clearInputBtn.style.display = query ? "block" : "none";

  clearTimeout(debounceTimeout);
  debounceTimeout = setTimeout(() => {
    performTranslation(query);
  }, 100);
});

// Preset Buttons
presetBtns.forEach(btn => {
  btn.addEventListener("click", () => {
    const text = btn.getAttribute("data-text");
    openHud(text);
  });
});

// Filter Tabs
filterTabs.forEach(tab => {
  tab.addEventListener("click", () => {
    filterTabs.forEach(t => t.classList.remove("active"));
    tab.classList.add("active");
    activeFilter = tab.getAttribute("data-filter");
    renderCandidates();
  });
});

// Translation Query Algorithm
function performTranslation(query) {
  const clean = query.trim();
  if (!clean) {
    currentCandidates = [];
    vocabDrawer.style.display = "none";
    renderCandidates();
    return;
  }

  activeEngineText.innerHTML = "⚡ 本地离线引擎 (0ms 瞬时)";

  const results = [];
  const extractedKeywords = [];

  // 1. Search sentence templates
  let exactMatch = DICTIONARY.sentences.find(s => s.chinese === clean || s.pinyin.replace(/\s+/g, '') === clean.toLowerCase().replace(/\s+/g, ''));
  if (!exactMatch) {
    exactMatch = DICTIONARY.sentences.find(s => s.chinese.includes(clean) || clean.includes(s.chinese));
  }

  if (exactMatch) {
    exactMatch.candidates.forEach(c => {
      results.push({
        text: c.text,
        style: c.style,
        tone: c.tone,
        isVocab: false
      });
    });

    if (exactMatch.keywords) {
      exactMatch.keywords.forEach(kw => {
        extractedKeywords.push(kw);
        kw.translations.forEach(tr => {
          results.push({
            text: tr,
            style: `词汇 (${kw.pos})`,
            tone: "vocab",
            isVocab: true,
            originalWord: kw.word
          });
        });
      });
    }
  }

  // 2. Search vocabulary dictionary
  DICTIONARY.vocabulary.forEach(v => {
    if (clean.includes(v.chinese) || v.chinese.includes(clean) || v.pinyin === clean.toLowerCase()) {
      v.english.forEach(eng => {
        if (!results.some(r => r.text.toLowerCase() === eng.toLowerCase())) {
          results.push({
            text: eng,
            style: `词汇 (${v.pos})`,
            tone: "vocab",
            isVocab: true,
            originalWord: v.chinese
          });
        }
      });
      extractedKeywords.push({ word: v.chinese, translations: v.english, pos: v.pos });
    }
  });

  // 3. Fallback translation if not found in dictionary
  if (results.length === 0) {
    activeEngineText.innerHTML = "🌐 智能翻译生成器 (实时匹配)";
    results.push(
      { text: `[English translation of: "${clean}"]`, style: "自然推荐", tone: "natural", isVocab: false },
      { text: `[Formal style: "${clean}"]`, style: "商务正式", tone: "formal", isVocab: false }
    );
  }

  currentCandidates = results;
  selectedIndex = 0;

  // Render Vocab Drawer
  if (extractedKeywords.length > 0) {
    vocabDrawer.style.display = "block";
    vocabChipsContainer.innerHTML = "";
    extractedKeywords.forEach(kw => {
      kw.translations.forEach(t => {
        const chip = document.createElement("div");
        chip.className = "vocab-chip";
        chip.innerHTML = `<strong>${t}</strong> <span class="vocab-chip-word">${kw.word}</span>`;
        chip.addEventListener("click", () => {
          commitCandidate({ text: t, originalWord: kw.word });
        });
        vocabChipsContainer.appendChild(chip);
      });
    });
  } else {
    vocabDrawer.style.display = "none";
  }

  renderCandidates();
}

function renderCandidates() {
  candidatesList.innerHTML = "";

  if (currentCandidates.length === 0) {
    candidatesList.innerHTML = `
      <div class="hud-empty-state">
        <div class="empty-icon">⌨️</div>
        <div class="empty-text">请输入中文句子或词汇，实时生成多种英文表达与词汇选择</div>
      </div>
    `;
    return;
  }

  // Filter candidates
  let filtered = currentCandidates;
  if (activeFilter !== "all") {
    filtered = currentCandidates.filter(c => c.tone === activeFilter);
  }

  if (filtered.length === 0) {
    candidatesList.innerHTML = `
      <div class="hud-empty-state">
        <div class="empty-icon">🔍</div>
        <div class="empty-text">该分类下暂无候选，可切换至【全部候选】查看</div>
      </div>
    `;
    return;
  }

  filtered.slice(0, 7).forEach((cand, idx) => {
    const card = document.createElement("div");
    card.className = `candidate-card ${idx === selectedIndex ? 'selected' : ''}`;

    let badgeClass = "badge-natural";
    if (cand.tone === "formal") badgeClass = "badge-formal";
    else if (cand.tone === "casual") badgeClass = "badge-casual";
    else if (cand.tone === "concise") badgeClass = "badge-concise";
    else if (cand.isVocab) badgeClass = "badge-vocab";

    let metaHtml = "";
    if (cand.isVocab && cand.originalWord) {
      metaHtml = `<span class="cand-meta-text">原词: ${cand.originalWord}</span>`;
    }

    card.innerHTML = `
      <div class="cand-index-badge">${idx + 1}</div>
      <div class="cand-style-badge ${badgeClass}">${cand.style}</div>
      <div class="cand-content-wrap">
        <div class="cand-english-text">${cand.text}</div>
        ${metaHtml}
      </div>
      <div class="cand-commit-action">↵ 上屏</div>
    `;

    card.addEventListener("click", () => {
      commitCandidate(cand);
    });

    candidatesList.appendChild(card);
  });
}

function moveSelection(direction) {
  let filtered = currentCandidates;
  if (activeFilter !== "all") {
    filtered = currentCandidates.filter(c => c.tone === activeFilter);
  }
  const max = Math.min(filtered.length, 7);
  if (max === 0) return;

  selectedIndex = (selectedIndex + direction + max) % max;
  renderCandidates();
}

function commitCurrentSelection() {
  let filtered = currentCandidates;
  if (activeFilter !== "all") {
    filtered = currentCandidates.filter(c => c.tone === activeFilter);
  }
  if (filtered.length > 0 && selectedIndex < filtered.length) {
    commitCandidate(filtered[selectedIndex]);
  }
}

// Core Commit Logic: Inserts English text directly into target app!
function commitCandidate(cand) {
  const englishText = cand.text;

  // 1. Hide HUD
  closeHud();

  // 2. Insert into target textarea at current cursor position
  const startPos = targetTextarea.selectionStart;
  const endPos = targetTextarea.selectionEnd;
  const currentVal = targetTextarea.value;

  const prefix = currentVal.substring(0, startPos);
  const suffix = currentVal.substring(endPos);

  // Add space if needed
  const needsSpace = prefix.length > 0 && !prefix.endsWith(" ") && !prefix.endsWith("\n");
  const insertString = (needsSpace ? " " : "") + englishText;

  targetTextarea.value = prefix + insertString + suffix;

  // Move cursor to end of inserted text
  const newCaretPos = prefix.length + insertString.length;
  targetTextarea.setSelectionRange(newCaretPos, newCaretPos);
  targetTextarea.focus();

  // 3. Clear HUD for next use
  hudInput.value = "";
  currentCandidates = [];

  // 4. Show Notification Toast
  showToast(`已成功上屏英文：${englishText}`);
}

function showToast(msg) {
  toast.textContent = msg;
  toast.classList.add("show");
  setTimeout(() => {
    toast.classList.remove("show");
  }, 2200);
}

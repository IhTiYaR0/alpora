/**
 * ALPORA Unified Interactive Shell & Motion Sandbox
 * Single-Page Architecture with live Python BE telemetry & i18n support.
 * Pure JavaScript logic: zero embedded HTML strings or innerHTML usage.
 */

'use strict';

const I18N = {
  vi: {
    navShell: "Desktop Shell",
    navMotion: "Phòng thí nghiệm Motion (16 Studies)",
    navTypo: "Bộ Typography",
    brandTitle: "ALPORA · INTERACTIVE LAB",
    liveBackend: "● KẾT NỐI LIVE BACKEND",
    standalone: "● MÔ PHỎNG ĐỘC LẬP",
    lblTheme: "Chủ đề:",
    lblMode: "Chế độ:",
    workMode: "Làm việc",
    vibeMode: "Thư giãn",
    lblPower: "Hiệu năng",
    lblTypoTitle: "Bộ Typography Tiêu Chuẩn ALPORA",
    lblTypoDesc: "Được nạp trực tiếp qua FontLoader vào Quickshell và áp dụng đồng bộ cho toàn bộ hệ thống.",
    playAll: "↻ Chạy tất cả",
    closeAll: "Đóng tất cả",
    speed: "Tốc độ",
    open: "Mở",
    close: "Đóng",
    repeat: "Thử lại",
    opened: "Đang mở",
    closed: "Đã đóng",
    qmlCode: "Mã QML",
    copied: "Đã sao chép!",
    footerHint: "Nhấn chuột vào các nút trên thanh TopBar để thử nghiệm tương tác · Phím Esc để thoát.",
    days: ["Chủ Nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"],
    studies: [
      { id: 'slide', title: 'Trượt mềm (Soft Slide)', desc: 'Panel trượt xuống êm ái từ mép dưới của TopBar rồi dừng nhẹ nhàng. Khi đóng trượt ngược lên.', hint: 'Dịch chuyển trục Y + mờ dần (opacity). Chuẩn mặc định cho desktop.' },
      { id: 'curtain', title: 'Kéo rèm (Curtain Drop)', desc: 'Mép trên cố định dưới TopBar. Panel mở dần xuống dưới như tấm rèm buông nhẹ.', hint: 'Mở rộng chiều cao với clip-path bo tròn 14px; văn bản không bị kéo giãn.' },
      { id: 'origin', title: 'Phóng từ icon (Origin Pop)', desc: 'Từ vị trí icon được nhấn trên TopBar, một khối nhỏ bung nở thành cửa sổ hoàn chỉnh.', hint: 'Tâm biến đổi (transform-origin) gắn chặt với tọa độ icon bấm.' },
      { id: 'pop', title: 'Nảy nhẹ (Subtle Pop-in)', desc: 'Panel xuất hiện với độ phóng to 94% -> 100% kèm tăng dần độ trong suốt, không rung lắc.', hint: 'Tăng nhẹ kích thước + mượt mà. Rất phù hợp với chế độ Work tối giản.' },
      { id: 'spring', title: 'Độ nảy lò xo (Spring Bounce)', desc: 'Panel trượt xuống, vượt nhẹ qua điểm dừng một chút rồi bật khẽ trở lại vị trí cân bằng.', hint: 'Hiệu ứng lò xo tinh tế tạo cảm giác phản hồi vật lý sống động.' },
      { id: 'morph', title: 'Biến đổi tab (Morph Switch)', desc: 'Panel tự động co giãn kích thước, di chuyển vị trí và đổi nội dung mượt mà khi bấm tab khác.', hint: 'Thử chuyển qua lại giữa Đồng hồ, Lịch, Thông báo và Cài đặt!', pages: true },
      { id: 'center', title: 'Mở từ tâm (Center Expand)', desc: 'Từ một điểm nhỏ ở giữa bung thành thanh ngang mỏng, sau đó mở rộng theo chiều dọc.', hint: 'Chuyển động 2 pha: Chiều ngang (Width) -> Chiều dọc (Height).' },
      { id: 'iris', title: 'Mở khẩu độ (Circular Iris)', desc: 'Một mặt nạ hình tròn từ icon nút bấm mở rộng dần ra xung quanh làm lộ panel.', hint: 'Clip-path dạng circle(r at x y) mở rộng 0% -> 145%.' },
      { id: 'depth', title: 'Chiều sâu 3D (Depth Perspective)', desc: 'Panel phóng to từ không gian 3D phía sau, xoay nhẹ góc nghiêng và áp sát màn hình.', hint: 'Sử dụng perspective 800px + translateZ(-180px) + rotateX(22deg).' },
      { id: 'hinge', title: 'Bản lề thả (Hinge Drop)', desc: 'Panel xoay quanh bản lề mép trên thả xuống như cánh cửa tủ mở nhẹ.', hint: 'Xoay 3D quanh trục trên rotateX(-88deg -> 0deg).' },
      { id: 'fold', title: 'Gấp nếp giấy (Origami Fold)', desc: 'Nửa trên mở ra trước, sau đó nửa dưới bung tiếp theo như mở một tờ giấy gấp đôi.', hint: 'Hai mảnh độc lập với trục xoay riêng biệt.' },
      { id: 'liquid', title: 'Giọt nước lỏng (Liquid Droplet)', desc: 'Giọt nước từ icon kéo dài xuống, biến dạng hữu cơ rồi nở bung thành hình panel chữ nhật.', hint: 'Biến thiên border-radius bất đối xứng tạo cảm giác hữu cơ mềm mại.' },
      { id: 'outline', title: 'Vẽ viền trước (Outline Trace)', desc: 'Một vệt sáng neon chạy vòng quanh viền bo góc trước, sau đó nền kính và nội dung hiện ra.', hint: 'Vẽ đường nét SVG stroke-dashoffset rồi làm đầy nội dung.' },
      { id: 'cascade', title: 'Thác đổ (Staggered Cascade)', desc: 'Mặt nền kính hiện lên, sau đó tiêu đề, thanh âm lượng và các ô nút lần lượt rơi vào vị trí.', hint: 'Mỗi thành phần con xuất hiện cách nhau 75ms (stagger delay).' },
      { id: 'slit', title: 'Khe sáng hẹp (Glowing Slit)', desc: 'Một khe sáng mảnh xuất hiện dưới thanh bar, rồi nở rộng xuống dưới thành panel.', hint: 'Đa giác polygon thu hẹp thành khe 1px rồi mở rộng toàn phần.' },
      { id: 'travel', title: 'Con nhộng di chuyển (Traveling Capsule)', desc: 'Panel thu gọn thành hình con nhộng, chạy ngang sang icon mới rồi bung mở trở lại.', hint: 'Thu nhỏ capsule -> dịch chuyển ngang -> mở rộng kích thước mới.', pages: true }
    ],
    pages: {
      settings: { title: "Cài đặt nhanh", subtitle: "ALPORA · Không gian làm việc", volume: "Âm lượng", brightness: "Độ sáng", wifi: "Wi-Fi", bluetooth: "Bluetooth", on: "Đang bật", off: "Đang tắt", mode: "Chế độ làm việc", balance: "Cân bằng" },
      calendar: { title: "Lịch hôm nay", month: "Tháng 10 2026", footer: "Hôm nay là thời điểm tuyệt vời cho các dự định mới", days: ['T2','T3','T4','T5','T6','T7','CN'] },
      notifications: { title: "Thông báo", note1Title: "Chào mừng đến với ALPORA", note1Desc: "Hệ thống · vừa xong", note2Title: "Danh sách nhạc đã sẵn sàng", note2Desc: "Media · 5 phút trước", footer: "Lịch sử thông báo hệ thống" },
      timeline: { title: "Dòng thời gian (Timeline)", subtitle: "Từ bình minh đến đêm muộn" }
    }
  },
  en: {
    navShell: "Desktop Shell",
    navMotion: "Motion Lab (16 Studies)",
    navTypo: "Typography Suite",
    brandTitle: "ALPORA · INTERACTIVE LAB",
    liveBackend: "● LIVE PYTHON BACKEND",
    standalone: "● STANDALONE SIMULATOR",
    lblTheme: "Theme:",
    lblMode: "Mode:",
    workMode: "Work",
    vibeMode: "Vibe",
    lblPower: "Performance",
    lblTypoTitle: "ALPORA Typography Suite",
    lblTypoDesc: "Embedded natively via Quickshell FontLoader and applied system-wide for crisp legibility.",
    playAll: "↻ Play All",
    closeAll: "Close All",
    speed: "Speed",
    open: "Open",
    close: "Close",
    repeat: "Replay",
    opened: "Opened",
    closed: "Closed",
    qmlCode: "QML Code",
    copied: "Copied!",
    footerHint: "Click any button on the TopBar or cards to test interactions · Press Escape to close all.",
    days: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
    studies: [
      { id: 'slide', title: 'Soft Slide', desc: 'Panel slides down smoothly from beneath the bar and eases to a stop. Closing slides it back.', hint: 'Vertical translation + opacity fade. Clean and distraction-free.' },
      { id: 'curtain', title: 'Curtain Drop', desc: 'Top edge anchored under the bar. The panel unfolds downward, revealing contents progressively.', hint: 'Height expansion with 14px rounded clip-path; text is not stretched.' },
      { id: 'origin', title: 'Origin Pop', desc: 'A compact shape directly beneath the clicked button morphs outward into the full window.', hint: 'Transform origin anchored directly to the clicked icon coordinates.' },
      { id: 'pop', title: 'Subtle Pop-in', desc: 'The panel expands gently from 94% to full scale with zero bounce or overshoot.', hint: 'Subtle scale-up + smooth opacity curve. Ideal for Work mode.' },
      { id: 'spring', title: 'Spring Bounce', desc: 'The panel slides down, slightly overshoots its resting mark, then springs gently back into place.', hint: 'Organic bounce simulation with subtle physical elasticity.' },
      { id: 'morph', title: 'Morph Switch', desc: 'The open window simultaneously animates position, dimensions, and contents when switching tabs.', hint: 'Switch between Clock, Timeline, Notifications, and Settings!', pages: true },
      { id: 'center', title: 'Center Expand', desc: 'A tiny center point grows into a thin horizontal bar, which then opens vertically.', hint: 'Two-phase transition: Width first -> Height second.' },
      { id: 'iris', title: 'Circular Iris', desc: 'A circular mask centered at the button expands outward, revealing the panel cleanly.', hint: 'Circle clip-path mask from 0% to 145% without text distortion.' },
      { id: 'depth', title: 'Depth Perspective', desc: 'Panel zooms forward from 3D background depth, tilts slightly, and snaps flush to the viewport.', hint: 'Perspective 800px with translateZ(-180px) and rotateX tilt.' },
      { id: 'hinge', title: 'Hinge Drop', desc: 'Panel swings down on a top hinge like an elegant mechanical lid.', hint: 'Rotates around the top edge from -88deg to 0deg.' },
      { id: 'fold', title: 'Origami Fold', desc: 'Upper half unfolds first, followed by the lower half swinging out like folded paper.', hint: 'Two discrete halves with independent hinge perspectives.' },
      { id: 'liquid', title: 'Liquid Droplet', desc: 'A droplet beneath the button stretches, becomes an organic bubble, then settles into a rectangle.', hint: 'Asymmetric border-radius deformation with smooth dampening.' },
      { id: 'outline', title: 'Outline Trace', desc: 'A crisp glowing outline traces the perimeter first, followed by surface fill and contents.', hint: 'SVG stroke-dashoffset perimeter animation then body fade-in.' },
      { id: 'cascade', title: 'Staggered Cascade', desc: 'Surface appears, then header, sliders, and toggle tiles animate into position one by one.', hint: 'Each child component enters with a 75ms sequential delay.' },
      { id: 'slit', title: 'Glowing Slit', desc: 'A luminous horizontal line widens under the bar, then expands downward into the full panel.', hint: 'Polygon slit expands from 1px slice into full bounding box.' },
      { id: 'travel', title: 'Traveling Capsule', desc: 'Panel collapses into a capsule, glides horizontally to the new button, and re-expands.', hint: 'Click different bar buttons: capsule travels between them.', pages: true }
    ],
    pages: {
      settings: { title: "Quick Settings", subtitle: "ALPORA · Your workspace", volume: "Volume", brightness: "Brightness", wifi: "Wi-Fi", bluetooth: "Bluetooth", on: "Connected", off: "Off", mode: "Work Mode", balance: "Balanced" },
      calendar: { title: "My Day", month: "October 2026", footer: "Today is a great day for deep focus", days: ['MO','TU','WE','TH','FR','SA','SU'] },
      notifications: { title: "Notifications", note1Title: "Welcome to ALPORA", note1Desc: "System · Just now", note2Title: "Your playlist is ready", note2Desc: "Media · 5m ago", footer: "System notification history" },
      timeline: { title: "Timeline", subtitle: "From sunrise to starlight" }
    }
  },
  ru: {
    navShell: "Оболочка",
    navMotion: "Анимации (16 вариантов)",
    navTypo: "Типографика",
    brandTitle: "ALPORA · ИНТЕРАКТИВНАЯ ЛАБОРАТОРИЯ",
    liveBackend: "● БЭКЕНД PYTHON ПОДКЛЮЧЕН",
    standalone: "● АВТОНОМНЫЙ РЕЖИМ",
    lblTheme: "Тема:",
    lblMode: "Режим:",
    workMode: "Работа",
    vibeMode: "Вайб",
    lblPower: "Производительность",
    lblTypoTitle: "Типографика ALPORA",
    lblTypoDesc: "Загружается через Quickshell FontLoader и используется нативно по всей системе.",
    playAll: "↻ Сравнить все",
    closeAll: "Закрыть все",
    speed: "Скорость",
    open: "Открыть",
    close: "Закрыть",
    repeat: "Повторить",
    opened: "Открыто",
    closed: "Закрыто",
    qmlCode: "Код QML",
    copied: "Скопировано!",
    footerHint: "Нажми на значок панели в mini-bar · Esc — закрыть все карточки.",
    days: ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"],
    studies: [
      { id: 'slide', title: 'Мягкий выезд', desc: 'Панель спускается из-под бара и плавно останавливается. Закрытие уводит её обратно.', hint: 'Движение вниз + прозрачность.' },
      { id: 'curtain', title: 'Шторка', desc: 'Верхний край закреплён под баром. Панель раскрывается вниз, постепенно открывая содержимое.', hint: 'Раскрытие по высоте · текст не растягивается.' },
      { id: 'origin', title: 'Из кнопки в панель', desc: 'Маленькая форма возле иконки разворачивается в окно. Содержимое появляется после раскрытия.', hint: 'Превращение формы от нажатой кнопки.' },
      { id: 'pop', title: 'Мягкий pop-in', desc: 'Панель чуть увеличивается до полного размера. Спокойное движение без отскока.', hint: 'Лёгкое увеличение + прозрачность.' },
      { id: 'spring', title: 'Лёгкая пружина', desc: 'Панель выезжает, слегка проходит точку остановки и мягко возвращается на место.', hint: 'Один небольшой отскок с физической отдачей.' },
      { id: 'morph', title: 'Плавное превращение', desc: 'Открытое окно одновременно меняет положение, размер и содержимое при выборе другой кнопки.', hint: 'Переключай часы, солнце, колокольчик и настройки!', pages: true },
      { id: 'center', title: 'Раскрытие от центра', desc: 'Из маленькой точки вырастает тонкая горизонтальная полоска. Затем панель раскрывается вверх и вниз.', hint: 'Две фазы: ширина → высота.' },
      { id: 'iris', title: 'Диафрагма', desc: 'Из точки под кнопкой расширяется круг. Он постепенно открывает всю панель.', hint: 'Круглая маска от иконки · без искажения текста.' },
      { id: 'depth', title: 'Карточка из глубины', desc: 'Панель приближается из глубины, немного поворачивается и мягко становится плоской.', hint: 'Перспектива + приближение + выравнивание.' },
      { id: 'hinge', title: 'Откидная панель', desc: 'Панель висит на верхнем шарнире и опускается из-под бара, как лёгкая крышка.', hint: 'Поворот вокруг верхнего края на 88°.' },
      { id: 'fold', title: 'Складка', desc: 'Сначала разворачивается верхняя половина, затем из неё выходит нижняя. Как сложенный лист.', hint: 'Две отдельные половины с собственными шарнирами.' },
      { id: 'liquid', title: 'Жидкое превращение', desc: 'Капля под иконкой вытягивается, становится мягким пузырём и принимает форму панели.', hint: 'Асимметричная форма + растяжение + мягкое оседание.' },
      { id: 'outline', title: 'Контур → содержимое', desc: 'Светлая линия обходит рамку. Следом появляется поверхность и наполняется содержимым.', hint: 'Реальная прорисовка контура, затем заполнение.' },
      { id: 'cascade', title: 'Каскад элементов', desc: 'Появляется поверхность, затем заголовок, ползунки и плитки последовательно занимают свои места.', hint: 'У каждого элемента своя небольшая задержка.' },
      { id: 'slit', title: 'Из тонкой щели', desc: 'Под баром растёт узкая светлая линия. Она раскрывается вниз в полноценную панель.', hint: 'Горизонтальная щель → раскрытие вниз.' },
      { id: 'travel', title: 'Движущийся контейнер', desc: 'Панель сворачивается в компактную капсулу, переезжает к другой кнопке и раскрывается заново.', hint: 'Нажимай разные кнопки — капсула перемещается между ними.', pages: true }
    ],
    pages: {
      settings: { title: "Быстрые настройки", subtitle: "Alpine · Твоё пространство", volume: "Громкость", brightness: "Яркость", wifi: "Wi-Fi", bluetooth: "Bluetooth", on: "Включён", off: "Выключен", mode: "Рабочий режим", balance: "Баланс" },
      calendar: { title: "Мой день", month: "Октябрь 2026", footer: "Сегодня — время для своих планов", days: ['ПН','ВТ','СР','ЧТ','ПТ','СБ','ВС'] },
      notifications: { title: "Уведомления", note1Title: "Добро пожаловать в Alpine", note1Desc: "Система · только что", note2Title: "Твой плейлист готов", note2Desc: "Музыка · 5 минут назад", footer: "Демонстрационные уведомления" },
      timeline: { title: "Timeline", subtitle: "От рассвета до ночной долины" }
    }
  }
};

const THEMES = {
  alpine: { bg: "#101a1b", surface: "#182526", line: "#344441", ink: "#ecf0e7", muted: "#9baea6", accent: "#c0d3ae", secondary: "#f1b791", wallpaper: "/assets/wallpapers/alpine-dawn.png", altWallpaper: "../../../assets/wallpapers/alpine-dawn.png" },
  "moon-lake": { bg: "#101625", surface: "#1a253b", line: "#374762", ink: "#edf0f6", muted: "#a8b5c9", accent: "#b2a5f2", secondary: "#a9caf6", wallpaper: "/assets/wallpapers/moon-lake.png", altWallpaper: "../../../assets/wallpapers/moon-lake.png" },
  "forest-mist": { bg: "#101f20", surface: "#1c3230", line: "#345550", ink: "#ecf3ef", muted: "#9bb5ab", accent: "#a9c8ba", secondary: "#dfd7bb", wallpaper: "/assets/wallpapers/forest-mist.png", altWallpaper: "../../../assets/wallpapers/forest-mist.png" },
  "northern-lights": { bg: "#0d1b22", surface: "#172c38", line: "#2f5367", ink: "#edf3f6", muted: "#97b8c7", accent: "#7bd3cd", secondary: "#bca4f0", wallpaper: "/assets/wallpapers/northern-lights.png", altWallpaper: "../../../assets/wallpapers/northern-lights.png" },
  "warm-desert": { bg: "#221714", surface: "#35231c", line: "#5c3d31", ink: "#faede8", muted: "#cbb1a5", accent: "#efba87", secondary: "#df9274", wallpaper: "/assets/wallpapers/warm-desert.png", altWallpaper: "../../../assets/wallpapers/warm-desert.png" },
  "rose-sunset": { bg: "#1e1724", surface: "#2f2237", line: "#533b5f", ink: "#f7edf3", muted: "#c5adc0", accent: "#e5a9c4", secondary: "#efb89e", wallpaper: "/assets/wallpapers/rose-sunset.png", altWallpaper: "../../../assets/wallpapers/rose-sunset.png" },
  timeline: { bg: "#141c21", surface: "#222c32", line: "#3c4d57", ink: "#edf2f4", muted: "#a9bac5", accent: "#c7c5a6", secondary: "#edb297", wallpaper: "/assets/wallpapers/timeline/day.png", altWallpaper: "../../../assets/wallpapers/timeline/day.png" }
};

let currentLang = localStorage.getItem('alpora_demo_lang') || 'vi';
let currentTheme = localStorage.getItem('alpora_demo_theme') || 'alpine';
let speed = 1;
let isLiveBackend = false;
const controllers = [];

function applyTheme(key, notifyBackend = true) {
  const t = THEMES[key] || THEMES.alpine;
  currentTheme = key;
  localStorage.setItem('alpora_demo_theme', key);
  const root = document.documentElement;
  root.style.setProperty('--bg', t.bg);
  root.style.setProperty('--surface', t.surface);
  root.style.setProperty('--line', t.line);
  root.style.setProperty('--ink', t.ink);
  root.style.setProperty('--muted', t.muted);
  root.style.setProperty('--accent', t.accent);
  root.style.setProperty('--secondary', t.secondary);
  const wp = window.location.protocol === 'file:' ? t.altWallpaper : t.wallpaper;
  root.style.setProperty('--wallpaper', "url('" + wp + "')");

  document.querySelectorAll('.theme-pill-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.theme === key);
  });

  if (notifyBackend) {
    void sendAction('theme', key);
  }
}

async function checkBackend() {
  try {
    const res = await fetch('/api/state');
    if (res.ok) {
      const data = await res.json();
      isLiveBackend = true;
      const badge = document.querySelector('#backend-badge');
      if (badge) {
        badge.textContent = I18N[currentLang].liveBackend;
        badge.style.color = 'var(--accent)';
      }
      if (data.metrics) {
        if (data.metrics.cpuPercent !== undefined) {
          const cpuEl = document.querySelector('#metric-cpu');
          if (cpuEl) cpuEl.textContent = data.metrics.cpuPercent + "% · 48°C";
        }
        if (data.metrics.ramUsedGb !== undefined) {
          const ramEl = document.querySelector('#metric-ram');
          if (ramEl) ramEl.textContent = data.metrics.ramUsedGb + " / " + data.metrics.ramTotalGb + " GB";
        }
        if (data.metrics.batteryPercent !== undefined) {
          const batSpan = document.querySelector('#qs-pill-btn span');
          if (batSpan) batSpan.textContent = data.metrics.batteryPercent + "%";
        }
      }
      if (data.session && data.session.theme && data.session.theme !== currentTheme) {
        applyTheme(data.session.theme, false);
      }
    }
  } catch (_) {
    isLiveBackend = false;
    const badge = document.querySelector('#backend-badge');
    if (badge) {
      badge.textContent = I18N[currentLang].standalone;
      badge.style.color = 'var(--muted)';
    }
  }
}

async function sendAction(action, value) {
  if (!isLiveBackend) return;
  try {
    await fetch('/api/action', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action, value })
    });
  } catch (_) {}
}

function updateLanguage(lang) {
  currentLang = lang;
  localStorage.setItem('alpora_demo_lang', lang);
  const t = I18N[lang];

  document.querySelectorAll('.lang-switch button').forEach(btn => {
    btn.setAttribute('aria-pressed', String(btn.dataset.lang === lang));
  });

  const setText = (selector, text) => {
    const el = document.querySelector(selector);
    if (el) el.textContent = text;
  };

  setText('#tab-nav-shell', t.navShell);
  setText('#tab-nav-motion', t.navMotion);
  setText('#tab-nav-typo', t.navTypo);
  setText('#lbl-theme', t.lblTheme);
  setText('#lbl-mode', t.lblMode);
  setText('#btn-work-mode', t.workMode);
  setText('#btn-vibe-mode', t.vibeMode);
  setText('#txt-power-label', t.lblPower);
  setText('#lbl-typo-title', t.lblTypoTitle);
  setText('#lbl-typo-desc', t.lblTypoDesc);
  setText('#play-all', t.playAll);
  setText('#close-all', t.closeAll);
  setText('#speed-label', t.speed);
  setText('#footer-hint', t.footerHint);

  const badge = document.querySelector('#backend-badge');
  if (badge) {
    badge.textContent = isLiveBackend ? t.liveBackend : t.standalone;
  }

  // Update all 16 study cards in the DOM
  document.querySelectorAll('.study').forEach((card, i) => {
    const s = t.studies[i];
    if (!s) return;

    const titleEl = card.querySelector('.study-title');
    if (titleEl) titleEl.textContent = s.title;

    const descEl = card.querySelector('.study-desc');
    if (descEl) descEl.textContent = s.desc;

    const hintEl = card.querySelector('.hint-line');
    if (hintEl) hintEl.textContent = s.hint;

    const repeatLabel = card.querySelector('.repeat-label');
    if (repeatLabel) repeatLabel.textContent = t.repeat;

    const qmlLabel = card.querySelector('.qml-label');
    if (qmlLabel) qmlLabel.textContent = t.qmlCode;

    const isCardOpen = controllers[i] && controllers[i].open;
    const toggleEl = card.querySelector('.toggle');
    if (toggleEl) toggleEl.textContent = isCardOpen ? t.close : t.open;

    const stateEl = card.querySelector('.state');
    if (stateEl) stateEl.textContent = isCardOpen ? t.opened : t.closed;

    // Update settings sub-page text
    const setPage = card.querySelector('.panel-page[data-page="settings"]');
    if (setPage) {
      const heading = setPage.querySelector('.heading-title');
      if (heading) heading.textContent = t.pages.settings.title;
      const subtitle = setPage.querySelector('.panel-subtitle');
      if (subtitle) subtitle.textContent = t.pages.settings.subtitle;
      const modeText = setPage.querySelector('.page-mode');
      if (modeText) modeText.textContent = t.pages.settings.mode;
      const balanceTag = setPage.querySelector('.mini-tag');
      if (balanceTag) balanceTag.textContent = t.pages.settings.balance;
    }

    // Update calendar sub-page text (if present)
    const calPage = card.querySelector('.panel-page[data-page="calendar"]');
    if (calPage) {
      const heading = calPage.querySelector('.heading-title');
      if (heading) heading.textContent = t.pages.calendar.title;
      const month = calPage.querySelector('.calendar-month');
      if (month) month.textContent = t.pages.calendar.month;
      const footer = calPage.querySelector('.footer-note');
      if (footer) footer.textContent = t.pages.calendar.footer;
      const weekdays = calPage.querySelectorAll('.weekday');
      t.pages.calendar.days.forEach((dayStr, dIdx) => {
        if (weekdays[dIdx]) weekdays[dIdx].textContent = dayStr;
      });
    }

    // Update notifications sub-page text (if present)
    const notifPage = card.querySelector('.panel-page[data-page="notifications"]');
    if (notifPage) {
      const heading = notifPage.querySelector('.heading-title');
      if (heading) heading.textContent = t.pages.notifications.title;
      const n1Title = notifPage.querySelector('.note-title-1');
      if (n1Title) n1Title.textContent = t.pages.notifications.note1Title;
      const n1Desc = notifPage.querySelector('.note-desc-1');
      if (n1Desc) n1Desc.textContent = t.pages.notifications.note1Desc;
      const n2Title = notifPage.querySelector('.note-title-2');
      if (n2Title) n2Title.textContent = t.pages.notifications.note2Title;
      const n2Desc = notifPage.querySelector('.note-desc-2');
      if (n2Desc) n2Desc.textContent = t.pages.notifications.note2Desc;
      const footer = notifPage.querySelector('.footer-note');
      if (footer) footer.textContent = t.pages.notifications.footer;
    }

    // Update timeline sub-page text (if present)
    const timePage = card.querySelector('.panel-page[data-page="timeline"]');
    if (timePage) {
      const heading = timePage.querySelector('.heading-title');
      if (heading) heading.textContent = t.pages.timeline.title;
      const subtitle = timePage.querySelector('.panel-subtitle');
      if (subtitle) subtitle.textContent = t.pages.timeline.subtitle;
    }
  });

  tick();
}

function tick() {
  const now = new Date();
  const hours = String(now.getHours()).padStart(2, '0');
  const minutes = String(now.getMinutes()).padStart(2, '0');
  const seconds = now.getSeconds();

  const hourEl = document.querySelector('#hero-hour');
  if (hourEl) hourEl.textContent = hours;
  const minEl = document.querySelector('#hero-min');
  if (minEl) minEl.textContent = minutes;

  const fillEl = document.querySelector('#seconds-fill');
  if (fillEl) fillEl.style.width = ((seconds / 60) * 100) + '%';

  const t = I18N[currentLang];
  const dayName = t.days[now.getDay()];
  const dateEl = document.querySelector('#hero-date-text');
  if (dateEl) {
    dateEl.textContent = dayName + ", " + now.getDate() + " / " + (now.getMonth() + 1);
  }

  const clockBar = document.querySelector('#bar-clock');
  if (clockBar) {
    clockBar.textContent = hours + ":" + minutes + " · " + dayName.slice(0, 3) + " " + now.getDate();
  }

  if (!isLiveBackend) {
    const cpuVal = 28 + (seconds % 9);
    const cpuEl = document.querySelector('#metric-cpu');
    if (cpuEl) cpuEl.textContent = cpuVal + "% · 48°C";
  }
}

const identity = 'translate(0px, 0px) scale(1)';
const closed = {
  slide: { transform: 'translateY(-26px)', opacity: 0 },
  curtain: { clipPath: 'inset(0 0 100% 0 round 14px)', transform: 'translateY(-5px)', opacity: 1 },
  origin: { transform: 'translateY(-26px) scale(0.065, 0.10)', borderRadius: '45px', opacity: 0 },
  pop: { transform: 'translateY(-5px) scale(.94)', opacity: 0 },
  spring: { transform: 'translateY(-32px)', opacity: 0 },
  morph: { transform: 'translateY(-12px) scale(.98)', opacity: 0 },
  center: { clipPath: 'inset(49.5% 49.5% 49.5% 49.5% round 14px)', opacity: 1 },
  iris: { clipPath: 'circle(0% at calc(100% - 17px) 0%)', opacity: 1 },
  depth: { transform: 'perspective(800px) translateZ(-180px) translateY(-25px) rotateX(22deg)', opacity: 0 },
  hinge: { transform: 'perspective(750px) rotateX(-88deg)', opacity: 0 },
  fold: { opacity: 0 },
  liquid: { transform: 'translateY(-27px) scale(.09,.14)', borderRadius: '70% 30% 65% 35% / 45% 70% 30% 55%', opacity: 0 },
  outline: { opacity: 0 },
  cascade: { opacity: 0 },
  slit: { clipPath: 'polygon(44% 0%,56% 0%,56% 1%,44% 1%)', opacity: 1 },
  travel: { transform: 'translateY(-12px) scale(.98)', opacity: 0 }
};

const final = { transform: identity, opacity: 1, clipPath: 'inset(0 0 0% 0 round 14px)', borderRadius: '14px' };
function endStyle(id) {
  const overrides = {};
  if (id === 'iris') {
    overrides.clipPath = 'circle(145% at calc(100% - 17px) 0%)';
  } else if (id === 'slit') {
    overrides.clipPath = 'polygon(0% 0%,100% 0%,100% 100%,0% 100%)';
  }
  return Object.assign({}, final, overrides);
}

const ease = 'cubic-bezier(.2,.8,.2,1)';

class DemoCard {
  constructor(element, config) {
    this.el = element;
    this.config = config;
    this.canvas = element.querySelector('.desktop');
    this.panel = element.querySelector('.panel');
    this.body = element.querySelector('.panel-content');
    this.open = false;
    this.page = 'settings';
    this.pending = [];
    this.token = 0;
    this.layout();
    if (['center', 'depth', 'hinge', 'fold', 'cascade', 'slit'].includes(config.id)) {
      this.panel.style.transformOrigin = '50% 0%';
    }
    Object.assign(this.panel.style, endStyle(config.id), closed[config.id]);

    const toggleBtn = this.el.querySelector('.toggle');
    if (toggleBtn) {
      toggleBtn.onclick = () => {
        this.autoPlayed = true;
        this.setOpen(!this.open);
      };
    }

    const repeatBtn = this.el.querySelector('.repeat');
    if (repeatBtn) {
      repeatBtn.onclick = () => this.replay();
    }

    this.el.querySelectorAll('[data-page]').forEach(b => {
      b.onclick = () => {
        this.autoPlayed = true;
        const targetPage = b.dataset.page;
        if (this.config.pages && this.open && targetPage !== this.page) {
          this.changePage(targetPage);
        } else {
          if (this.config.pages) this.changePage(targetPage, false);
          this.setOpen(!this.open);
        }
      };
    });

    this.canvas.addEventListener('click', e => {
      if (e.target.closest('[data-close]')) {
        this.setOpen(false);
      } else if (!e.target.closest('.panel,.mini-bar')) {
        this.setOpen(false);
      }
      const toggleTile = e.target.closest('[data-toggle]');
      if (toggleTile) {
        const enabled = toggleTile.getAttribute('aria-pressed') !== 'true';
        toggleTile.setAttribute('aria-pressed', String(enabled));
        toggleTile.classList.toggle('off', !enabled);
        const t = I18N[currentLang].pages.settings;
        const smallLabel = toggleTile.querySelector('small');
        if (smallLabel) smallLabel.textContent = enabled ? t.on : t.off;
      }
    });
  }

  cleanup() {
    this.panel.querySelectorAll('.motion-extra').forEach(el => el.remove());
    this.panel.classList.remove('folding', 'outlining', 'animating');
    for (const child of this.body.children) {
      child.style.removeProperty('opacity');
      child.style.removeProperty('transform');
    }
    this.body.style.opacity = '1';
  }

  stop() {
    this.pending.forEach(clearTimeout);
    this.pending = [];
    for (const a of this.panel.getAnimations({ subtree: true })) {
      try { a.commitStyles(); } catch (_) {}
      a.cancel();
    }
    this.cleanup();
    this.token++;
  }

  layout() {
    const dimensions = { settings: [290, 240], calendar: [330, 250], notifications: [290, 240], timeline: [290, 160] };
    const [desiredWidth, height] = this.config.pages ? dimensions[this.page] : dimensions.settings;
    const width = Math.min(desiredWidth, this.canvas.clientWidth - 28);
    let left = this.canvas.clientWidth - width - 15;
    if (this.config.pages) {
      const source = this.el.querySelector('[data-page="' + this.page + '"]');
      if (source) {
        const r = source.getBoundingClientRect(), c = this.canvas.getBoundingClientRect();
        left = Math.max(14, Math.min(this.canvas.clientWidth - width - 14, r.left - c.left + r.width / 2 - width / 2));
      }
    }
    this.panel.style.right = 'auto';
    Object.assign(this.panel.style, { left: left + 'px', width: width + 'px', height: height + 'px' });
  }

  update() {
    const t = I18N[currentLang];
    const toggleBtn = this.el.querySelector('.toggle');
    if (toggleBtn) toggleBtn.textContent = this.open ? t.close : t.open;
    const status = this.el.querySelector('.state');
    if (status) {
      status.textContent = this.open ? t.opened : t.closed;
      status.classList.toggle('open', this.open);
    }
    this.panel.setAttribute('aria-hidden', String(!this.open));
    this.panel.inert = !this.open;
    this.el.querySelectorAll('[data-page]').forEach(b => {
      const selected = this.open && (!this.config.pages || b.dataset.page === this.page);
      b.classList.toggle('selected', selected);
      b.setAttribute('aria-expanded', String(selected));
    });
  }

  play(target, frames, options) {
    const a = target.animate(frames, Object.assign({ fill: 'forwards' }, options));
    a.finished.catch(() => {});
    return a;
  }

  setOpen(value, opts) {
    const instant = opts && opts.instant;
    this.stop();
    this.open = value;
    this.update();
    const opened = endStyle(this.config.id);
    const end = value ? opened : Object.assign({}, opened, closed[this.config.id]);
    if (instant) {
      Object.assign(this.panel.style, end);
      this.panel.style.visibility = value ? 'visible' : 'hidden';
      return;
    }
    this.panel.style.visibility = 'visible';
    this.panel.classList.add('animating');
    const computed = getComputedStyle(this.panel);
    const start = { transform: computed.transform, opacity: computed.opacity, clipPath: computed.clipPath, borderRadius: computed.borderRadius };
    let frames = [start, end];
    const id = this.config.id;

    if (value) {
      if (id === 'spring') {
        frames = [
          Object.assign({}, closed.spring, { offset: 0 }),
          { transform: 'translateY(7px)', opacity: 1, offset: 0.57 },
          { transform: 'translateY(-2px)', opacity: 1, offset: 0.79 },
          Object.assign({}, opened, { offset: 1 })
        ];
      } else if (id === 'center') {
        frames = [
          Object.assign({}, opened, closed.center, { offset: 0 }),
          Object.assign({}, opened, { clipPath: 'inset(49.5% 0% 49.5% 0% round 14px)', offset: 0.38 }),
          Object.assign({}, opened, { offset: 1 })
        ];
      } else if (id === 'slit') {
        frames = [
          Object.assign({}, opened, closed.slit, { offset: 0 }),
          Object.assign({}, opened, { clipPath: 'polygon(0% 0%,100% 0%,100% 1%,0% 1%)', offset: 0.38 }),
          Object.assign({}, opened, { offset: 1 })
        ];
      } else if (id === 'liquid') {
        frames = [
          Object.assign({}, opened, closed.liquid, { offset: 0 }),
          { transform: 'translateY(-12px) scale(.48,.65)', borderRadius: '58% 42% 35% 65% / 65% 40% 60% 35%', opacity: 1, offset: 0.36 },
          { transform: 'translateY(3px) scale(1.025,.97)', borderRadius: '25px 20px 32px 18px', opacity: 1, offset: 0.74 },
          Object.assign({}, opened, { offset: 1 })
        ];
      }
    }
    const duration = (this.config.duration || 540) * (value ? 1 : 0.8) / speed;
    const animation = this.play(this.panel, frames, { duration, easing: ['spring', 'center', 'liquid', 'slit'].includes(id) ? 'linear' : ease });

    const token = this.token;
    animation.finished.then(() => {
      if (token !== this.token) return;
      for (const a of this.panel.getAnimations({ subtree: true })) a.cancel();
      Object.assign(this.panel.style, end);
      this.cleanup();
      if (!this.open) this.panel.style.visibility = 'hidden';
    }).catch(() => {});
  }

  replay() {
    this.autoPlayed = true;
    this.setOpen(false, { instant: true });
    this.pending.push(setTimeout(() => this.setOpen(true), 90));
  }

  changePage(page, animate = true) {
    if (page === this.page) return;
    this.stop();
    const previous = { left: this.panel.offsetLeft, width: this.panel.offsetWidth, height: this.panel.offsetHeight };
    this.page = page;

    // Toggle hidden property on pre-rendered panel pages
    this.panel.querySelectorAll('.panel-page').forEach(pageEl => {
      pageEl.hidden = (pageEl.dataset.page !== page);
    });

    this.layout();
    this.update();
    if (animate && this.open) {
      const next = { left: this.panel.style.left, width: this.panel.style.width, height: this.panel.style.height };
      const old = { left: previous.left + 'px', width: previous.width + 'px', height: previous.height + 'px' };
      const duration = 540 / speed;
      this.play(this.panel, [old, next], { duration, easing: ease });
      this.play(this.body, [{ opacity: 0 }, { opacity: 1 }], { duration, easing: 'linear' });
    }
  }
}

function initMotionStudies() {
  controllers.length = 0;
  const t = I18N[currentLang];
  document.querySelectorAll('.study').forEach((el, i) => {
    controllers.push(new DemoCard(el, t.studies[i]));
  });

  document.querySelectorAll('.copy-qml').forEach(btn => {
    btn.onclick = () => {
      const qmlId = btn.dataset.qmlId;
      const snippet = '// Quickshell QML PanelMotion definition for "' + qmlId + '"\n' +
        'NumberAnimation on progress {\n' +
        '    duration: Session.motionMs > 0 ? ' + (qmlId === 'spring' ? 720 : 540) + ' : 0\n' +
        '    easing.type: ' + (qmlId === 'spring' ? 'Easing.OutBack' : 'Easing.OutCubic') + '\n' +
        '}';
      navigator.clipboard.writeText(snippet).then(() => {
        const label = btn.querySelector('.qml-label');
        if (label) {
          const orig = label.textContent;
          label.textContent = t.copied;
          setTimeout(() => { label.textContent = orig; }, 1800);
        }
      }).catch(() => {});
    };
  });
}

// Global initialization
document.addEventListener('DOMContentLoaded', () => {
  initMotionStudies();
  updateLanguage(currentLang);
  applyTheme(currentTheme, false);
  tick();
  setInterval(tick, 1000);
  void checkBackend();
  setInterval(() => { void checkBackend(); }, 4000);

  // Tab Navigation
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.onclick = () => {
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-view').forEach(v => v.classList.remove('active'));
      btn.classList.add('active');
      const targetView = document.querySelector('#view-' + btn.dataset.tab);
      if (targetView) targetView.classList.add('active');
    };
  });

  // Language buttons
  document.querySelectorAll('.lang-switch button').forEach(btn => {
    btn.onclick = () => updateLanguage(btn.dataset.lang);
  });

  // Theme buttons
  document.querySelectorAll('.theme-pill-btn[data-theme]').forEach(btn => {
    btn.onclick = () => applyTheme(btn.dataset.theme);
  });

  // Mode buttons
  const btnWork = document.querySelector('#btn-work-mode');
  const btnVibe = document.querySelector('#btn-vibe-mode');
  if (btnWork && btnVibe) {
    btnWork.onclick = () => {
      btnWork.classList.add('active');
      btnVibe.classList.remove('active');
      void sendAction('mode', 'work');
    };
    btnVibe.onclick = () => {
      btnVibe.classList.add('active');
      btnWork.classList.remove('active');
      void sendAction('mode', 'vibe');
    };
  }

  // Speed buttons
  document.querySelectorAll('[data-speed]').forEach(btn => {
    btn.onclick = () => {
      speed = Number(btn.dataset.speed);
      document.querySelectorAll('[data-speed]').forEach(b => b.setAttribute('aria-pressed', String(b === btn)));
    };
  });

  // Play All / Close All
  const playAllBtn = document.querySelector('#play-all');
  if (playAllBtn) playAllBtn.onclick = () => controllers.forEach(c => c.replay());

  const closeAllBtn = document.querySelector('#close-all');
  if (closeAllBtn) closeAllBtn.onclick = () => controllers.forEach(c => c.setOpen(false));

  // Workspaces
  document.querySelectorAll('.ws-pill').forEach(pill => {
    pill.onclick = () => {
      document.querySelectorAll('.ws-pill').forEach(p => p.classList.remove('active'));
      pill.classList.add('active');
    };
  });

  // Hover-Faceted Quick Menu
  const qsPill = document.querySelector('#qs-pill-btn');
  const hoverMenu = document.querySelector('#hover-menu');
  if (qsPill && hoverMenu) {
    qsPill.onclick = () => {
      hoverMenu.classList.toggle('show');
      qsPill.classList.toggle('active');
    };
    const viewport = document.querySelector('#viewport');
    if (viewport) {
      viewport.onclick = (e) => {
        if (!e.target.closest('#qs-pill-btn') && !e.target.closest('#hover-menu')) {
          hoverMenu.classList.remove('show');
          qsPill.classList.remove('active');
        }
      };
    }
  }
});

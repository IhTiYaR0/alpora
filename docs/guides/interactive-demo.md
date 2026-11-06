# ALPORA Interactive Shell & Design Lab

Tài liệu hướng dẫn kiến trúc và cách sử dụng module Demo đa nền tảng (Web Simulator + Native QML Sandbox + Python Micro-server) của ALPORA.

---

## 1. Tổng quan Kiến trúc

Module Demo được chuẩn hóa thành một module độc lập thuộc hệ sinh thái ALPORA:
- **Backend (Python)**: `poly_shell/system/demo_server.py` cung cấp HTTP micro-server không phụ thuộc thư viện ngoài (zero-dependency), phục vụ tài nguyên tĩnh và cung cấp API REST đo lường hệ thống (live telemetry), điều khiển chế độ làm việc (Work / Vibe).
- **Web Sandbox (SPA HTML/CSS/JS)**: `shell/demos/web/` bao gồm:
  - Màn hình mô phỏng Desktop Shell với thanh TopBar, menu Hover-Faceted theo quy chuẩn thiết kế đã phê duyệt (`assets/reference/hover-faceted-approved.png`), và các widget đồng hồ, thông số hệ thống.
  - Phòng thí nghiệm chuyển động (16 Animation Studies) với khả năng tinh chỉnh tốc độ (1x, 0.5x, 0.25x, 0.1x), xem trước hiệu ứng và copy code QML tương ứng.
  - Bộ trưng bày Typography Tiêu chuẩn (Inter Variable, JetBrains Mono, Outfit Variable).
- **Native QML Sandbox**: `shell/demos/DemoRunner.qml` cho phép chạy thử nghiệm cửa sổ Quickshell độc lập trực tiếp trên compositor Wayland mà không làm ảnh hưởng đến shell chính đang chạy.

```
alpora/
├── poly_shell/
│   ├── commands/demo_cmd.py        # CLI handler cho subcommand `poly-shell demo`
│   └── system/demo_server.py       # Micro-server REST API & static server
├── shell/
│   └── demos/
│       ├── DemoRunner.qml          # Native Quickshell Wayland Sandbox
│       └── web/
│           ├── index.html          # Single-Page Application (SPA)
│           ├── style.css           # Semantic palette, responsive grid, glassmorphism
│           └── app.js              # Live telemetry polling, 16 motion engines, i18n
└── tests/
    └── test_demo.py                # Unit test suite cho module demo
```

---

## 2. Hướng dẫn Dòng lệnh (CLI)

### Khởi chạy Giao diện Web Interactive Lab
```bash
poly-shell demo
# hoặc
poly-shell demo web
```
Lệnh sẽ tự động tìm port khả dụng (mặc định 8080), khởi chạy micro-server và mở trình duyệt tại:
`http://127.0.0.1:8080/shell/demos/web/index.html`

### Chạy Micro-server ở chế độ Headless / Tùy chỉnh Port
```bash
poly-shell demo server --port 9000 --no-browser
```

### Chạy Native QML Sandbox trên Hyprland
```bash
poly-shell demo native
```
Lệnh này gọi trực tiếp `quickshell -p shell/demos/DemoRunner.qml` cùng với các biến môi trường cấu hình shell.

---

## 3. Hệ thống REST API

Micro-server cung cấp các endpoint sau:

| Phương thức | Endpoint | Mô tả |
|-------------|----------|-------|
| `GET` | `/` hoặc `/index.html` | Chuyển hướng 302 về `/shell/demos/web/index.html` |
| `GET` | `/api/state` | Trả về thông số CPU (%), RAM (GB), Pin (%), nền tảng OS, chế độ và theme đang kích hoạt |
| `GET` | `/api/themes` | Đọc danh sách 7 theme có sẵn và bảng màu từ `assets/themes/*.json` |
| `POST` | `/api/action` | Nhận action thay đổi `mode` (`work`/`vibe`) hoặc `theme` và cập nhật vào runtime session |

---

## 4. Ba Không Gian Trải Nghiệm trong Web Lab

1. **Desktop Shell Simulator**:
   - Thử nghiệm thanh TopBar trực quan, chuyển đổi 4 Workspaces.
   - Menu nhanh đa tầng Hover-Faceted Quick Menu (Wi-Fi, Bluetooth, Power Slider, Volume, Brightness).
   - Widget Hero Clock sử dụng font hình học **Outfit Display**.
   - Widget Developer Metrics hiển thị trực tiếp dữ liệu đo lường từ Python backend sử dụng font **JetBrains Mono**.
   - Bảng đổi nhanh 7 theme: Alpine, Moon Lake, Forest Mist, Northern Lights, Warm Desert, Rose Sunset, Timeline.

2. **Panel Motion Lab (16 Studies)**:
   - Nghiên cứu 16 đường cong chuyển động (Soft Slide, Curtain Drop, Origin Pop, Subtle Pop-in, Spring Bounce, Morph Switch, Circular Iris, Depth Perspective,...).
   - Thử nghiệm ở các tốc độ thực tế từ `1x` đến `0.1x` (siêu chậm).
   - Nút copy mã định nghĩa chuyển động QML trực tiếp vào clipboard.

3. **Typography Suite Showcase**:
   - Trưng bày các thông số và ví dụ trực quan của 3 font chữ chủ đạo đã được nhúng:
     - **Inter Variable**: Giao diện điều khiển UI, menu, nhãn.
     - **JetBrains Mono**: Terminal, code ligatures, thông số kỹ thuật.
     - **Outfit Variable**: Chữ số đồng hồ hiển thị lớn, tiêu đề trang trọng.


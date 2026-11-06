# Quy Trình Quản Lý & Đồng Bộ Dotfiles (Symlink & Git Workflow)

Tài liệu này hướng dẫn cách quản lý toàn bộ cấu hình hệ thống và giao diện **ALPORA** tập trung trong một repository duy nhất bằng **GNU Stow** (hoặc **Chezmoi**), kèm chiến lược phân nhánh Git và bảo mật thông tin nhạy cảm.

---

## 1. Workflow Quản Lý & Liên Kết Cấu Hình (Symlink Management)

### Nguyên Lý Hoạt Động
Thay vì sao chép thủ công các file cấu hình vào `~/.config/`, toàn bộ dotfiles được lưu tập trung trong thư mục `dotfiles/` của repo này. Ta sử dụng **Symlink (liên kết mềm)** trỏ từ `~/.config/...` về repo:
* **Khi bạn chỉnh sửa cấu hình** tại bất kỳ ứng dụng nào trong hệ thống (`~/.config/hypr/`, `~/.config/poly-shell/`), file gốc trong repo này **tự động cập nhật ngay lập tức**.
* Bạn không bao giờ phải nhớ lệnh copy file ngược lại vào git!

### Cấu Trúc Gói Dotfiles Chuẩn (GNU Stow Structure)
```
dotfiles/
├── hypr/
│   └── .config/
│       └── hypr/
│           ├── alpora-hypridle.conf
│           └── hyprlock.conf
├── poly-shell/
│   └── .config/
│       └── poly-shell/
│           └── settings.json
└── systemd/
    └── .config/
        └── systemd/
            └── user/
                └── poly-shell.service
```

### Các Lệnh Thao Tác Nhanh

Script quản lý [`scripts/stow-dotfiles.sh`](file:///d:/code/alpora/scripts/stow-dotfiles.sh) đã tích hợp sẵn: tự động dùng `stow` nếu có, hoặc tự động tạo symlink an toàn có backup tự động nếu chưa cài `stow`.

#### 1. Kiểm tra trạng thái liên kết
```bash
./scripts/stow-dotfiles.sh status
```
Hiển thị bảng trạng thái xem từng file cấu hình đã được liên kết (`[LINKED]`), bị xung đột (`[EXISTS]`), hay đang thiếu (`[MISSING]`).

#### 2. Kích hoạt toàn bộ Symlink
```bash
./scripts/stow-dotfiles.sh link
```
*Tự động sao lưu các file cấu hình cũ (nếu có) sang `~/.config/alpora-backups/` và tạo symlink trỏ về repo.*

#### 3. Sử dụng trực tiếp bằng GNU Stow
Nếu bạn thích dùng trực tiếp lệnh `stow`:
```bash
cd ~/dotfiles
stow -v -R -t ~ hypr poly-shell systemd
```

#### 4. Gỡ bỏ Symlink sạch sẽ
```bash
./scripts/stow-dotfiles.sh unlink
```

---

## 2. Workflow Kiểm Soát Phiên Bản & Đồng Bộ (Git Workflow)

### Chiến Lược Phân Nhánh (Branching Strategy)

* **Nhánh `main` (Production / Daily Driver)**:
  * Chứa toàn bộ cấu hình ổn định nhất đang chạy trơn tru hàng ngày.
  * Chỉ merge vào `main` khi cấu hình mới đã được kiểm tra không bị lỗi giật lag hay crash compositor.
* **Nhánh `dev` hoặc `testing` (Ricing / Sandbox)**:
  * Dùng khi bạn muốn "độ" (rice) giao diện mới, thử nghiệm animation curves, đổi màu sắc chủ đề, thử nghiệm widget hoặc chuyển đổi compositor (ví dụ từ Hyprland sang Niri/Sway).

### Quy Trình Thao Tác Hàng Ngày

1. **Tạo nhánh thử nghiệm khi độ giao diện**:
   ```bash
   git checkout -b dev-glass-theme
   ```
2. **Chỉnh sửa cấu hình & kiểm tra trực tiếp**:
   Vì đã symlink, bạn chỉ cần sửa trong trình soạn thảo hoặc ứng dụng và reload shell.
3. **Commit với thông điệp rõ ràng theo chuẩn Conventional Commits**:
   ```bash
   git add .
   git commit -m "feat(hyprland): add keybind for interactive screenshot"
   ```
4. **Merge về `main` sau khi ưng ý**:
   ```bash
   git checkout main
   git merge dev-glass-theme
   git push origin main
   ```

---

## 3. Bảo Vệ File Nhạy Cảm & Credentials (.gitignore)

Repository đã được thiết lập bộ quy tắc [`.gitignore`](file:///d:/code/alpora/.gitignore) nghiêm ngặt để **ngăn chặn tuyệt đối việc vô tình commit các thông tin riêng tư**:

| Loại Dữ Liệu Nhạy Cảm | Các Mẫu Được Bảo Vệ Trong .gitignore |
| :--- | :--- |
| **SSH Keys** | `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `*.pem`, `*.key` |
| **GPG & Chứng chỉ** | `*.gpg`, `*.asc`, `*.p12`, `*.pfx`, `*.keystore` |
| **Mật khẩu Wi-Fi & Mạng** | `hotspot.json`, `*.nmconnection`, `wifi-credentials.json` |
| **Token & API Keys** | `.env*`, `*.secret`, `secrets.*`, `credentials.json`, `token.json` |
| **Trạng thái cục bộ & Socket** | `.local/`, `*.sock`, `instance.lock`, `airplane-restore.json` |

> [!IMPORTANT]
> Nếu bạn muốn lưu trữ mật khẩu hoặc token cá nhân trong repo dotfiles để đồng bộ giữa nhiều máy, hãy sử dụng **Chezmoi** kết hợp với **GPG** hoặc **age** để mã hóa file (ví dụ `secrets.json.age`), tuyệt đối không lưu file văn bản thô.

---

## 4. Thiết Lập Trên Máy Mới (1-Click Sync)

Khi bạn cài đặt một máy tính mới (Arch Linux, laptop hoặc PC phụ), chỉ cần chạy 2 lệnh:

```bash
# 1. Clone repository về thư mục cá nhân
git clone https://github.com/pnam-it309/alpora.git ~/dotfiles

# 2. Tạo symlink tự động toàn bộ cấu hình
cd ~/dotfiles
./scripts/stow-dotfiles.sh link
```

Toàn bộ hệ thống phím tắt, giao diện, thanh dock, control center, màn hình khóa và quy tắc cửa sổ sẽ hoạt động ngay lập tức đồng nhất 100% với máy chính của bạn!

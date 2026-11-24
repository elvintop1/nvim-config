# Neovim + competitive programming terminal setup

Config Neovim của bạn, kèm một script cài môi trường C++ và công cụ luyện thi cho **Linux, macOS và Windows**. Giữ runner, templates, snippets, completion và LSP hiện có; bổ sung tải samples, test, nộp bài và xem verdict trong terminal của Neovim.

## Cài đặt

Linux/macOS, hoặc **Git Bash trên Windows**:

```bash
git clone https://github.com/elvintop1/nvim-config.git
cd nvim-config
bash setup.sh --dry-run
bash setup.sh
source "$HOME/.local/share/cpw/env.sh"
cpw doctor
nvim
```

Windows cần Git for Windows để có Git Bash. Nếu chưa cài, chạy trong PowerShell rồi mở **Git Bash**:

```powershell
winget install --id Git.Git --exact
```

`.sh` không chạy trực tiếp trong PowerShell/cmd.exe. Windows native dùng MSYS2/MinGW64 do script cài vào `C:/msys64`; có thể đổi bằng biến `CPW_MSYS2_ROOT`. Không trộn công cụ cài trong WSL với Neovim native Windows.

Mặc định, script:

1. Kiểm tra/cài compiler và thư viện cần để build công cụ.
2. Cài uv, môi trường Python riêng, `oj`, Kattis CLI và `submitter`.
3. Cài Node, Go, fork `cf-tool` có browser mode và Chrome bridge.
4. Chuẩn bị thư mục extension và đăng ký Chrome native host cho tài khoản hiện tại.
5. Cài Neovim portable; triển khai **chính config trong repo này** vào vị trí Neovim sử dụng.
6. Tạo `cpw`, `oj`, `kattis`, `cf`, file kích hoạt PATH và hướng dẫn `NEXT_STEPS.txt`.

Neovim config có sẵn được chuyển sang `nvim.backup-<timestamp>` trước lần triển khai đầu tiên. Chạy lại từ cùng checkout cập nhật config đã triển khai. Config, snippets và templates nên được chỉnh trong checkout này rồi chạy lại setup. Nếu checkout đã nằm đúng thư mục config thì dùng trực tiếp tại đó.

Lần đầu mở Neovim, `lazy.nvim` cài plugin theo config/lockfile hiện có; dùng `:Lazy sync` nếu cần. Mason quản lý các language server đã khai báo. Bạn có thể cài Nerd Font để hiển thị icon; font không ảnh hưởng test/nộp bài.

### Tùy chọn

```bash
# Chỉ oj + Kattis + submitter, bỏ Go/Node/cf/browser bridge
bash setup.sh --minimal

# Máy đã có Neovim/config: chỉ cài công cụ CP
bash setup.sh --no-nvim

# Giữ nguyên shell startup files; kích hoạt env.sh thủ công
bash setup.sh --no-shell

# Đã có compiler, OpenSSL/pkg-config và thư viện build cần thiết
bash setup.sh --skip-system

# Không tải extension hoặc đăng ký native browser host
bash setup.sh --skip-extensions

# Đường dẫn có dấu cách cũng được hỗ trợ
bash setup.sh --prefix "$HOME/CP Tools"
source "$HOME/CP Tools/env.sh"
```

`--dry-run` và `--help` không tải hoặc ghi file. Trên macOS, nếu thiếu Xcode Command Line Tools, script mở hộp thoại cài đặt; hoàn tất rồi chạy lại lệnh. Linux tự cài native packages qua apt, dnf hoặc pacman; các distro khác dùng `--skip-system` sau khi cài dependencies. Pacman chạy full upgrade để tránh partial upgrade.

Script không cài browser thay bạn. Cần Chrome/Chromium để dùng browser mode của `cf-tool`; `submitter` có thể dùng browser mặc định. Các bước đăng nhập, xác nhận hệ điều hành và kích hoạt extension vẫn cần thao tác của bạn.

## Đăng nhập và bật extension

### Codeforces / AtCoder / các sàn khác

```bash
cpw login codeforces
cpw login atcoder
```

Với Codeforces, tạo API key/secret ở [API settings](https://codeforces.com/settings/api) và nhập **trong terminal của công cụ**. API dùng theo dõi verdict; việc nộp bài vẫn qua browser đã đăng nhập.

Bật **Submitter Helper**:

1. Mở `chrome://extensions` (Edge/Brave cũng hỗ trợ extension unpacked).
2. Bật Developer mode → Load unpacked.
3. Chọn `~/.local/share/cpw/extensions/submitter-helper` hoặc đường dẫn trong `NEXT_STEPS.txt`.
4. Đăng nhập Codeforces/AtCoder trong browser.

Không có helper: `submitter` mở form và chép code vào clipboard để bạn dán/nộp. Có helper: nó tự điền source, chọn ngôn ngữ và bấm nộp. Nếu không khớp compiler, chọn thủ công hoặc truyền tên ngôn ngữ bằng `--language`.

Thông tin đăng nhập của các lệnh `cpw login`/`cpw submit` được sử dụng với cùng working directory riêng: `<prefix>/state`. Không đưa API key, cookie hoặc `.kattisrc` vào Git.

### Kattis

Tải [.kattisrc](https://open.kattis.com/download/kattisrc) sau khi đăng nhập, lưu trong thư mục home:

```bash
kattis -p hello main.cpp
# Hoặc:
cpw kattis -p hello main.cpp
```

### Browser mode của cf-tool

Bản gốc `xalanq/cf-tool` đã archived. Repo cài fork `NetWilliam/cf-tool` và package **`mcp-chrome-bridge`** từ upstream của Chrome MCP.

1. Load unpacked extension Chrome MCP từ đường dẫn `chrome_extension` trong `NEXT_STEPS.txt`.
2. Bấm **Connect** trong popup extension.
3. Đăng nhập Codeforces trong cùng browser.
4. Kiểm tra:

```bash
cf mcp-ping
cpw doctor --browser
cf config   # Chọn template/compiler để dùng cf gen và cf test
```

Nếu bỏ qua đăng ký ở bước setup, có thể chạy `cpw bridge register`. Bridge hoạt động qua native messaging và extension; không cần mở một terminal giữ daemon thường trực.

Các lệnh `cf parse`, `cf gen`, `cf test`, `cf submit` dùng cấu hình riêng của cf-tool. Luồng `cpw` bên dưới đã cấu hình compiler và template từ repo này.

**WSL:** `oj`/compiler hoạt động trong Linux. Native browser bridge đăng ký trong WSL cần browser Linux có GUI (WSLg). Để dùng Chrome Windows với toàn bộ browser mode, dùng setup trong Git Bash và Neovim Windows; script không tự nối native host xuyên Windows/WSL.

## Làm bài từ terminal

```bash
mkdir -p ~/cp
cd ~/cp
cpw new https://atcoder.jp/contests/abc388/tasks/abc388_a abc388-a
cd abc388-a
nvim main.cpp
cpw test
cpw submit
```

Lệnh chính:

| Lệnh | Tác dụng |
|---|---|
| `cpw new URL [DIR]` | Tạo `main.cpp`, metadata, tải samples |
| `cpw new URL DIR --no-download` | Tạo bài để tự nhập samples |
| `cpw samples` | Tải samples cho bài hiện tại |
| `cpw test` | Compile C++17 và chạy samples bằng oj |
| `cpw test --sanitize` | ASan + UBSan trên Linux/macOS |
| `cpw test --timeout 3` | Đổi timeout local cho mỗi test |
| `cpw submit [FILE] --language "C++"` | Nộp source; mặc định `main.cpp` |
| `cpw login SITE` | Đăng nhập tương tác |
| `cpw receive` | Nhận bài/samples từ Competitive Companion |
| `cpw doctor` | Kiểm tra file/công cụ đã cài |

`cpw test` hiện hỗ trợ **C++17**. Có thể chọn compiler khác bằng `CPW_CXX`, ví dụ `CPW_CXX=clang++ cpw test`. Runner F5 hiện có của Neovim vẫn hỗ trợ các ngôn ngữ khác. Chạy đúng samples chỉ xác nhận samples; verdict chính thức do judge trả về khi nộp.

Workspace:

```text
abc388-a/
  main.cpp
  .cpw.json
  .gitignore
  test/
    sample-1.in
    sample-1.out
  .build/
```

`cpw new` từ chối ghi đè thư mục đã tồn tại. Template C++ dùng file `templates/files/cpp/cp.cpp` hiện có; có fallback header chuẩn để dùng được với Clang trên macOS.

### Samples qua Competitive Companion

Codeforces và một số sàn có thể chặn việc lấy trang bằng HTTP. Khi đó dùng [Competitive Companion](https://github.com/jmerle/competitive-companion):

```bash
cd ~/cp
cpw receive
```

Thêm **10043** vào **Custom ports** trong settings của extension, mở trang đề bài rồi bấm Competitive Companion. Công cụ nhận qua `127.0.0.1`, tạo workspace và lưu samples. Nếu workspace của cùng URL đã tồn tại, receiver cập nhật samples và giữ nguyên source. Ctrl+C để dừng; mở `main.cpp` vừa tạo. Đây là chức năng lấy đề/samples, độc lập với extension nộp bài.

## Dùng trong Neovim

Leader hiện tại là Space. Phím F5/F6/F7 và nhóm `<leader>r` giữ nguyên.

| Phím | Lệnh | Tác dụng |
|---|---|---|
| `<Space>pn` | `:CPNew` | Nhập URL và thư mục bài |
| `<Space>pt` | `:CPTest` | Lưu source, compile và chạy samples |
| | `:CPTest!` | Test với sanitizer |
| `<Space>ps` | `:CPSubmit` | Lưu và nộp **file đang mở** |
| | `:CPSubmit C++17` | Chọn tên ngôn ngữ/compiler |
| `<Space>pi` | `:CPSamples` | Tải samples |
| `<Space>pr` | `:CPReceive` | Mở receiver Competitive Companion |
| `<Space>pl` | `:CPLogin` | Đăng nhập judge |
| `<Space>pd` | `:CPDoctor` | Kiểm tra setup |
| | `:CPDoctor!` | Kiểm tra thêm browser connection |

Output hiện trong terminal split. Esc chuyển sang normal mode; `q` đóng split. Các lệnh nhận diện workspace từ `.cpw.json` gần file hiện tại, nên bạn không cần đổi cwd toàn cục trong Neovim.

Nếu dùng prefix tùy chỉnh nhưng không triển khai config bằng script, thêm vào `init.lua` trước `core.competitive.setup()`:

```lua
vim.g.cpw_prefix = "/absolute/path/to/CP Tools"
```

Neovim gọi Python bằng argv trực tiếp, không phụ thuộc việc GUI Neovim có đọc `.bashrc` hay không. Windows dùng đường dẫn native; script setup vẫn chạy bằng Git Bash.

Templates/snippets: [TEMPLATES.md](TEMPLATES.md), [SNIPPETS.md](SNIPPETS.md).

## Kiểm tra và bảo trì

```bash
bash -n setup.sh
python3 -m unittest discover -s tests -v
nvim --headless -u NONE -l tests/neovim.lua

# Kiểm tra compiler + oj thực tế sau khi setup
CPW_TEST_PREFIX="$HOME/.local/share/cpw" python3 -m unittest discover -s tests -v
```

GitHub Actions có kiểm tra trên Ubuntu, macOS và Windows. Workflow `Install smoke test` có thể chạy thủ công để cài thật và kiểm tra sample đúng/sai; nó không đăng nhập tài khoản hoặc gửi lời giải lên judge.

Các phiên bản chính/commit nằm trong `config/versions.json`; Node, Go, Neovim và Chrome extension có SHA256. Rust stable, bootstrap installers và Python/npm dependencies gián tiếp vẫn phụ thuộc upstream; đây không phải lockfile hermetic cho toàn bộ toolchain. Cập nhật pin sau khi kiểm tra lại; chạy lại setup để áp dụng.

Cài đặt riêng nằm dưới `<prefix>`; native build packages/MSYS2, shell profile và browser registration nằm ngoài đó. `--no-shell --no-nvim --skip-extensions --skip-system` phù hợp cho môi trường kiểm thử cách ly đã có build dependencies.

import os
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Optional


APP_BOOTSTRAP_DIR = Path(__file__).resolve().parent
VENV_ROOT = APP_BOOTSTRAP_DIR / ".venv"
VENV_PYW = APP_BOOTSTRAP_DIR / ".venv" / "Scripts" / "pythonw.exe"
if os.name == "nt" and VENV_PYW.is_file():
    if Path(sys.prefix).resolve() != VENV_ROOT.resolve():
        subprocess.Popen(
            [str(VENV_PYW), str(Path(__file__).resolve()), *sys.argv[1:]],
            cwd=str(APP_BOOTSTRAP_DIR),
            creationflags=0x08000000,
        )
        raise SystemExit(0)


from PySide6.QtCore import (
    QEasingCurve,
    QEvent,
    QPoint,
    QParallelAnimationGroup,
    QProcess,
    QPropertyAnimation,
    QRect,
    Qt,
    QUrl,
    Signal,
)
from PySide6.QtGui import (
    QCloseEvent,
    QDesktopServices,
    QDragEnterEvent,
    QDropEvent,
    QMouseEvent,
    QPainter,
    QPen,
)
from PySide6.QtWidgets import (
    QApplication,
    QFileDialog,
    QFrame,
    QGraphicsOpacityEffect,
    QHBoxLayout,
    QLabel,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QProgressBar,
    QSizePolicy,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)


APP_TITLE = "Lua Obfuscator"
PRESET_MAP = {
    "Low": "light",
    "Medium": "balanced",
    "High": "maximum",
}
TARGET_MAP = {
    "Lua 5.4": "lua",
    "Roblox Luau": "luau",
}
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")


class TrafficLightButton(QPushButton):
    def __init__(self, color_name: str, tooltip: str, parent=None):
        super().__init__(parent)
        self.setObjectName(color_name)
        self.setToolTip(tooltip)
        self.setFixedSize(13, 13)
        self.setCursor(Qt.PointingHandCursor)


class TitleBar(QFrame):
    def __init__(self, host):
        super().__init__(host)
        self.host = host
        self.drag_offset = QPoint()
        self.setObjectName("titleBar")
        self.setFixedHeight(38)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(14, 0, 14, 0)
        layout.setSpacing(8)

        maximize_button = TrafficLightButton("maximizeDot", "Maximize")
        minimize_button = TrafficLightButton("minimizeDot", "Minimize")
        close_button = TrafficLightButton("closeDot", "Close")

        close_button.clicked.connect(host.close)
        minimize_button.clicked.connect(host.showMinimized)
        maximize_button.clicked.connect(self.toggle_maximized)

        controls = QHBoxLayout()
        controls.setContentsMargins(0, 0, 0, 0)
        controls.setSpacing(8)
        controls.addWidget(maximize_button)
        controls.addWidget(minimize_button)
        controls.addWidget(close_button)

        controls_holder = QWidget()
        controls_holder.setFixedWidth(64)
        controls_holder.setLayout(controls)

        title = QLabel(APP_TITLE)
        title.setObjectName("windowTitle")
        title.setAlignment(Qt.AlignCenter)

        left_spacer = QWidget()
        left_spacer.setFixedWidth(64)

        layout.addWidget(left_spacer)
        layout.addStretch()
        layout.addWidget(title)
        layout.addStretch()
        layout.addWidget(controls_holder)

    def toggle_maximized(self):
        if self.host.isMaximized():
            self.host.showNormal()
        else:
            self.host.showMaximized()

    def mouseDoubleClickEvent(self, event: QMouseEvent):
        if event.button() == Qt.LeftButton:
            self.toggle_maximized()
            event.accept()

    def mousePressEvent(self, event: QMouseEvent):
        if event.button() == Qt.LeftButton:
            self.drag_offset = (
                event.globalPosition().toPoint()
                - self.host.frameGeometry().topLeft()
            )
            event.accept()

    def mouseMoveEvent(self, event: QMouseEvent):
        if event.buttons() & Qt.LeftButton and not self.host.isMaximized():
            self.host.move(event.globalPosition().toPoint() - self.drag_offset)
            event.accept()


class ChevronButton(QPushButton):
    def paintEvent(self, event):
        super().paintEvent(event)

        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        painter.setPen(QPen(Qt.white, 1.4))

        x = self.width() - 20
        y = self.height() // 2 - 1
        painter.drawLine(x - 4, y - 2, x, y + 2)
        painter.drawLine(x, y + 2, x + 4, y - 2)


class AnimatedDropdown(QWidget):
    changed = Signal(str)

    def __init__(self, items, current_index=0, parent=None):
        super().__init__(parent)
        self.items = list(items)
        self._current = self.items[current_index]
        self._animation = None

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.button = ChevronButton(self._current)
        self.button.setObjectName("dropdownButton")
        self.button.setMinimumHeight(38)
        self.button.clicked.connect(self.toggle_popup)
        layout.addWidget(self.button)

        self.popup = QFrame(
            None,
            Qt.Tool | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint,
        )
        self.popup.setObjectName("dropdownPopup")
        self.popup.setAttribute(Qt.WA_TranslucentBackground)

        outer = QVBoxLayout(self.popup)
        outer.setContentsMargins(0, 0, 0, 0)

        surface = QFrame()
        surface.setObjectName("dropdownSurface")

        surface_layout = QVBoxLayout(surface)
        surface_layout.setContentsMargins(5, 5, 5, 5)
        surface_layout.setSpacing(2)

        for item in self.items:
            option = QPushButton(item)
            option.setObjectName("dropdownOption")
            option.setMinimumHeight(32)
            option.clicked.connect(
                lambda checked=False, value=item: self.select(value)
            )
            surface_layout.addWidget(option)

        outer.addWidget(surface)

        self.opacity_effect = QGraphicsOpacityEffect(self.popup)
        self.popup.setGraphicsEffect(self.opacity_effect)

    def currentText(self):
        return self._current

    def select(self, value):
        self._current = value
        self.button.setText(value)
        self.changed.emit(value)
        self.hide_popup()

    def toggle_popup(self):
        if self.popup.isVisible():
            self.hide_popup()
        else:
            self.show_popup()

    def show_popup(self):
        popup_height = len(self.items) * 34 + 12
        popup_width = self.width()

        button_top_left = self.mapToGlobal(QPoint(0, 0))
        below_y = button_top_left.y() + self.height() + 4

        screen = QApplication.screenAt(button_top_left)
        available = screen.availableGeometry() if screen else QRect()

        if available and below_y + popup_height > available.bottom():
            final_y = button_top_left.y() - popup_height - 4
            start_y = final_y + 8
        else:
            final_y = below_y
            start_y = final_y - 8

        end_rect = QRect(
            button_top_left.x(),
            final_y,
            popup_width,
            popup_height,
        )
        start_rect = QRect(
            button_top_left.x(),
            start_y,
            popup_width,
            popup_height,
        )

        QApplication.instance().installEventFilter(self)

        self.popup.setGeometry(start_rect)
        self.opacity_effect.setOpacity(0.0)
        self.popup.show()
        self.popup.raise_()

        geometry_animation = QPropertyAnimation(self.popup, b"geometry")
        geometry_animation.setDuration(150)
        geometry_animation.setStartValue(start_rect)
        geometry_animation.setEndValue(end_rect)
        geometry_animation.setEasingCurve(QEasingCurve.OutCubic)

        opacity_animation = QPropertyAnimation(self.opacity_effect, b"opacity")
        opacity_animation.setDuration(150)
        opacity_animation.setStartValue(0.0)
        opacity_animation.setEndValue(1.0)
        opacity_animation.setEasingCurve(QEasingCurve.OutCubic)

        group = QParallelAnimationGroup(self)
        group.addAnimation(geometry_animation)
        group.addAnimation(opacity_animation)

        self._animation = group
        group.start()

    def hide_popup(self):
        if not self.popup.isVisible():
            return

        QApplication.instance().removeEventFilter(self)

        current_rect = self.popup.geometry()
        end_rect = QRect(
            current_rect.x(),
            current_rect.y() - 5,
            current_rect.width(),
            current_rect.height(),
        )

        geometry_animation = QPropertyAnimation(self.popup, b"geometry")
        geometry_animation.setDuration(100)
        geometry_animation.setStartValue(current_rect)
        geometry_animation.setEndValue(end_rect)
        geometry_animation.setEasingCurve(QEasingCurve.InCubic)

        opacity_animation = QPropertyAnimation(self.opacity_effect, b"opacity")
        opacity_animation.setDuration(100)
        opacity_animation.setStartValue(self.opacity_effect.opacity())
        opacity_animation.setEndValue(0.0)
        opacity_animation.setEasingCurve(QEasingCurve.InCubic)

        group = QParallelAnimationGroup(self)
        group.addAnimation(geometry_animation)
        group.addAnimation(opacity_animation)
        group.finished.connect(self.popup.hide)

        self._animation = group
        group.start()

    def eventFilter(self, watched, event):
        if self.popup.isVisible() and event.type() == QEvent.MouseButtonPress:
            global_position = event.globalPosition().toPoint()

            popup_rect = self.popup.frameGeometry()
            button_rect = QRect(
                self.button.mapToGlobal(QPoint(0, 0)),
                self.button.size(),
            )

            if (
                not popup_rect.contains(global_position)
                and not button_rect.contains(global_position)
            ):
                self.hide_popup()

        return super().eventFilter(watched, event)


class LuaObfuscator(QMainWindow):
    def __init__(self):
        super().__init__()

        self.setWindowTitle(APP_TITLE)
        self.setWindowFlags(Qt.Window | Qt.FramelessWindowHint)
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setAcceptDrops(True)

        self.resize(660, 570)
        self.setMinimumSize(620, 530)

        self.app_dir = Path(__file__).resolve().parent
        self.source_file: Optional[Path] = None
        self.output_folder = Path.home() / "Downloads"
        self.output_file: Optional[Path] = None
        self.process: Optional[QProcess] = None
        self.work_dir: Optional[Path] = None
        self.staged_output: Optional[Path] = None
        self.active_target: Optional[str] = None
        self.running = False
        self.cancel_requested = False
        self.last_log_message = ""

        self.lua_path = self.find_lua_runtime()
        self.cli_path = self.find_hercules_cli()

        self.apply_style()
        self.build_ui()
        self.report_setup_status()

    @staticmethod
    def _creation_flags():
        return 0x08000000 if os.name == "nt" else 0

    def is_compatible_lua(self, path: Path) -> bool:
        try:
            result = subprocess.run(
                [str(path), "-v"],
                capture_output=True,
                text=True,
                timeout=4,
                creationflags=self._creation_flags(),
            )
            version_text = f"{result.stdout}\n{result.stderr}".lower()
            return "lua 5.4" in version_text
        except (OSError, subprocess.SubprocessError):
            return False

    def find_lua_runtime(self) -> Optional[Path]:
        candidate = self.app_dir / ".runtime" / "lua54" / "lua54.exe"
        try:
            candidate = candidate.resolve()
        except OSError:
            return None
        return candidate if candidate.is_file() and self.is_compatible_lua(candidate) else None

    def find_hercules_cli(self) -> Optional[Path]:
        candidate = self.app_dir / ".runtime" / "hercules" / "src" / "hercules.lua"
        try:
            candidate = candidate.resolve()
        except OSError:
            return None
        if candidate.is_file() and (candidate.parent / "pipeline.lua").is_file():
            return candidate
        return None

    def apply_style(self):
        QApplication.instance().setStyleSheet(
            """
            QWidget {
                color: #f5f5f5;
                font-family: "Segoe UI";
                font-size: 13px;
            }

            QFrame#windowFrame {
                background: #070707;
                border: 1px solid #252525;
                border-radius: 14px;
            }

            QFrame#titleBar {
                background: #070707;
                border: none;
                border-bottom: 1px solid #1c1c1c;
                border-top-left-radius: 14px;
                border-top-right-radius: 14px;
            }

            QLabel#windowTitle {
                color: #bdbdbd;
                font-size: 12px;
                font-weight: 600;
            }

            QPushButton#closeDot,
            QPushButton#minimizeDot,
            QPushButton#maximizeDot {
                border: none;
                border-radius: 6px;
                min-height: 13px;
                max-height: 13px;
                min-width: 13px;
                max-width: 13px;
                padding: 0;
            }

            QPushButton#closeDot { background: #ff5f57; }
            QPushButton#minimizeDot { background: #febc2e; }
            QPushButton#maximizeDot { background: #28c840; }

            QPushButton#closeDot:hover,
            QPushButton#minimizeDot:hover,
            QPushButton#maximizeDot:hover {
                border: 1px solid rgba(0, 0, 0, 90);
            }

            QLabel#label {
                color: #b8b8b8;
                font-size: 12px;
                font-weight: 600;
            }

            QLabel#status {
                color: #8b8b8b;
                font-size: 12px;
            }

            QLabel#note {
                color: #7a7a7a;
                font-size: 11px;
            }

            QFrame#panel {
                background: #0d0d0d;
                border: 1px solid #242424;
                border-radius: 14px;
            }

            QPushButton {
                background: #151515;
                border: 1px solid #2b2b2b;
                border-radius: 10px;
                min-height: 38px;
                padding: 0 14px;
                font-weight: 600;
            }

            QPushButton:hover {
                background: #1d1d1d;
                border-color: #3a3a3a;
            }

            QPushButton:pressed { background: #101010; }

            QPushButton#primary {
                background: #ffffff;
                color: #000000;
                border: none;
                min-height: 42px;
            }

            QPushButton#primary:hover { background: #e7e7e7; }

            QPushButton#small {
                min-height: 28px;
                max-height: 28px;
                border-radius: 8px;
                padding: 0 10px;
                color: #bdbdbd;
                font-size: 11px;
            }

            QPushButton#dropdownButton {
                background: #0a0a0a;
                border: 1px solid #292929;
                border-radius: 10px;
                min-height: 38px;
                padding: 0 38px 0 12px;
                text-align: left;
                font-weight: 500;
            }

            QPushButton#dropdownButton:hover {
                background: #101010;
                border-color: #3b3b3b;
            }

            QFrame#dropdownSurface {
                background: #111111;
                border: 1px solid #303030;
                border-radius: 11px;
            }

            QPushButton#dropdownOption {
                background: transparent;
                border: none;
                border-radius: 7px;
                min-height: 32px;
                padding: 0 10px;
                text-align: left;
                font-weight: 500;
            }

            QPushButton#dropdownOption:hover { background: #242424; }

            QFrame#pathFrame {
                background: #0a0a0a;
                border: 1px solid #292929;
                border-radius: 10px;
            }

            QLabel#pathLabel {
                color: #d7d7d7;
                padding-left: 11px;
            }

            QTextEdit {
                background: #090909;
                color: #c8c8c8;
                border: 1px solid #242424;
                border-radius: 10px;
                padding: 8px;
                font-family: "Cascadia Mono", "Consolas";
                font-size: 11px;
                selection-background-color: #ffffff;
                selection-color: #000000;
            }

            QProgressBar {
                background: #121212;
                border: none;
                border-radius: 3px;
                min-height: 6px;
                max-height: 6px;
            }

            QProgressBar::chunk {
                background: #ffffff;
                border-radius: 3px;
            }

            QScrollBar:vertical {
                width: 8px;
                background: transparent;
            }

            QScrollBar::handle:vertical {
                background: #333333;
                border-radius: 4px;
                min-height: 24px;
            }

            QScrollBar::add-line:vertical,
            QScrollBar::sub-line:vertical { height: 0; }
            """
        )

    def build_ui(self):
        label_gap = 6
        group_gap = 10
        side_button_width = 84

        central = QWidget()
        self.setCentralWidget(central)

        outer = QVBoxLayout(central)
        outer.setContentsMargins(0, 0, 0, 0)

        window_frame = QFrame()
        window_frame.setObjectName("windowFrame")
        outer.addWidget(window_frame)

        window_layout = QVBoxLayout(window_frame)
        window_layout.setContentsMargins(0, 0, 0, 0)
        window_layout.setSpacing(0)

        self.title_bar = TitleBar(self)
        window_layout.addWidget(self.title_bar)

        content = QWidget()
        window_layout.addWidget(content, 1)

        page = QVBoxLayout(content)
        page.setContentsMargins(22, 18, 22, 18)
        page.setSpacing(0)

        panel = QFrame()
        panel.setObjectName("panel")
        panel.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        layout = QVBoxLayout(panel)
        layout.setContentsMargins(18, 16, 18, 16)
        layout.setSpacing(group_gap)

        file_group = QVBoxLayout()
        file_group.setSpacing(label_gap)
        file_label = QLabel("Script file (.lua, .luau, or .txt)")
        file_label.setObjectName("label")
        file_group.addWidget(file_label)

        file_row = QHBoxLayout()
        file_row.setSpacing(8)
        file_frame = QFrame()
        file_frame.setObjectName("pathFrame")
        file_frame.setMinimumHeight(38)
        file_layout = QHBoxLayout(file_frame)
        file_layout.setContentsMargins(0, 0, 0, 0)
        self.file_path_label = QLabel("Choose a file or drag it here")
        self.file_path_label.setObjectName("pathLabel")
        self.file_path_label.setTextInteractionFlags(Qt.NoTextInteraction)
        file_layout.addWidget(self.file_path_label)
        self.file_browse_button = QPushButton("Browse")
        self.file_browse_button.setFixedWidth(side_button_width)
        self.file_browse_button.clicked.connect(self.choose_file)
        file_row.addWidget(file_frame, 1)
        file_row.addWidget(self.file_browse_button)
        file_group.addLayout(file_row)
        layout.addLayout(file_group)

        selectors = QHBoxLayout()
        selectors.setSpacing(10)

        level_column = QVBoxLayout()
        level_column.setSpacing(label_gap)
        level_label = QLabel("Obfuscation level")
        level_label.setObjectName("label")
        self.level_dropdown = AnimatedDropdown(
            ["Low", "Medium", "High"],
            current_index=1,
        )
        self.level_dropdown.changed.connect(self.level_changed)
        level_column.addWidget(level_label)
        level_column.addWidget(self.level_dropdown)

        info_column = QVBoxLayout()
        info_column.setSpacing(label_gap)
        info_label = QLabel("Target")
        info_label.setObjectName("label")
        self.target_dropdown = AnimatedDropdown(
            ["Lua 5.4", "Roblox Luau"],
            current_index=0,
        )
        info_column.addWidget(info_label)
        info_column.addWidget(self.target_dropdown)

        selectors.addLayout(level_column, 1)
        selectors.addLayout(info_column, 1)
        layout.addLayout(selectors)

        self.level_note = QLabel(
            "Medium is the recommended balance. High is much larger and slower."
        )
        self.level_note.setObjectName("note")
        self.level_note.setWordWrap(True)
        layout.addWidget(self.level_note)

        save_group = QVBoxLayout()
        save_group.setSpacing(label_gap)
        output_label = QLabel("Save to")
        output_label.setObjectName("label")
        save_group.addWidget(output_label)

        path_row = QHBoxLayout()
        path_row.setSpacing(8)
        path_frame = QFrame()
        path_frame.setObjectName("pathFrame")
        path_frame.setMinimumHeight(38)
        path_layout = QHBoxLayout(path_frame)
        path_layout.setContentsMargins(0, 0, 0, 0)
        self.output_path_label = QLabel(str(self.output_folder))
        self.output_path_label.setObjectName("pathLabel")
        self.output_path_label.setTextInteractionFlags(Qt.NoTextInteraction)
        path_layout.addWidget(self.output_path_label)
        self.output_browse_button = QPushButton("Browse")
        self.output_browse_button.setFixedWidth(side_button_width)
        self.output_browse_button.clicked.connect(self.choose_output_folder)
        path_row.addWidget(path_frame, 1)
        path_row.addWidget(self.output_browse_button)
        save_group.addLayout(path_row)
        layout.addLayout(save_group)

        self.obfuscate_button = QPushButton("Obfuscate")
        self.obfuscate_button.setObjectName("primary")
        self.obfuscate_button.clicked.connect(self.obfuscate_or_cancel)
        layout.addWidget(self.obfuscate_button)

        progress_group = QVBoxLayout()
        progress_group.setSpacing(label_gap)
        self.progress_bar = QProgressBar()
        self.progress_bar.setTextVisible(False)
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        progress_group.addWidget(self.progress_bar)
        self.status_label = QLabel("Ready")
        self.status_label.setObjectName("status")
        progress_group.addWidget(self.status_label)
        layout.addLayout(progress_group)

        log_group = QVBoxLayout()
        log_group.setSpacing(label_gap)
        log_header = QHBoxLayout()
        log_header.setSpacing(6)
        log_label = QLabel("Log")
        log_label.setObjectName("label")
        self.open_folder_button = QPushButton("Open output")
        self.open_folder_button.setObjectName("small")
        self.open_folder_button.setEnabled(False)
        self.open_folder_button.clicked.connect(self.open_output_folder)
        clear_button = QPushButton("Clear")
        clear_button.setObjectName("small")
        clear_button.clicked.connect(self.clear_log)
        log_header.addWidget(log_label)
        log_header.addStretch()
        log_header.addWidget(self.open_folder_button)
        log_header.addWidget(clear_button)
        log_group.addLayout(log_header)

        self.log_box = QTextEdit()
        self.log_box.setReadOnly(True)
        self.log_box.setPlaceholderText("No activity")
        self.log_box.setMinimumHeight(105)
        log_group.addWidget(self.log_box, 1)
        layout.addLayout(log_group, 1)

        page.addWidget(panel, 1)

    def report_setup_status(self):
        missing = []
        if self.lua_path is None:
            missing.append("Lua 5.4")
        if self.cli_path is None:
            missing.append("Hercules")

        if missing:
            self.status_label.setText("Setup needed")
            self.append_log(
                "Missing: " + ", ".join(missing) + ". Run installer.bat again."
            )
        else:
            self.status_label.setText("Ready")
            self.append_log(f"Lua: {self.lua_path}")
            self.append_log(f"Hercules: {self.cli_path.parent.parent}")

    def level_changed(self, value: str):
        notes = {
            "Low": "Low is fast and produces smaller output.",
            "Medium": "Medium is the recommended balance of protection and size.",
            "High": "High uses every compatible protection. Output can be huge and slower.",
        }
        self.level_note.setText(notes[value])

    def choose_file(self):
        start_folder = (
            str(self.source_file.parent)
            if self.source_file
            else str(Path.home() / "Downloads")
        )
        filename, _ = QFileDialog.getOpenFileName(
            self,
            "Choose Lua or Luau File",
            start_folder,
            "Lua and Luau files (*.lua *.luau *.txt);;All files (*.*)",
        )
        if filename:
            self.set_source_file(Path(filename))

    def set_source_file(self, path: Path):
        path = path.expanduser().resolve()
        if not path.is_file() or path.suffix.lower() not in {".lua", ".luau", ".txt"}:
            self.status_label.setText("Choose a script file")
            self.append_log("Choose a valid .lua, .luau, or .txt file.")
            return

        self.source_file = path
        self.output_folder = path.parent
        self.file_path_label.setText(str(path))
        self.file_path_label.setToolTip(str(path))
        self.output_path_label.setText(str(self.output_folder))
        self.output_path_label.setToolTip(str(self.output_folder))
        self.output_file = None
        self.open_folder_button.setEnabled(False)
        self.status_label.setText("Ready")
        self.append_log(f"Selected: {path.name}")
        if path.suffix.lower() == ".luau":
            self.target_dropdown.select("Roblox Luau")

    def choose_output_folder(self):
        folder = QFileDialog.getExistingDirectory(
            self,
            "Choose Output Folder",
            str(self.output_folder),
        )
        if folder:
            self.output_folder = Path(folder).resolve()
            self.output_path_label.setText(str(self.output_folder))
            self.output_path_label.setToolTip(str(self.output_folder))

    def clear_log(self):
        self.log_box.clear()
        self.last_log_message = ""
        if not self.running:
            self.status_label.setText("Ready")
            self.progress_bar.setRange(0, 100)
            self.progress_bar.setValue(0)

    def append_log(self, message: str):
        message = ANSI_RE.sub("", message).strip()
        if not message or message == self.last_log_message:
            return

        self.last_log_message = message
        self.log_box.append(message)
        scrollbar = self.log_box.verticalScrollBar()
        scrollbar.setValue(scrollbar.maximum())

    def refresh_tool_paths(self):
        if self.lua_path is None or not self.lua_path.is_file():
            self.lua_path = self.find_lua_runtime()
        if self.cli_path is None or not self.cli_path.is_file():
            self.cli_path = self.find_hercules_cli()

    def obfuscate_or_cancel(self):
        if self.running:
            self.cancel_obfuscation()
        else:
            self.start_obfuscation()

    def start_obfuscation(self):
        self.refresh_tool_paths()

        if self.source_file is None or not self.source_file.is_file():
            self.status_label.setText("Choose a file")
            self.append_log("Choose a .lua, .luau, or .txt file first.")
            return

        if self.lua_path is None:
            self.status_label.setText("Lua 5.4 missing")
            self.append_log("Lua 5.4 was not found. Run Installer.bat again.")
            return

        if self.cli_path is None:
            self.status_label.setText("Hercules missing")
            self.append_log("Hercules was not found. Run Installer.bat again.")
            return

        target_label = self.target_dropdown.currentText()
        target = TARGET_MAP[target_label]
        output_extension = ".luau" if target == "luau" else ".lua"
        output_file = self.output_folder / (
            f"{self.source_file.stem}.obfuscated{output_extension}"
        )

        try:
            self.output_folder.mkdir(parents=True, exist_ok=True)
        except OSError as error:
            self.status_label.setText("Invalid output")
            self.append_log(f"Could not create the output folder: {error}")
            return

        if output_file.resolve() == self.source_file.resolve():
            self.status_label.setText("Invalid output")
            self.append_log("The output cannot overwrite the original file.")
            return

        if output_file.exists():
            choice = QMessageBox.question(
                self,
                "Replace output?",
                f"{output_file.name} already exists. Replace it?",
                QMessageBox.Yes | QMessageBox.No,
                QMessageBox.No,
            )
            if choice != QMessageBox.Yes:
                self.status_label.setText("Cancelled")
                return

        preset = PRESET_MAP[self.level_dropdown.currentText()]
        self.cleanup_work_dir()

        try:
            work_root = self.app_dir / ".runtime" / "work"
            work_root.mkdir(parents=True, exist_ok=True)
            self.work_dir = Path(
                tempfile.mkdtemp(prefix="job-", dir=str(work_root))
            )
            staged_source = self.work_dir / (
                f"{self.source_file.stem}{output_extension}"
            )
            shutil.copy2(self.source_file, staged_source)
            self.staged_output = self.work_dir / (
                f"{self.source_file.stem}_obfuscated{output_extension}"
            )
        except OSError as error:
            self.cleanup_work_dir()
            self.status_label.setText("Could not prepare")
            self.append_log(f"Could not prepare the source file: {error}")
            return

        args = [
            str(self.cli_path),
            str(staged_source),
            "--target",
            target,
            f"--{preset}",
            "--no-watermark",
        ]

        self.output_file = output_file
        self.active_target = target
        self.cancel_requested = False
        self.last_log_message = ""
        self.log_box.clear()
        self.open_folder_button.setEnabled(False)

        self.append_log(f"Input: {self.source_file}")
        self.append_log(f"Target: {target_label}")
        self.append_log(f"Preset: {preset} ({self.level_dropdown.currentText()})")
        self.append_log(f"Output: {output_file}")

        self.process = QProcess(self)
        self.process.setWorkingDirectory(str(self.cli_path.parent))
        self.process.setProcessChannelMode(QProcess.MergedChannels)
        self.process.readyReadStandardOutput.connect(self.read_process_output)
        self.process.finished.connect(self.process_finished)
        self.process.errorOccurred.connect(self.process_error)

        self.running = True
        self.obfuscate_button.setText("Cancel")
        self.status_label.setText("Obfuscating...")
        self.progress_bar.setRange(0, 0)
        self.set_controls_enabled(False)

        self.process.start(str(self.lua_path), args)

    def set_controls_enabled(self, enabled: bool):
        self.file_browse_button.setEnabled(enabled)
        self.output_browse_button.setEnabled(enabled)
        self.level_dropdown.setEnabled(enabled)
        self.target_dropdown.setEnabled(enabled)

    def read_process_output(self):
        if not self.process:
            return

        output = bytes(self.process.readAllStandardOutput()).decode(
            "utf-8",
            errors="replace",
        )
        for raw_line in output.splitlines():
            self.append_log(raw_line)

    def cancel_obfuscation(self):
        if self.process and self.process.state() != QProcess.NotRunning:
            self.cancel_requested = True
            self.status_label.setText("Stopping...")
            self.process.kill()

    def validate_staged_output(self) -> bool:
        if self.staged_output is None or not self.staged_output.is_file():
            return False
        if self.staged_output.stat().st_size == 0:
            return False
        if self.active_target != "lua" or self.lua_path is None:
            return True

        compiler_path = self.lua_path.with_name("luac54.exe")
        if not compiler_path.is_file():
            self.append_log("Lua output could not be syntax checked.")
            return True

        try:
            result = subprocess.run(
                [str(compiler_path), "-p", str(self.staged_output)],
                capture_output=True,
                text=True,
                timeout=15,
                creationflags=self._creation_flags(),
            )
        except (OSError, subprocess.SubprocessError) as error:
            self.append_log(f"Lua syntax check failed to start: {error}")
            return False

        if result.returncode != 0:
            details = (result.stdout + result.stderr).strip()
            if details:
                self.append_log(details)
            return False

        self.append_log("Lua 5.4 syntax check passed.")
        return True

    def publish_staged_output(self) -> bool:
        if self.output_file is None or self.staged_output is None:
            return False

        transfer_file = self.output_file.with_name(
            f".{self.output_file.name}.{uuid.uuid4().hex}.tmp"
        )
        try:
            shutil.copy2(self.staged_output, transfer_file)
            os.replace(transfer_file, self.output_file)
            return self.output_file.is_file() and self.output_file.stat().st_size > 0
        except OSError as error:
            self.append_log(f"Could not save the output: {error}")
            return False
        finally:
            try:
                transfer_file.unlink(missing_ok=True)
            except OSError:
                pass

    def cleanup_work_dir(self):
        if self.work_dir is not None:
            try:
                shutil.rmtree(self.work_dir)
            except OSError:
                pass
        self.work_dir = None
        self.staged_output = None

    def process_finished(self, exit_code, exit_status):
        self.read_process_output()

        self.running = False
        self.obfuscate_button.setText("Obfuscate")
        self.set_controls_enabled(True)
        self.progress_bar.setRange(0, 100)

        if self.cancel_requested:
            self.progress_bar.setValue(0)
            self.status_label.setText("Cancelled")
            self.append_log("Obfuscation cancelled.")
        elif exit_code == 0 and self.validate_staged_output() and self.publish_staged_output():
            self.progress_bar.setValue(100)
            self.status_label.setText("Done")
            self.append_log("Finished successfully.")
            self.open_folder_button.setEnabled(True)
        else:
            self.progress_bar.setValue(0)
            self.status_label.setText("Failed")
            self.append_log(f"Hercules exited with code {exit_code}.")

        self.cleanup_work_dir()
        self.process = None
        self.active_target = None

    def process_error(self, error):
        if error == QProcess.FailedToStart:
            self.append_log("Could not start Lua. Run installer.bat again.")
            self.running = False
            self.obfuscate_button.setText("Obfuscate")
            self.set_controls_enabled(True)
            self.progress_bar.setRange(0, 100)
            self.progress_bar.setValue(0)
            self.status_label.setText("Failed")
            self.cleanup_work_dir()
            self.process = None
            self.active_target = None
        elif self.running and error != QProcess.Crashed:
            self.append_log(f"Process error: {error}")

    def open_output_folder(self):
        folder = (
            self.output_file.parent
            if self.output_file is not None
            else self.output_folder
        )
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(folder)))

    def dragEnterEvent(self, event: QDragEnterEvent):
        urls = event.mimeData().urls()
        if len(urls) == 1 and urls[0].isLocalFile():
            path = Path(urls[0].toLocalFile())
            if path.suffix.lower() in {".lua", ".luau", ".txt"}:
                event.acceptProposedAction()
                return
        event.ignore()

    def dropEvent(self, event: QDropEvent):
        urls = event.mimeData().urls()
        if urls:
            self.set_source_file(Path(urls[0].toLocalFile()))
            event.acceptProposedAction()

    def closeEvent(self, event: QCloseEvent):
        if self.process and self.process.state() != QProcess.NotRunning:
            self.process.kill()
            self.process.waitForFinished(1000)
        self.cleanup_work_dir()
        event.accept()


if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setStyle("Fusion")

    window = LuaObfuscator()
    window.show()

    sys.exit(app.exec())

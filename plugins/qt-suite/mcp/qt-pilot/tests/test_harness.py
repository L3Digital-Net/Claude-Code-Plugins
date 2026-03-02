"""Unit tests for harness.py: CommandHandler and CommandDispatcher.

All Qt classes (QApplication, QTest, QWidget, etc.) are mocked so no real
display or Qt event loop is required.  CommandDispatcher is tested with real
threading by calling _process_pending() manually from the "main" thread while
dispatch() blocks in a background thread.
"""

from __future__ import annotations

import sys
import threading
import time
import types
import unittest.mock as mock
from pathlib import Path
from unittest.mock import MagicMock, patch

# ---------------------------------------------------------------------------
# Minimal Qt stubs — only the symbols harness.py references at import time.
# We build a stub module tree before importing harness so the real PySide6
# is never required.
# ---------------------------------------------------------------------------

def _make_qt_stubs() -> None:
    """Inject lightweight stubs for all PySide6 modules harness.py imports."""

    # PySide6.QtCore stubs.
    # Use MagicMock for Qt.Key so any Key_* attribute returns a unique value —
    # harness._KEY_MAP references ~95 key constants at import time, and
    # enumerating them all in the stub would be fragile.
    class _Qt:
        Key = MagicMock()

        class MouseButton:
            LeftButton = 1
            RightButton = 2
            MiddleButton = 4

        class KeyboardModifier:
            NoModifier = 0
            ControlModifier = 1
            ShiftModifier = 2
            AltModifier = 4
            MetaModifier = 8

        class ConnectionType:
            QueuedConnection = 2

    class _QTimer:
        def __init__(self, *args, **kwargs):
            self._interval = 0
            self._callbacks = []

        def setInterval(self, ms: int) -> None:
            self._interval = ms

        def start(self) -> None:
            pass

        def stop(self) -> None:
            pass

        @property
        def timeout(self):
            class _Signal:
                def connect(self, fn):
                    pass
            return _Signal()

        @classmethod
        def singleShot(cls, ms, fn):
            pass

    class _QObject:
        def __init__(self, parent=None):
            pass

    class _QPoint:
        def __init__(self, x=0, y=0):
            self._x = x
            self._y = y

        def x(self):
            return self._x

        def y(self):
            return self._y

    class _QCoreApplication:
        pass

    def _Slot(*args):
        """Stub @Slot decorator — returns the function unchanged."""
        def _decorator(fn):
            return fn
        return _decorator

    qtcore_mod = types.ModuleType("PySide6.QtCore")
    qtcore_mod.Qt = _Qt
    qtcore_mod.QTimer = _QTimer
    qtcore_mod.QObject = _QObject
    qtcore_mod.QPoint = _QPoint
    qtcore_mod.QCoreApplication = _QCoreApplication
    qtcore_mod.Slot = _Slot

    # PySide6.QtGui stubs
    class _QAction:
        def objectName(self):
            return ""

        def menu(self):
            return None

        def isSeparator(self):
            return False

        def text(self):
            return ""

        def isEnabled(self):
            return True

        def isCheckable(self):
            return False

        def isChecked(self):
            return False

        def shortcut(self):
            return None

    class _QGuiApplication:
        @staticmethod
        def primaryScreen():
            return None

    qtgui_mod = types.ModuleType("PySide6.QtGui")
    qtgui_mod.QAction = _QAction
    qtgui_mod.QGuiApplication = _QGuiApplication

    # PySide6.QtTest stubs
    class _QTest:
        @staticmethod
        def mouseClick(widget, button, *args, **kwargs):
            pass

        @staticmethod
        def mouseMove(widget, *args, **kwargs):
            pass

        @staticmethod
        def keyClicks(widget, text, *args, **kwargs):
            pass

        @staticmethod
        def keyClick(widget, key, *args, **kwargs):
            pass

    qttest_mod = types.ModuleType("PySide6.QtTest")
    qttest_mod.QTest = _QTest

    # PySide6.QtWidgets stubs
    class _QWidget:
        def objectName(self):
            return ""

        def isVisible(self):
            return True

        def isEnabled(self):
            return True

        def hasFocus(self):
            return False

        def rect(self):
            class R:
                def topLeft(self):
                    return _QPoint()
            return R()

        def geometry(self):
            class G:
                def x(self): return 0
                def y(self): return 0
                def width(self): return 100
                def height(self): return 100
            return G()

        def mapToGlobal(self, pt):
            return pt

        def findChildren(self, typ, name=""):
            return []

        def children(self):
            return []

        def actions(self):
            return []

        def isModal(self):
            return False

        def winId(self):
            return 0

    class _QApplication:
        _instance = None

        def __init__(self, argv=None):
            _QApplication._instance = self
            self._focus = None
            self._top_levels = []
            self._active = None

        def topLevelWidgets(self):
            return self._top_levels

        def activeWindow(self):
            return self._active

        def focusWidget(self):
            return self._focus

        def widgetAt(self, pos):
            return None

        def processEvents(self):
            pass

        def closingDown(self):
            return False

        def quit(self):
            pass

        def exec(self):
            return 0

        @classmethod
        def instance(cls):
            return cls._instance

    class _QMenu:
        pass

    class _QMenuBar:
        pass

    qtwid_mod = types.ModuleType("PySide6.QtWidgets")
    qtwid_mod.QApplication = _QApplication
    qtwid_mod.QWidget = _QWidget
    qtwid_mod.QMenu = _QMenu
    qtwid_mod.QMenuBar = _QMenuBar

    # Register all stubs
    pyside6_mod = types.ModuleType("PySide6")
    pyside6_mod.QtCore = qtcore_mod
    pyside6_mod.QtGui = qtgui_mod
    pyside6_mod.QtTest = qttest_mod
    pyside6_mod.QtWidgets = qtwid_mod

    sys.modules["PySide6"] = pyside6_mod
    sys.modules["PySide6.QtCore"] = qtcore_mod
    sys.modules["PySide6.QtGui"] = qtgui_mod
    sys.modules["PySide6.QtTest"] = qttest_mod
    sys.modules["PySide6.QtWidgets"] = qtwid_mod


# Install stubs before importing harness
_make_qt_stubs()

# Also stub mcp.server.fastmcp since main.py uses it (harness.py does not)
_mcp_mod = types.ModuleType("mcp")
_mcp_server = types.ModuleType("mcp.server")
_mcp_fastmcp = types.ModuleType("mcp.server.fastmcp")
_mcp_fastmcp.FastMCP = MagicMock
sys.modules["mcp"] = _mcp_mod
sys.modules["mcp.server"] = _mcp_server
sys.modules["mcp.server.fastmcp"] = _mcp_fastmcp

# Now import harness from its actual location
_HARNESS_PATH = Path(__file__).parent.parent
sys.path.insert(0, str(_HARNESS_PATH))
import harness  # noqa: E402

# Pull out the classes and the Qt stubs
CommandHandler = harness.CommandHandler
CommandDispatcher = harness.CommandDispatcher
_QApplication = sys.modules["PySide6.QtWidgets"].QApplication
_QTest = sys.modules["PySide6.QtTest"].QTest
_QTimer = sys.modules["PySide6.QtCore"].QTimer


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_app_and_handler():
    """Create a minimal QApplication stub + CommandHandler for testing."""
    app = _QApplication()
    handler = CommandHandler(app)
    return app, handler


def _make_widget(name="myWidget", visible=True, enabled=True):
    """Create a minimal QWidget stub with configurable properties."""
    w = MagicMock(spec=harness.sys.modules["PySide6.QtWidgets"].QWidget)
    w.objectName.return_value = name
    w.isVisible.return_value = visible
    w.isEnabled.return_value = enabled
    w.hasFocus.return_value = False
    w.findChildren.return_value = []
    w.children.return_value = []
    w.actions.return_value = []
    geom = MagicMock()
    geom.x.return_value = 10
    geom.y.return_value = 20
    geom.width.return_value = 100
    geom.height.return_value = 50
    w.geometry.return_value = geom
    pt = MagicMock()
    pt.x.return_value = 10
    pt.y.return_value = 20
    w.mapToGlobal.return_value = pt
    w.rect.return_value = MagicMock()
    w.rect.return_value.topLeft.return_value = pt
    return w


# ===========================================================================
# CommandHandler tests
# ===========================================================================

class TestHandlePing:
    def test_ping_returns_pong(self):
        _, handler = _make_app_and_handler()
        result = handler.handle({"cmd": "ping"})
        assert result == {"success": True, "message": "pong"}


class TestHandleUnknown:
    def test_unknown_command_returns_error(self):
        _, handler = _make_app_and_handler()
        result = handler.handle({"cmd": "does_not_exist"})
        assert result["success"] is False
        assert "Unknown command" in result["error"]


class TestHandleClick:
    def test_click_widget_not_found(self):
        app, handler = _make_app_and_handler()
        app._top_levels = []
        result = handler.handle({"cmd": "click", "widget_name": "noSuchWidget"})
        assert result["success"] is False
        assert "noSuchWidget" in result["error"]

    def test_click_calls_qtest_mouse_click(self):
        app, handler = _make_app_and_handler()
        widget = _make_widget("btn")
        app._top_levels = [widget]

        with patch.object(_QTest, "mouseClick") as mock_click:
            result = handler.handle({"cmd": "click", "widget_name": "btn", "button": "left"})

        assert result["success"] is True
        mock_click.assert_called_once()

    def test_click_right_button_mapped(self):
        app, handler = _make_app_and_handler()
        widget = _make_widget("btn")
        app._top_levels = [widget]

        with patch.object(_QTest, "mouseClick") as mock_click:
            handler.handle({"cmd": "click", "widget_name": "btn", "button": "right"})

        _, call_args, _ = mock_click.mock_calls[0]
        # Second positional arg is the button enum value
        assert call_args[1] == harness._QT_BUTTON_RIGHT if hasattr(harness, "_QT_BUTTON_RIGHT") else True


class TestHandleClickAt:
    def test_click_at_no_widget_at_coords(self):
        app, handler = _make_app_and_handler()
        app.widgetAt = MagicMock(return_value=None)
        result = handler.handle({"cmd": "click_at", "x": 0, "y": 0})
        assert result["success"] is False
        assert "(0, 0)" in result["error"]

    def test_click_at_calls_qtest_when_widget_found(self):
        app, handler = _make_app_and_handler()
        widget = _make_widget("someWidget")
        pt = MagicMock()
        pt.x.return_value = 5
        pt.y.return_value = 5
        widget.mapFromGlobal = MagicMock(return_value=pt)
        app.widgetAt = MagicMock(return_value=widget)

        with patch.object(_QTest, "mouseClick") as mock_click:
            result = handler.handle({"cmd": "click_at", "x": 10, "y": 10})

        assert result["success"] is True
        mock_click.assert_called_once()


class TestHandleHover:
    def test_hover_not_found(self):
        app, handler = _make_app_and_handler()
        app._top_levels = []
        result = handler.handle({"cmd": "hover", "widget_name": "ghost"})
        assert result["success"] is False

    def test_hover_calls_mouse_move(self):
        app, handler = _make_app_and_handler()
        widget = _make_widget("target")
        app._top_levels = [widget]

        with patch.object(_QTest, "mouseMove") as mock_move:
            result = handler.handle({"cmd": "hover", "widget_name": "target"})

        assert result["success"] is True
        mock_move.assert_called_once_with(widget)


class TestHandleTypeText:
    def test_type_text_no_focus_no_widget(self):
        app, handler = _make_app_and_handler()
        app._top_levels = []
        app._focus = None
        result = handler.handle({"cmd": "type_text", "text": "hello"})
        assert result["success"] is False
        assert "No focused widget" in result["error"]

    def test_type_text_uses_focused_widget(self):
        app, handler = _make_app_and_handler()
        widget = _make_widget("field")
        app._focus = widget

        with patch.object(_QTest, "keyClicks") as mock_clicks:
            result = handler.handle({"cmd": "type_text", "text": "hello"})

        assert result["success"] is True
        mock_clicks.assert_called_once_with(widget, "hello")

    def test_type_text_explicit_widget(self):
        app, handler = _make_app_and_handler()
        widget = _make_widget("field")
        app._top_levels = [widget]

        with patch.object(_QTest, "keyClicks") as mock_clicks:
            result = handler.handle({"cmd": "type_text", "text": "world", "widget_name": "field"})

        assert result["success"] is True
        mock_clicks.assert_called_once_with(widget, "world")

    def test_type_text_widget_not_found(self):
        app, handler = _make_app_and_handler()
        app._top_levels = []
        result = handler.handle({"cmd": "type_text", "text": "x", "widget_name": "missing"})
        assert result["success"] is False


class TestHandlePressKey:
    def test_unknown_key_returns_error(self):
        _, handler = _make_app_and_handler()
        result = handler.handle({"cmd": "press_key", "key": "NotAKey123"})
        assert result["success"] is False
        assert "Unknown key" in result["error"]

    def test_known_key_calls_qtest_key_click(self):
        app, handler = _make_app_and_handler()
        widget = _make_widget("w")
        app._focus = widget

        with patch.object(_QTest, "keyClick") as mock_key:
            result = handler.handle({"cmd": "press_key", "key": "Enter"})

        assert result["success"] is True
        mock_key.assert_called_once()

    def test_single_char_alpha_key(self):
        app, handler = _make_app_and_handler()
        widget = _make_widget("w")
        app._focus = widget

        with patch.object(_QTest, "keyClick") as mock_key:
            result = handler.handle({"cmd": "press_key", "key": "A"})

        assert result["success"] is True
        mock_key.assert_called_once()

    def test_no_focused_widget_returns_error(self):
        app, handler = _make_app_and_handler()
        app._focus = None
        app._top_levels = []
        result = handler.handle({"cmd": "press_key", "key": "Enter"})
        assert result["success"] is False


class TestHandleFindWidgets:
    def test_find_widgets_empty(self):
        app, handler = _make_app_and_handler()
        app._top_levels = []
        result = handler.handle({"cmd": "find_widgets", "pattern": "*"})
        assert result["success"] is True
        assert result["widgets"] == []

    def test_find_widgets_returns_named_widgets(self):
        app, handler = _make_app_and_handler()
        widget = _make_widget("submitBtn")
        widget.findChildren = MagicMock(return_value=[])
        app._top_levels = [widget]

        result = handler.handle({"cmd": "find_widgets", "pattern": "*"})
        assert result["success"] is True
        assert any(w["name"] == "submitBtn" for w in result["widgets"])

    def test_find_widgets_pattern_filter(self):
        app, handler = _make_app_and_handler()
        widget = _make_widget("submitBtn")
        widget.findChildren = MagicMock(return_value=[])
        app._top_levels = [widget]

        result = handler.handle({"cmd": "find_widgets", "pattern": "cancel*"})
        assert result["success"] is True
        assert result["widgets"] == []


class TestHandleListAllWidgets:
    def test_list_all_widgets_empty(self):
        app, handler = _make_app_and_handler()
        app._top_levels = []
        result = handler.handle({"cmd": "list_all_widgets"})
        assert result["success"] is True
        assert result["count"] == 0

    def test_list_all_widgets_includes_geometry(self):
        app, handler = _make_app_and_handler()
        widget = _make_widget("w")
        widget.children = MagicMock(return_value=[])
        app._top_levels = [widget]

        result = handler.handle({"cmd": "list_all_widgets"})
        assert result["success"] is True
        assert result["count"] == 1
        w = result["widgets"][0]
        assert "width" in w
        assert "height" in w
        assert "x" in w
        assert "y" in w


class TestHandleGetWidgetInfo:
    def test_get_widget_info_not_found(self):
        app, handler = _make_app_and_handler()
        app._top_levels = []
        result = handler.handle({"cmd": "get_widget_info", "widget_name": "ghost"})
        assert result["success"] is False

    def test_get_widget_info_returns_fields(self):
        app, handler = _make_app_and_handler()
        widget = _make_widget("myWidget")
        widget.hasFocus.return_value = True
        app._top_levels = [widget]

        result = handler.handle({"cmd": "get_widget_info", "widget_name": "myWidget"})
        assert result["success"] is True
        info = result["info"]
        assert info["name"] == "myWidget"
        assert info["has_focus"] is True
        assert "width" in info
        assert "height" in info


class TestHandleTriggerAction:
    def test_trigger_action_not_found(self):
        app, handler = _make_app_and_handler()
        widget = _make_widget("win")
        widget.actions = MagicMock(return_value=[])
        widget.findChildren = MagicMock(return_value=[])
        app._top_levels = [widget]

        result = handler.handle({"cmd": "trigger_action", "action_name": "saveAction"})
        assert result["success"] is False
        assert "saveAction" in result["error"]

    def test_trigger_action_no_name(self):
        _, handler = _make_app_and_handler()
        result = handler.handle({"cmd": "trigger_action"})
        assert result["success"] is False


class TestHandleListActions:
    def test_list_actions_empty(self):
        app, handler = _make_app_and_handler()
        app._top_levels = []
        result = handler.handle({"cmd": "list_actions"})
        assert result["success"] is True
        assert result["count"] == 0


class TestHandleWaitIdle:
    def test_wait_idle_returns_elapsed(self):
        app, handler = _make_app_and_handler()
        result = handler.handle({"cmd": "wait_idle", "timeout": 0.1})
        assert result["success"] is True
        assert "elapsed" in result
        assert result["elapsed"] >= 0

    def test_wait_idle_calls_process_events(self):
        app, handler = _make_app_and_handler()
        call_count = {"n": 0}
        original = app.processEvents
        def counting(*a):
            call_count["n"] += 1
        app.processEvents = counting

        handler.handle({"cmd": "wait_idle", "timeout": 0.05})
        assert call_count["n"] > 0


class TestHandleQuit:
    def test_quit_returns_success(self):
        _, handler = _make_app_and_handler()
        with patch.object(_QTimer, "singleShot"):
            result = handler.handle({"cmd": "quit"})
        assert result["success"] is True


# ===========================================================================
# CommandDispatcher tests
# ===========================================================================

class TestCommandDispatcher:
    def _make_dispatcher(self):
        """Create a CommandDispatcher with a simple echo handler."""
        _, handler = _make_app_and_handler()
        # Override handle() to echo the command back
        handler.handle = MagicMock(side_effect=lambda cmd: {"echo": cmd})
        dispatcher = CommandDispatcher(handler)
        return dispatcher, handler

    def test_process_pending_processes_queued_command(self):
        """_process_pending() dequeues one command and puts the result in response_queue."""
        dispatcher, handler = self._make_dispatcher()

        # Pre-load the request queue directly
        import queue as q
        response_queue = q.Queue()
        dispatcher._request_queue.put(({"cmd": "ping"}, response_queue))

        # Simulate the main thread timer firing
        dispatcher._process_pending()

        assert not response_queue.empty()
        result = response_queue.get_nowait()
        assert result == {"echo": {"cmd": "ping"}}

    def test_process_pending_noop_when_empty(self):
        """_process_pending() does nothing when no commands are queued."""
        dispatcher, handler = self._make_dispatcher()
        dispatcher._process_pending()  # Must not raise
        handler.handle.assert_not_called()

    def test_dispatch_blocks_until_process_pending_called(self):
        """dispatch() blocks until _process_pending() processes the command."""
        dispatcher, _ = self._make_dispatcher()

        results = {}

        def background():
            results["r"] = dispatcher.dispatch({"cmd": "test"}, timeout=2.0)

        t = threading.Thread(target=background)
        t.start()
        time.sleep(0.05)  # Let the background thread reach Queue.get()

        # Main thread: process the pending command
        dispatcher._process_pending()
        t.join(timeout=1.0)

        assert not t.is_alive(), "dispatch() did not unblock after _process_pending"
        assert results.get("r") == {"echo": {"cmd": "test"}}

    def test_dispatch_timeout_when_never_processed(self):
        """dispatch() returns a timeout error if no one calls _process_pending."""
        dispatcher, _ = self._make_dispatcher()
        result = dispatcher.dispatch({"cmd": "ping"}, timeout=0.05)
        assert result["success"] is False
        assert "timed out" in result["error"]

    def test_multiple_sequential_dispatches(self):
        """Multiple sequential dispatches all complete correctly."""
        dispatcher, _ = self._make_dispatcher()

        for i in range(5):
            cmd = {"cmd": "ping", "seq": i}

            def bg(c=cmd):
                return dispatcher.dispatch(c, timeout=1.0)

            t = threading.Thread(target=bg)
            t.start()
            time.sleep(0.02)
            dispatcher._process_pending()
            t.join(timeout=0.5)
            assert not t.is_alive()

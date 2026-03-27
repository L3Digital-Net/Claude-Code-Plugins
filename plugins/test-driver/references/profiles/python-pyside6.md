  conventions, execution commands, coverage tools, and UI testing via pytest-qt and Qt Pilot.
---

# Stack Profile: Python / PySide6

## 1. Applicable Test Categories

- **Unit** — always applicable
- **Integration** — always applicable
- **E2E** — applicable (full application flow tests)
- **UI** — applicable (widget interaction via pytest-qt and Qt Pilot)
- **Contract** — not applicable
- **Security** — not applicable

## 2. Test Discovery

- **Location:** `tests/` directory at project root
- **Naming:** files matching `test_*.py`
- **Categorization:**

| Category | Directory | Marker |
|----------|-----------|--------|
| Unit | `tests/unit/` | `@pytest.mark.unit` |
| Integration | `tests/integration/` | `@pytest.mark.integration` |
| E2E | `tests/e2e/` | `@pytest.mark.e2e` |
| UI | `tests/ui/` | `@pytest.mark.ui` |

## 3. Test Execution

```bash
# All tests (offscreen prevents display requirement)
QT_QPA_PLATFORM=offscreen pytest tests/

# Unit and integration only (no display needed)
pytest -m "not ui" tests/

# UI tests only (needs offscreen or Xvfb)
QT_QPA_PLATFORM=offscreen pytest -m ui tests/

# Single file
pytest tests/test_main_window.py -v
```

**Headless CI setup** using Xvfb:
```bash
Xvfb :99 -screen 0 1280x1024x24 &
export DISPLAY=:99
pytest tests/
```

## 4. Coverage Measurement

- **Tool:** coverage.py via pytest-cov
- **Command:** `QT_QPA_PLATFORM=offscreen pytest --cov=src --cov-report=term-missing`
- **Note:** UI tests need `QT_QPA_PLATFORM=offscreen` for headless coverage

## 5. UI Testing

Two complementary tools:

### pytest-qt (widget unit tests)

The `qtbot` fixture provides programmatic widget interaction. Key methods from the official API:

**Widget lifecycle:**
- `qtbot.addWidget(widget)` — **required** for every widget created in tests; ensures cleanup
- `qtbot.waitActive(widget)` — wait until widget is active
- `qtbot.waitExposed(widget)` — wait until widget is visible

**Signal testing:**
- `qtbot.waitSignal(signal, timeout=1000)` — block until signal emits
- `qtbot.waitSignals([sig1, sig2], timeout=1000)` — wait for multiple signals
- `qtbot.assertNotEmitted(signal)` — verify signal was not emitted

**Input simulation:**
- `qtbot.mouseClick(widget, Qt.LeftButton)` — simulate mouse click
- `qtbot.keyClick(widget, 'A')` — simulate key press
- `qtbot.keyClicks(widget, 'Hello')` — type a string

```python
def test_button_click_emits_signal(qtbot):
    widget = MyWidget()
    qtbot.addWidget(widget)

    with qtbot.waitSignal(widget.submitted, timeout=1000):
        qtbot.mouseClick(widget.submit_button, Qt.LeftButton)
```

```python
def test_text_input(qtbot):
    widget = SearchBar()
    qtbot.addWidget(widget)

    qtbot.keyClicks(widget.search_field, "hello world")
    assert widget.search_field.text() == "hello world"
```

### Qt Pilot (headless GUI testing)

For full application-level visual testing, use the Qt Pilot MCP server (provided by the `qt-suite` plugin). Qt Pilot launches the app headlessly and interacts via widget object names.

Setup: requires Xvfb and the `qt-suite` plugin installed.

## Key Testing Patterns

- Always use `qtbot.addWidget()` for widget cleanup
- Use `QT_QPA_PLATFORM=offscreen` for headless rendering
- Use `qtbot.waitSignal()` for async signal verification, not sleep
- Test widget state changes (enabled/disabled, text content, visibility) after interactions
- Use `qtbot.waitUntil(lambda: condition(), timeout=1000)` for polling conditions

## Delegates To

- `qt-suite:qtest-patterns` for comprehensive Qt test patterns and QML testing
- `qt-suite:qt-pilot-usage` for headless GUI testing via Qt Pilot MCP
- If not installed, proceed using general pytest-qt knowledge

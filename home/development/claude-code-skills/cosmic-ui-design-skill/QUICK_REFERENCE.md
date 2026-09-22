# COSMIC Development Quick Reference

## Essential Commands

### Project Setup

```bash
# Create new application
cargo generate gh:pop-os/cosmic-app-template

# Create new applet
cargo generate gh:pop-os/cosmic-applet-template

# Install dependencies (Ubuntu/Pop!_OS)
sudo apt install cargo cmake just libexpat1-dev libfontconfig-dev \
    libfreetype-dev libxkbcommon-dev pkgconf

# Install Rust (if needed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Build & Development

```bash
just check          # Run linter (do before commit!)
just build          # Build the project
just run            # Run the application
just check-json     # JSON output for editor integration
cargo fmt           # Format code
cargo clippy        # Run clippy
```

## Application Template

```rust
use cosmic::prelude::*;
use cosmic::{Application, Element, Core};

struct MyApp {
    core: Core,
    // Your state here
}

#[derive(Debug, Clone)]
pub enum Message {
    // Your messages
}

impl Application for MyApp {
    type Executor = cosmic::executor::Default;
    type Flags = ();
    type Message = Message;
    const APP_ID: &'static str = "com.example.myapp";

    fn core(&self) -> &Core { &self.core }
    fn core_mut(&mut self) -> &mut Core { &mut self.core }

    fn init(core: Core, _flags: Self::Flags) -> (Self, cosmic::app::Task<Self::Message>) {
        let app = Self { core };
        let cmd = app.set_window_title("My App");
        (app, cmd)
    }

    fn view(&self) -> Element<Self::Message> {
        widget::text("Hello COSMIC!").into()
    }

    fn update(&mut self, message: Self::Message) -> cosmic::app::Task<Self::Message> {
        cosmic::app::Task::none()
    }
}

fn main() -> cosmic::iced::Result {
    cosmic::app::run::<MyApp>(cosmic::app::Settings::default(), ())
}
```

## Applet Template

```rust
use cosmic::prelude::*;
use cosmic::{Application, Element, Core};
use cosmic::iced::window;

struct MyApplet {
    core: Core,
    popup: Option<window::Id>,
}

impl Application for MyApplet {
    // Same boilerplate as app...
    const APP_ID: &'static str = "com.example.myapplet";

    fn view(&self) -> Element<Message> {
        self.core.applet
            .icon_button("icon-name-symbolic")
            .on_press_down(Message::TogglePopup)
            .into()
    }

    fn style(&self) -> Option<cosmic::iced_runtime::Appearance> {
        Some(cosmic::applet::style())
    }
}

fn main() -> cosmic::iced::Result {
    cosmic::applet::run::<MyApplet>(cosmic::app::Settings::default(), ())
}
```

## Cargo.toml Configuration

### Application

```toml
[dependencies]
libcosmic = "0.1"
tokio = { version = "1", features = ["full"] }
tracing = "0.1"
```

### Applet

```toml
[dependencies]
libcosmic = { version = "0.1", features = ["applet"] }
# For lower memory: remove wgpu
# libcosmic = { version = "0.1", features = ["applet"], default-features = false }
```

## Common Widgets

```rust
use cosmic::widget;

// Buttons
widget::button("Click me").on_press(Message::Clicked)
widget::button::link("https://example.com").on_press(Message::OpenLink)

// Text hierarchy
widget::text::title1("Main Title")
widget::text::title2("Section Title")
widget::text::title3("Subsection")
widget::text::body("Body text")
widget::text::caption("Caption")

// Icons (use symbolic variants)
widget::icon::from_name("folder-symbolic")
widget::icon::from_name("media-playback-start-symbolic")

// Layouts
widget::column()
    .spacing(theme::spacing().space_s)
    .push(widget1)
    .push(widget2)

widget::row()
    .spacing(theme::spacing().space_m)
    .push(widget1)
    .push(widget2)

// Containers
widget::container(content)
    .width(Length::Fill)
    .center_x()
    .padding(theme::spacing().space_m)
```

## Theming

```rust
use cosmic::{theme, cosmic_theme};

// Get spacing
let spacing = theme::spacing();
spacing.space_xxs  // Extra extra small
spacing.space_xs   // Extra small
spacing.space_s    // Small
spacing.space_m    // Medium
spacing.space_l    // Large
spacing.space_xl   // Extra large

// Get theme colors
let theme = theme::active();
let bg = theme.cosmic().background.base;
let accent = theme.cosmic().accent_color();

// Custom style with theme
.style(|theme| container::Style {
    background: Some(theme.cosmic().accent_color().into()),
    border: iced::Border {
        radius: theme.cosmic().corner_radii.radius_m.into(),
        ..Default::default()
    },
    ..Default::default()
})
```

## Error Handling

### ❌ Don't Use

```rust
value.unwrap()              // Panics on None/Err
value.expect("message")     // Panics on None/Err
```

### ✅ Use Instead

```rust
use tracing::{error, warn, info};

// Pattern matching
match result {
    Ok(value) => { /* use value */ }
    Err(e) => error!("Failed: {}", e),
}

// if let
if let Some(value) = option {
    // use value
}

// Question mark operator
fn load() -> Result<Data, Error> {
    let file = std::fs::read_to_string("data.txt")?;
    let data = parse(&file)?;
    Ok(data)
}

// Unwrap with default
let value = option.unwrap_or_default();
let value = option.unwrap_or(fallback);
```

## Async Patterns

### Tasks (for one-time operations)

```rust
fn update(&mut self, message: Message) -> cosmic::app::Task<Message> {
    match message {
        Message::Load => {
            cosmic::app::Task::perform(
                async { load_data().await },
                Message::Loaded
            )
        }
        Message::Loaded(data) => {
            self.data = data;
            cosmic::app::Task::none()
        }
    }
}
```

### Subscriptions (for streams)

```rust
use cosmic::iced::Subscription;
use cosmic::iced::time;

impl Application for MyApp {
    fn subscription(&self) -> Subscription<Message> {
        time::every(std::time::Duration::from_secs(1))
            .map(|_| Message::Tick)
    }
}
```

## Configuration System

```rust
use cosmic_config::{Config, ConfigGet, ConfigSet};

// Initialize
let config = Config::new("com.example.myapp", 1)?;

// Read
let width: u32 = config.get("window_width").unwrap_or(800);

// Write
config.set("window_width", 1024)?;
```

## Applet Desktop Entry

```ini
[Desktop Entry]
Name=My Applet
Type=Application
Exec=cosmic-applet-myapp
Terminal=false
Categories=COSMIC;
NoDisplay=true              # Required
X-CosmicApplet=true        # Required
X-CosmicHoverPopup=Auto    # Optional
X-OverflowPriority=10      # Optional
Icon=my-applet-icon
```

## Popup Management (Applets)

```rust
use cosmic::iced_runtime::platform_specific;
use cosmic::iced::window;

// Create popup
fn create_popup(&mut self) -> cosmic::app::Task<Message> {
    let new_id = window::Id::unique();
    self.popup = Some(new_id);

    let settings = self.core.applet.get_popup_settings(
        self.core.main_window_id().unwrap(),
        new_id,
        Some((500, 300)), // width, height
    );

    platform_specific::shell::commands::popup::get_popup(settings)
}

// Destroy popup
fn destroy_popup(&mut self, id: window::Id) -> cosmic::app::Task<Message> {
    self.popup = None;
    platform_specific::shell::commands::popup::destroy_popup(id)
}

// Toggle popup
fn toggle_popup(&mut self) -> cosmic::app::Task<Message> {
    if let Some(id) = self.popup.take() {
        self.destroy_popup(id)
    } else {
        self.create_popup()
    }
}
```

## Common Icons

```rust
// System
"system-shutdown-symbolic"
"system-restart-symbolic"
"system-log-out-symbolic"

// Media
"media-playback-start-symbolic"
"media-playback-pause-symbolic"
"media-playback-stop-symbolic"

// Navigation
"go-previous-symbolic"
"go-next-symbolic"
"go-up-symbolic"
"go-down-symbolic"

// Actions
"document-open-symbolic"
"document-save-symbolic"
"edit-delete-symbolic"
"list-add-symbolic"

// Status
"dialog-error-symbolic"
"dialog-warning-symbolic"
"dialog-information-symbolic"

// Hardware
"audio-volume-high-symbolic"
"network-wired-symbolic"
"battery-symbolic"
```

## Code Review Checklist

### Quick Pre-Commit

- [ ] Runs `just check` without errors
- [ ] No `.unwrap()` or `.expect()` calls
- [ ] No hard-coded colors, dimensions, or radii
- [ ] Proper error logging with tracing
- [ ] No blocking operations in `update()`

### Full Review

- [ ] Application trait properly implemented
- [ ] State management follows patterns
- [ ] Widgets borrow from state (no unnecessary clones)
- [ ] Theme integration complete
- [ ] Works in light and dark mode
- [ ] Async operations use Tasks/Subscriptions
- [ ] Error handling is graceful
- [ ] Public items have doc comments
- [ ] Desktop entry configured (for applets)

## Common Mistakes

### ❌ Hard-coded values

```rust
.padding(10)
.style(|_| Style {
    background: Some(Color::from_rgb(0.2, 0.4, 0.8).into()),
    ..Default::default()
})
```

### ✅ Use theme

```rust
.padding(theme::spacing().space_m)
.style(button::Style::Primary)
```

### ❌ Blocking in update

```rust
fn update(&mut self, msg: Message) -> Task<Message> {
    self.data = std::fs::read_to_string("file.txt").unwrap();
    Task::none()
}
```

### ✅ Use async Task

```rust
fn update(&mut self, msg: Message) -> Task<Message> {
    match msg {
        Message::Load => Task::perform(
            async { tokio::fs::read_to_string("file.txt").await },
            |result| Message::Loaded(result)
        ),
        Message::Loaded(result) => {
            self.data = result.unwrap_or_default();
            Task::none()
        }
    }
}
```

## Resources

- **libcosmic Book**: <https://pop-os.github.io/libcosmic-book/>
- **API Docs**: <https://pop-os.github.io/libcosmic/cosmic/>
- **Templates**: <https://github.com/pop-os/cosmic-app-template>
- **Examples**: <https://github.com/pop-os/libcosmic/tree/master/examples>

---

Print this reference or keep it open while developing!

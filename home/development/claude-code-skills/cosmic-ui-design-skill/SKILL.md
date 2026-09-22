# COSMIC Desktop UI Design & Development Excellence

**Version:** 1.0.0
**Last Updated:** January 2026
**Official Documentation:** <https://pop-os.github.io/libcosmic-book/>

## Overview

This skill provides comprehensive guidance for developing COSMIC Desktop applications and applets
using libcosmic and Rust. It embeds best practices derived from System76's official COSMIC Desktop
project, ensuring code quality, performance, and adherence to COSMIC's design language.

## When to Use This Skill

Use this skill when:

- Developing COSMIC Desktop applications or applets
- Reviewing COSMIC-related Rust code
- Creating or modifying libcosmic widgets
- Implementing Wayland Layer Shell protocols
- Working with COSMIC's theming system
- Building panel applets or dock widgets
- Integrating with COSMIC's configuration system

## Core Principles

### 1. **COSMIC Design Language**

COSMIC's design system is built on themeable foundations:

- **Nothing is hard-coded**: All colors, spacing, icon sizing, and corner radii use variables
- **Automatic color derivation**: Selected colors automatically derive contrasting colors for surfaces and text
- **OKLCH color space**: Colors are converted from sRGB to OKLCH for lightness manipulation while
  preserving hue and chroma
- **Theme consistency**: Themes apply uniformly across apps, applets, panels, docks, and compatible GTK applications

### 2. **Architecture Philosophy**

- **Rust-first**: Memory-safe, secure, and efficient by design
- **iced-based**: Built on the cross-platform iced GUI library
- **Wayland-native**: Native Wayland compositor with Xwayland support
- **Stateless widgets**: Widgets don't contain application state; they rely on the application model
- **Functional composition**: Widgets use Builder pattern for configuration

### 3. **Development Standards**

- **Use official templates**: Always start with `cargo generate gh:pop-os/cosmic-app-template` for
  apps or `gh:pop-os/cosmic-applet-template` for applets
- **Avoid unwrap/expect**: Use `tracing::error!()` or `tracing::warn!()` for error handling
- **Follow just workflows**: Use `just check` before committing code
- **Respect cross-platform goals**: libcosmic targets Linux (X11/Wayland), Redox OS, Windows, Mac, and Android

---

## Application Development Best Practices

### Project Structure

#### Required Application Structure

```rust
use cosmic::prelude::*;
use cosmic::{Application, Element, Core};

// 1. Application Model (single source of truth)
struct MyApp {
    core: Core,  // REQUIRED: COSMIC runtime state
    // Your application state here
}

// 2. Message Enum (all possible events)
#[derive(Debug, Clone)]
pub enum Message {
    // Define your messages
}

// 3. Application Trait Implementation
impl Application for MyApp {
    type Executor = cosmic::executor::Default;
    type Flags = ();
    type Message = Message;

    const APP_ID: &'static str = "com.example.myapp"; // Reverse domain notation

    fn core(&self) -> &Core {
        &self.core
    }

    fn core_mut(&mut self) -> &mut Core {
        &mut self.core
    }

    fn init(core: Core, _flags: Self::Flags) -> (Self, cosmic::app::Task<Self::Message>) {
        let app = Self {
            core,
            // Initialize state
        };

        let command = app.set_window_title("My App Name");
        (app, command)
    }

    fn view(&self) -> Element<Self::Message> {
        // Build UI here
        todo!()
    }

    fn update(&mut self, message: Self::Message) -> cosmic::app::Task<Self::Message> {
        // Handle messages here
        cosmic::app::Task::none()
    }
}

fn main() -> cosmic::iced::Result {
    let settings = cosmic::app::Settings::default();
    cosmic::app::run::<MyApp>(settings, ())
}
```

#### Critical Rules

- ✅ **DO**: Store `cosmic::Core` in your application struct
- ✅ **DO**: Use stateless widgets that reference application state
- ✅ **DO**: Return `Task`s for async operations from `update()`
- ✅ **DO**: Keep `update()` logic swift to prevent UI freezing
- ❌ **DON'T**: Perform long-running operations in `update()` - use Tasks or Subscriptions
- ❌ **DON'T**: Store state in widgets themselves

---

## Applet Development Best Practices

### Applet vs Application Differences

**Applets are specialized applications for panels/docks:**

- Use `applet::run()` instead of `app::run()`
- Read panel configuration from environment variables
- Use transparent, undecorated windows
- Integrate with Wayland popup surfaces
- Support theme overrides to match panel appearance

### Required Cargo.toml Configuration

```toml
[dependencies]
libcosmic = { version = "...", features = ["applet"] }
# Optionally remove wgpu for lower memory usage with software renderer
# libcosmic = { version = "...", features = ["applet"], default-features = false }
```

### Applet Structure Template

```rust
use cosmic::prelude::*;
use cosmic::{Application, Element, Core};
use cosmic::iced::window;
use cosmic::iced_runtime::platform_specific;

struct MyApplet {
    core: Core,
    popup: Option<window::Id>,
    icon_name: &'static str,
}

#[derive(Debug, Clone)]
enum Message {
    TogglePopup,
    // Other messages
}

impl Application for MyApplet {
    type Executor = cosmic::executor::Default;
    type Flags = ();
    type Message = Message;

    const APP_ID: &'static str = "com.example.myapplet";

    fn core(&self) -> &Core {
        &self.core
    }

    fn core_mut(&mut self) -> &mut Core {
        &mut self.core
    }

    // Main applet button shown in panel
    fn view(&self) -> Element<Message> {
        self.core
            .applet
            .icon_button(self.icon_name)
            .on_press_down(Message::TogglePopup)
            .into()
    }

    // Popup window content (optional)
    fn view_window(&self, id: window::Id) -> Element<Message> {
        if Some(id) == self.popup {
            // Return popup content
            cosmic::widget::text("Popup Content").into()
        } else {
            cosmic::widget::text("Unknown window").into()
        }
    }

    fn update(&mut self, message: Message) -> cosmic::app::Task<Message> {
        match message {
            Message::TogglePopup => {
                if let Some(p) = self.popup.take() {
                    return platform_specific::shell::commands::popup::destroy_popup(p);
                } else {
                    let new_id = window::Id::unique();
                    self.popup = Some(new_id);

                    let popup_settings = self.core.applet.get_popup_settings(
                        self.core.main_window_id().unwrap(),
                        new_id,
                        Some((500, 300)), // width, height
                    );

                    return platform_specific::shell::commands::popup::get_popup(popup_settings);
                }
            }
        }
    }

    // Required for transparent panel background
    fn style(&self) -> Option<cosmic::iced_runtime::Appearance> {
        Some(cosmic::applet::style())
    }
}

fn main() -> cosmic::iced::Result {
    let settings = cosmic::app::Settings::default();
    cosmic::applet::run::<MyApplet>(settings, ())
}
```

### Applet Desktop Entry Requirements

Create a `.desktop` file with these required keys:

```ini
[Desktop Entry]
Name=My Applet
Type=Application
Exec=cosmic-applet-myapp
Terminal=false
Categories=COSMIC;
NoDisplay=true              # Required: Hide from app launchers
X-CosmicApplet=true        # Required: Mark as COSMIC applet
X-CosmicHoverPopup=Auto    # Optional: Auto-open popup on hover
X-OverflowPriority=10      # Optional: Priority in panel overflow
Icon=my-applet-icon
```

---

## Widget Usage Best Practices

### Widget Import Pattern

```rust
use cosmic::prelude::*;
use cosmic::{theme, widget};
use cosmic::cosmic_theme::Spacing;
```

### Common Widget Patterns

#### 1. **Spacing and Layout**

```rust
// Get theme spacing
let cosmic_theme::Spacing {
    space_xxs,
    space_xs,
    space_s,
    space_m,
    ..
} = theme::spacing();

// Use in layouts
let content = widget::column()
    .spacing(space_s)
    .padding(space_m)
    .push(widget::text("Hello"));
```

#### 2. **Buttons**

```rust
// Standard button
let button = widget::button("Click me")
    .on_press(Message::Clicked)
    .padding(space_s);

// Icon button
let icon_btn = widget::icon::from_name("printer-symbolic")
    .apply(widget::button::icon)
    .on_press(Message::Print);

// Link button
let link = widget::button::link("https://example.com")
    .on_press(Message::OpenLink)
    .padding(0);
```

#### 3. **Text Widgets**

```rust
// Hierarchical text
widget::text::title1("Main Title")
widget::text::title2("Section Title")
widget::text::title3("Subsection")
widget::text::body("Body text")
widget::text::caption("Caption text")
```

#### 4. **Containers and Alignment**

```rust
let content = widget::container(button)
    .width(iced::Length::Fill)
    .height(iced::Length::Shrink)
    .center_x()
    .center_y()
    .padding(space_m);
```

#### 5. **Icons**

```rust
// Use symbolic icons from icon theme
let icon = widget::icon::from_name("folder-symbolic");
let icon = widget::icon::from_name("media-playback-start-symbolic");

// Icons automatically respect theme colors
```

### Apply Trait for Composition

The `cosmic::Apply` trait enables clean widget embedding:

```rust
use cosmic::Apply;

// Instead of verbose nesting
let button = widget::button::icon(
    widget::icon::from_name("printer-symbolic")
).on_press(Message::Print);

// Use Apply trait
let button = widget::icon::from_name("printer-symbolic")
    .apply(widget::button::icon)
    .on_press(Message::Print);
```

---

## Theming and Styling

### Theme Integration

#### Accessing Theme Values

```rust
use cosmic::{theme, cosmic_theme};

// Get current theme
let theme = theme::active();

// Get spacing
let spacing = theme::spacing();

// Get specific color
let bg_color = theme.cosmic().background.base;
let accent = theme.cosmic().accent_color();
```

### Custom Styling Patterns

#### 1. **Custom Style Closures**

```rust
use cosmic::widget::container;

let custom_container = container(content)
    .style(|theme| container::Style {
        background: Some(theme.cosmic().accent_color().into()),
        border: iced::Border {
            radius: theme.cosmic().corner_radii.radius_m.into(),
            width: 2.0,
            color: theme.cosmic().accent.base.into(),
        },
        ..Default::default()
    });
```

#### 2. **Layer-Aware Styling**

```rust
// Card style that adapts to current layer
let card = widget::container(content)
    .style(container::Style::Card);

// This automatically adjusts appearance based on:
// - Whether it's on a primary, secondary, or tertiary layer
// - Current theme (light/dark)
// - User's custom theme settings
```

#### 3. **Reusable Custom Styles**

```rust
pub enum MyButtonStyle {
    Primary,
    Danger,
    Custom(Box<dyn Fn(&cosmic::Theme) -> button::Style>),
}

impl button::Catalog for MyButtonStyle {
    fn style(&self, theme: &cosmic::Theme) -> button::Style {
        match self {
            Self::Primary => {
                // Return primary style
            }
            Self::Danger => {
                // Return danger style
            }
            Self::Custom(f) => f(theme),
        }
    }
}
```

### Theme Best Practices

- ✅ **DO**: Use theme variables for all colors, spacing, and radii
- ✅ **DO**: Test with both light and dark modes
- ✅ **DO**: Test with different accent colors
- ✅ **DO**: Respect user's corner radius preferences (sharp, slightly round, round)
- ✅ **DO**: Use `cosmic::theme::spacing()` for consistent spacing
- ❌ **DON'T**: Hard-code colors or dimensions
- ❌ **DON'T**: Assume light mode or dark mode
- ❌ **DON'T**: Use fixed pixel values - use theme spacing

---

## Error Handling and Logging

### Logging Best Practices

```rust
use tracing::{debug, info, warn, error};

// Use appropriate log levels
info!("Application started");
debug!("Processing message: {:?}", msg);
warn!("Unexpected state: {:?}", state);
error!("Failed to load configuration: {}", err);
```

### Error Handling Patterns

#### ❌ **AVOID: unwrap() and expect()**

```rust
// BAD - Will panic
let value = some_option.unwrap();
let result = some_result.expect("Failed");
```

#### ✅ **PREFERRED: Pattern Matching**

```rust
// GOOD - Graceful error handling
match some_result {
    Ok(value) => {
        info!("Successfully loaded: {:?}", value);
        // Use value
    }
    Err(e) => {
        error!("Failed to load: {}", e);
        // Handle error gracefully
    }
}

// GOOD - Using if let
if let Some(value) = some_option {
    // Use value
} else {
    warn!("Value not available");
    // Provide fallback
}
```

#### ✅ **PREFERRED: Question Mark Operator**

```rust
fn load_config() -> Result<Config, Error> {
    let file = std::fs::read_to_string("config.toml")?;
    let config = toml::from_str(&file)?;
    Ok(config)
}
```

---

## Configuration System

### Using cosmic-config

COSMIC provides a standardized configuration system:

```rust
use cosmic_config::{Config, ConfigGet, ConfigSet};

// Initialize configuration
let config = Config::new("com.example.myapp", 1)?;

// Read values
let window_width: u32 = config.get("window_width").unwrap_or(800);
let theme_preference: String = config.get("theme").unwrap_or_default();

// Write values
config.set("window_width", 1024)?;
config.set("theme", "dark")?;
```

### Configuration File Location

- **User config**: `~/.config/cosmic/com.example.myapp/v1/`
- **System defaults**: `/usr/share/cosmic/com.example.myapp/v1/`

### Configuration Best Practices

- ✅ **DO**: Version your configuration (shown as `1` in example above)
- ✅ **DO**: Provide sensible defaults
- ✅ **DO**: Handle missing or corrupted config gracefully
- ✅ **DO**: Use semantic versioning for config changes
- ❌ **DON'T**: Store sensitive data in plain text config files
- ❌ **DON'T**: Panic if config is missing

---

## Performance and Optimization

### Memory Management

#### Applet Compilation

```bash
# Applets compiled as multicall binary (better performance, -115 MB disk usage)
# This is handled by the build system automatically
```

#### Widget Borrowing

```rust
// GOOD - Borrow from application state
fn view(&self) -> Element<Message> {
    widget::text(&self.label).into()  // Borrows, no allocation
}

// AVOID - Creating new strings unnecessarily
fn view(&self) -> Element<Message> {
    widget::text(self.label.clone()).into()  // Unnecessary clone
}
```

### Async Operations

#### Use Tasks for Async Work

```rust
impl Application for MyApp {
    fn update(&mut self, message: Message) -> cosmic::app::Task<Message> {
        match message {
            Message::LoadData => {
                // Return async task instead of blocking
                cosmic::app::Task::perform(
                    async { load_data_from_disk().await },
                    Message::DataLoaded
                )
            }
            Message::DataLoaded(data) => {
                self.data = data;
                cosmic::app::Task::none()
            }
        }
    }
}
```

#### Use Subscriptions for Continuous Streams

```rust
use cosmic::iced::Subscription;
use cosmic::iced::time;

impl Application for MyApp {
    fn subscription(&self) -> Subscription<Message> {
        // Timer example
        time::every(std::time::Duration::from_secs(1))
            .map(|_| Message::Tick)
    }
}
```

### Performance Best Practices

- ✅ **DO**: Use software renderer for low-memory applets (remove wgpu feature)
- ✅ **DO**: Profile with `cargo flamegraph`
- ✅ **DO**: Use `Rc<dyn Fn>` for frequently cloned style closures
- ✅ **DO**: Batch operations where possible
- ❌ **DON'T**: Perform I/O in `update()` method
- ❌ **DON'T**: Create unnecessary allocations in `view()`

---

## Build and Development Workflow

### Using `just` (Build Tool)

COSMIC projects use `just` as the preferred build tool:

```bash
# Check code quality (run before commits)
just check

# Build the project
just build

# Run the application
just run

# Build with vendored dependencies (for packaging)
just vendor
just build-vendored

# Install to system
just rootdir=/path prefix=/usr install
```

### Code Quality Checks

```bash
# Ensure code passes linter
just check

# For JSON output (useful for editor integration)
just check-json

# Format code
cargo fmt

# Run clippy
cargo clippy -- -D warnings
```

### Dependencies

#### Ubuntu/Pop!_OS

```bash
sudo apt install cargo cmake just libexpat1-dev \
    libfontconfig-dev libfreetype-dev libxkbcommon-dev pkgconf
```

#### Arch Linux

```bash
sudo pacman -S rust just base-devel
```

### Rust Toolchain

```bash
# Use rustup for latest Rust (distro versions may be too old)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install just via cargo if not in repos
cargo install just
```

---

## Wayland Integration

### Layer Shell Protocol

Applets use Wayland Layer Shell for panel integration:

```rust
// Automatically handled by cosmic::applet::run()
// Panel configuration read from environment variables:
// - COSMIC_PANEL_SIZE
// - COSMIC_PANEL_ANCHOR (Top, Bottom, Left, Right)
// - COSMIC_PANEL_THEME
```

### Popup Management

```rust
use cosmic::iced_runtime::platform_specific;
use cosmic::iced::window;

// Create popup
let popup_id = window::Id::unique();
let popup_settings = self.core.applet.get_popup_settings(
    self.core.main_window_id().unwrap(),
    popup_id,
    Some((width, height)),
);
platform_specific::shell::commands::popup::get_popup(popup_settings)

// Destroy popup
platform_specific::shell::commands::popup::destroy_popup(popup_id)
```

---

## Code Review Checklist

When reviewing COSMIC Desktop code, verify:

### Architecture

- [ ] Uses official app/applet template structure
- [ ] Implements `cosmic::Application` trait correctly
- [ ] Includes required `core: cosmic::Core` field
- [ ] APP_ID uses reverse domain notation
- [ ] Stateless widgets reference application model

### Error Handling

- [ ] No use of `unwrap()` or `expect()`
- [ ] Errors logged with `tracing::{error, warn}`
- [ ] Graceful fallbacks for missing data
- [ ] Result types propagated with `?` operator

### Theming

- [ ] No hard-coded colors or dimensions
- [ ] Uses `theme::spacing()` for layout
- [ ] Theme variables used for colors
- [ ] Tested in both light and dark modes
- [ ] Respects user's corner radius preference

### Performance

- [ ] No blocking I/O in `update()` method
- [ ] Async operations use `Task`s or `Subscription`s
- [ ] Widgets borrow from state (no unnecessary clones)
- [ ] Heavy operations moved to background tasks

### Applet-Specific (if applicable)

- [ ] Uses `cosmic::applet::run()` not `cosmic::app::run()`
- [ ] Implements `style()` returning `cosmic::applet::style()`
- [ ] Desktop file includes `NoDisplay=true` and `X-CosmicApplet=true`
- [ ] Popup positioning uses applet context helpers
- [ ] Enables `applet` feature in Cargo.toml

### Code Quality

- [ ] Passes `just check` without warnings
- [ ] Formatted with `cargo fmt`
- [ ] No clippy warnings
- [ ] Appropriate logging levels used
- [ ] Comments explain "why" not "what"

### Documentation

- [ ] Public functions have doc comments
- [ ] README includes build instructions
- [ ] Configuration options documented
- [ ] Desktop entry properly configured

---

## Common Patterns and Anti-Patterns

### ✅ Good Patterns

#### Idiomatic Widget Composition

```rust
use cosmic::Apply;

let content = widget::column()
    .spacing(theme::spacing().space_s)
    .push(
        widget::icon::from_name("folder-symbolic")
            .apply(widget::button::icon)
            .on_press(Message::OpenFolder)
    )
    .push(widget::text::body(&self.status))
    .align_items(Alignment::Center);
```

#### Clean Message Handling

```rust
fn update(&mut self, message: Message) -> cosmic::app::Task<Message> {
    match message {
        Message::LoadFile(path) => {
            cosmic::app::Task::perform(
                async move { tokio::fs::read_to_string(path).await },
                |result| match result {
                    Ok(content) => Message::FileLoaded(content),
                    Err(e) => Message::Error(e.to_string()),
                }
            )
        }
        Message::FileLoaded(content) => {
            self.content = content;
            cosmic::app::Task::none()
        }
        Message::Error(msg) => {
            error!("Operation failed: {}", msg);
            cosmic::app::Task::none()
        }
    }
}
```

### ❌ Anti-Patterns

#### Hard-Coded Values

```rust
// BAD
let button = widget::button("Click")
    .padding(10)
    .style(|_| button::Style {
        background: Some(Color::from_rgb(0.2, 0.4, 0.8).into()),
        ..Default::default()
    });

// GOOD
let spacing = theme::spacing();
let button = widget::button("Click")
    .padding(spacing.space_s)
    .style(button::Style::Primary);
```

#### Blocking Operations in Update

```rust
// BAD - Blocks UI thread
fn update(&mut self, message: Message) -> cosmic::app::Task<Message> {
    match message {
        Message::Load => {
            self.data = std::fs::read_to_string("data.txt").unwrap(); // Blocking!
            cosmic::app::Task::none()
        }
    }
}

// GOOD - Non-blocking
fn update(&mut self, message: Message) -> cosmic::app::Task<Message> {
    match message {
        Message::Load => {
            cosmic::app::Task::perform(
                async { tokio::fs::read_to_string("data.txt").await },
                |result| Message::DataLoaded(result)
            )
        }
        Message::DataLoaded(result) => {
            match result {
                Ok(data) => self.data = data,
                Err(e) => error!("Failed to load: {}", e),
            }
            cosmic::app::Task::none()
        }
    }
}
```

---

## Resources and References

### Official Documentation

- **libcosmic Book**: <https://pop-os.github.io/libcosmic-book/>
- **API Documentation**: <https://pop-os.github.io/libcosmic/cosmic/>
- **COSMIC Desktop**: <https://system76.com/cosmic>

### Templates and Examples

- **App Template**: <https://github.com/pop-os/cosmic-app-template>
- **Applet Template**: <https://github.com/pop-os/cosmic-applet-template>
- **Widget Examples**: <https://github.com/pop-os/libcosmic/tree/master/examples>
- **Design Demo**: <https://github.com/pop-os/cosmic-design-demo>

### Community

- **Pop!_OS Mattermost**: Join for developer discussions
- **GitHub Discussions**: <https://github.com/pop-os/cosmic-epoch/discussions>
- **COSMIC Themes**: <https://cosmicthemes.com/>

### Rust Learning

- **Rust Book**: <https://doc.rust-lang.org/book/>
- **Rust by Example**: <https://doc.rust-lang.org/rust-by-example/>
- **Rustlings**: <https://github.com/rust-lang/rustlings>

---

## Version History

### 1.0.0 (January 2026)

- Initial comprehensive skill document
- Covers libcosmic application and applet development
- Includes theming, performance, and Wayland integration
- Based on COSMIC Epoch 1 and libcosmic documentation

---

## Contributing to This Skill

This skill document should be updated when:

- New COSMIC Desktop versions introduce breaking changes
- libcosmic API changes significantly
- New best practices emerge from the COSMIC community
- Official documentation updates with new patterns

Maintain alignment with official System76 COSMIC documentation and examples.

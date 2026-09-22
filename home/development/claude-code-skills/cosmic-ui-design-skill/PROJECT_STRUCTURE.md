# COSMIC Project Structure Guide

## Recommended Directory Structure

### Small Application (Single Module)

```
my-cosmic-app/
├── Cargo.toml
├── justfile
├── README.md
├── LICENSE
├── .gitignore
├── src/
│   └── main.rs           # All code in one file
├── resources/
│   ├── icons/
│   │   └── my-app.svg
│   └── my-app.desktop
└── debian/              # Optional: for packaging
    ├── control
    ├── rules
    └── changelog
```

### Medium Application (Multiple Modules)

```
my-cosmic-app/
├── Cargo.toml
├── justfile
├── README.md
├── LICENSE
├── src/
│   ├── main.rs          # Entry point + Application trait
│   ├── app.rs           # Application struct
│   ├── message.rs       # Message enum
│   ├── config.rs        # Configuration management
│   ├── ui/
│   │   ├── mod.rs
│   │   ├── header.rs    # Header bar component
│   │   ├── sidebar.rs   # Sidebar component
│   │   └── content.rs   # Main content view
│   └── utils/
│       ├── mod.rs
│       └── helpers.rs
├── resources/
│   ├── icons/
│   └── my-app.desktop
└── i18n/                # Internationalization
    ├── en/
    └── es/
```

### Large Application (Feature-Based)

```
my-cosmic-app/
├── Cargo.toml
├── justfile
├── README.md
├── LICENSE
├── src/
│   ├── main.rs
│   ├── app.rs
│   ├── config.rs
│   ├── core/            # Core functionality
│   │   ├── mod.rs
│   │   ├── state.rs     # Application state
│   │   └── message.rs   # Message types
│   ├── features/        # Feature modules
│   │   ├── mod.rs
│   │   ├── editor/
│   │   │   ├── mod.rs
│   │   │   ├── view.rs
│   │   │   └── logic.rs
│   │   └── preview/
│   │       ├── mod.rs
│   │       ├── view.rs
│   │       └── logic.rs
│   ├── widgets/         # Custom widgets
│   │   ├── mod.rs
│   │   └── custom_widget.rs
│   ├── services/        # Background services
│   │   ├── mod.rs
│   │   ├── file_watcher.rs
│   │   └── network.rs
│   └── utils/
│       ├── mod.rs
│       ├── theme.rs
│       └── helpers.rs
├── resources/
│   ├── icons/
│   ├── my-app.desktop
│   └── metadata.xml
└── tests/
    ├── integration_tests.rs
    └── common/
        └── mod.rs
```

### Panel Applet

```
cosmic-applet-myapp/
├── Cargo.toml           # Must include applet feature
├── justfile
├── README.md
├── src/
│   ├── main.rs          # Entry point using applet::run
│   ├── config.rs        # Applet configuration
│   ├── popup.rs         # Popup view
│   └── icons.rs         # Icon management
├── resources/
│   ├── icons/
│   │   ├── icon-symbolic.svg
│   │   └── icon.svg
│   └── cosmic-applet-myapp.desktop
└── data/
    └── com.example.cosmic-applet-myapp.metainfo.xml
```

## File Templates

### main.rs (Application)

```rust
// Copyright notice and license

mod app;
mod config;
mod message;

use cosmic::app::Settings;

fn main() -> cosmic::iced::Result {
    // Initialize tracing
    tracing_subscriber::fmt::init();

    // Run application
    cosmic::app::run::<app::App>(Settings::default(), ())
}
```

### app.rs (Application Struct)

```rust
use cosmic::prelude::*;
use cosmic::{Application, Element, Core};

use crate::config::Config;
use crate::message::Message;

pub struct App {
    core: Core,
    config: Config,
    // Application state
}

impl Application for App {
    type Executor = cosmic::executor::Default;
    type Flags = ();
    type Message = Message;
    
    const APP_ID: &'static str = "com.example.myapp";

    fn core(&self) -> &Core {
        &self.core
    }

    fn core_mut(&mut self) -> &mut Core {
        &mut self.core
    }

    fn init(core: Core, _flags: Self::Flags) -> (Self, cosmic::app::Task<Self::Message>) {
        let config = Config::load().unwrap_or_default();
        
        let app = Self {
            core,
            config,
        };

        let command = app.set_window_title("My App");
        (app, command)
    }

    fn view(&self) -> Element<Self::Message> {
        self.build_ui()
    }

    fn update(&mut self, message: Self::Message) -> cosmic::app::Task<Self::Message> {
        self.handle_message(message)
    }

    fn subscription(&self) -> cosmic::iced::Subscription<Self::Message> {
        cosmic::iced::Subscription::none()
    }
}

impl App {
    fn build_ui(&self) -> Element<Message> {
        // Build UI here
        widget::text("Hello").into()
    }

    fn handle_message(&mut self, message: Message) -> cosmic::app::Task<Message> {
        // Handle messages
        cosmic::app::Task::none()
    }
}
```

### message.rs (Message Enum)

```rust
/// Messages that can be sent within the application
#[derive(Debug, Clone)]
pub enum Message {
    /// User clicked a button
    ButtonClicked,
    
    /// Data was loaded
    DataLoaded(Result<String, String>),
    
    /// Configuration changed
    ConfigChanged,
    
    // Add more messages as needed
}
```

### config.rs (Configuration)

```rust
use cosmic_config::{Config as CosmicConfig, ConfigGet, ConfigSet};
use serde::{Deserialize, Serialize};

const APP_ID: &str = "com.example.myapp";
const VERSION: u64 = 1;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub window_width: u32,
    pub window_height: u32,
    pub theme_preference: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            window_width: 800,
            window_height: 600,
            theme_preference: "system".to_string(),
        }
    }
}

impl Config {
    /// Load configuration from disk
    pub fn load() -> Result<Self, cosmic_config::Error> {
        let config = CosmicConfig::new(APP_ID, VERSION)?;
        
        Ok(Self {
            window_width: config.get("window_width").unwrap_or(800),
            window_height: config.get("window_height").unwrap_or(600),
            theme_preference: config.get("theme_preference").unwrap_or_default(),
        })
    }

    /// Save configuration to disk
    pub fn save(&self) -> Result<(), cosmic_config::Error> {
        let config = CosmicConfig::new(APP_ID, VERSION)?;
        
        config.set("window_width", self.window_width)?;
        config.set("window_height", self.window_height)?;
        config.set("theme_preference", &self.theme_preference)?;
        
        Ok(())
    }
}
```

### Cargo.toml (Application)

```toml
[package]
name = "my-cosmic-app"
version = "0.1.0"
edition = "2021"
license = "GPL-3.0"
description = "A COSMIC Desktop application"

[dependencies]
libcosmic = { git = "https://github.com/pop-os/libcosmic", default-features = false, features = ["desktop", "tokio", "wayland"] }
tokio = { version = "1", features = ["full"] }
tracing = "0.1"
tracing-subscriber = "0.3"
serde = { version = "1", features = ["derive"] }

[profile.release]
opt-level = 3
lto = "thin"
strip = true
```

### Cargo.toml (Applet)

```toml
[package]
name = "cosmic-applet-myapp"
version = "0.1.0"
edition = "2021"
license = "GPL-3.0"
description = "A COSMIC panel applet"

[dependencies]
libcosmic = { git = "https://github.com/pop-os/libcosmic", features = ["applet"] }
# For lower memory usage with software renderer:
# libcosmic = { git = "https://github.com/pop-os/libcosmic", features = ["applet"], default-features = false }

tracing = "0.1"
tracing-subscriber = "0.3"

[profile.release]
opt-level = 3
lto = "thin"
strip = true
```

### justfile

```makefile
# Build system configuration
name := 'my-cosmic-app'
export CARGO_TARGET_DIR := env_var_or_default('CARGO_TARGET_DIR', 'target')

# Default recipe - show help
default:
    @just --list

# Check code quality (run before commits!)
check:
    cargo clippy --all-features -- -D warnings
    cargo fmt --check

# Check with JSON output (for editor integration)
check-json:
    cargo clippy --all-features --message-format=json -- -D warnings

# Build the project
build:
    cargo build --release

# Run the application
run:
    cargo run

# Format code
fmt:
    cargo fmt

# Run tests
test:
    cargo test

# Clean build artifacts
clean:
    cargo clean

# Install to system (use with sudo)
install: build
    install -Dm0755 {{CARGO_TARGET_DIR}}/release/{{name}} {{prefix}}/bin/{{name}}
    install -Dm0644 resources/{{name}}.desktop {{prefix}}/share/applications/{{name}}.desktop

# Vendor dependencies for packaging
vendor:
    cargo vendor --sync Cargo.toml > .cargo/config.toml

# Build with vendored dependencies
build-vendored:
    cargo build --release --offline
```

### .desktop File

```ini
[Desktop Entry]
Version=1.0
Type=Application
Name=My COSMIC App
GenericName=Example Application
Comment=An example COSMIC Desktop application
Icon=my-cosmic-app
Exec=my-cosmic-app
Terminal=false
Categories=Utility;COSMIC;
Keywords=cosmic;utility;
StartupNotify=true
```

### .desktop File (Applet)

```ini
[Desktop Entry]
Name=My Applet
Type=Application
Exec=cosmic-applet-myapp
Terminal=false
Categories=COSMIC;
Keywords=COSMIC;panel;applet;
Icon=my-applet-icon
NoDisplay=true
X-CosmicApplet=true
X-CosmicHoverPopup=Auto
X-OverflowPriority=10
```

## Organization Best Practices

### 1. Separation of Concerns

```
✅ GOOD: Feature-based organization
src/
├── features/
│   ├── editor/      # All editor-related code
│   └── preview/     # All preview-related code

❌ BAD: Type-based organization
src/
├── views/           # All views mixed together
├── logic/           # All logic mixed together
└── models/          # All models mixed together
```

### 2. Module Structure

Each feature module should be self-contained:

```rust
// src/features/editor/mod.rs
mod view;
mod logic;
mod types;

pub use view::EditorView;
pub use types::EditorMessage;

// Internal implementation details stay private
use logic::internal_helper;
```

### 3. Message Organization

For large apps, organize messages by feature:

```rust
#[derive(Debug, Clone)]
pub enum Message {
    Editor(EditorMessage),
    Preview(PreviewMessage),
    Config(ConfigMessage),
}

#[derive(Debug, Clone)]
pub enum EditorMessage {
    TextChanged(String),
    Save,
}
```

### 4. Custom Widgets

Place custom widgets in their own module:

```rust
// src/widgets/custom_widget.rs
use cosmic::prelude::*;
use cosmic::{Element, widget};

pub fn custom_widget<Message>() -> Element<'static, Message> {
    widget::container(
        widget::text("Custom Widget")
    ).into()
}
```

### 5. Services and Background Tasks

```rust
// src/services/file_watcher.rs
use tokio::sync::mpsc;
use tracing::{info, error};

pub struct FileWatcher {
    // Service state
}

impl FileWatcher {
    pub fn new() -> Self {
        info!("File watcher service started");
        Self { }
    }

    pub async fn watch(&self, path: &str) -> Result<(), std::io::Error> {
        // Watch implementation
        Ok(())
    }
}
```

## Testing Structure

```
tests/
├── integration_tests.rs  # Integration tests
├── ui_tests.rs          # UI component tests
└── common/              # Shared test utilities
    └── mod.rs
```

### Example Test

```rust
// tests/integration_tests.rs
use my_cosmic_app::config::Config;

#[test]
fn test_config_default() {
    let config = Config::default();
    assert_eq!(config.window_width, 800);
    assert_eq!(config.window_height, 600);
}

#[test]
fn test_config_save_load() {
    let config = Config {
        window_width: 1024,
        window_height: 768,
        theme_preference: "dark".to_string(),
    };
    
    config.save().expect("Failed to save config");
    let loaded = Config::load().expect("Failed to load config");
    
    assert_eq!(config.window_width, loaded.window_width);
}
```

## Documentation Structure

### README.md Template

```markdown
# My COSMIC App

Brief description of your application.

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

### From Source

```bash
git clone https://github.com/user/my-cosmic-app
cd my-cosmic-app
just build
sudo just install
```

### Dependencies

On Ubuntu/Pop!_OS:
```bash
sudo apt install cargo cmake just libexpat1-dev \
    libfontconfig-dev libfreetype-dev libxkbcommon-dev pkgconf
```

## Usage

Launch from application menu or run:
```bash
my-cosmic-app
```

## Configuration

Configuration file location: `~/.config/cosmic/com.example.myapp/v1/`

## Development

```bash
# Check code quality
just check

# Run in development
just run

# Run tests
just test
```

## License

GPL-3.0 License
```

## Version Control

### .gitignore

```gitignore
# Rust
/target/
Cargo.lock

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Build artifacts
*.deb
*.rpm
```

## Summary

Good project structure:
- ✅ Separates concerns (features, widgets, services)
- ✅ Uses consistent naming
- ✅ Keeps modules self-contained
- ✅ Provides clear public APIs
- ✅ Includes comprehensive documentation
- ✅ Has proper build configuration
- ✅ Includes tests

This structure scales from small single-file apps to large feature-rich applications.

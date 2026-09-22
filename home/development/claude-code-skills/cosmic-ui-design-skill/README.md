# COSMIC Desktop UI Design & Development Skill

A comprehensive Claude Code skill for developing COSMIC Desktop applications and applets with best practices from System76's official documentation.

## Overview

This skill provides expert guidance for:
- ✨ **COSMIC Applications**: Full desktop applications using libcosmic
- 🎯 **Panel Applets**: Lightweight widgets for panels and docks
- 🎨 **Theming**: Proper theme integration and custom styling
- ⚡ **Performance**: Optimization and async patterns
- 🛡️ **Error Handling**: Safe Rust patterns without unwrap/expect
- 🔧 **Wayland Integration**: Layer Shell protocol and popup management

## Installation

### Upload to Claude Code

1. **Download or clone this skill directory**
2. **Upload to Claude Code:**
   - Open Claude Code
   - Navigate to Settings → Skills
   - Click "Upload Skill"
   - Select the `cosmic-ui-design-skill` directory

### Alternative: Clone and Link

```bash
# Clone this skill to your skills directory
cd ~/.config/claude-code/skills/
git clone [repository-url] cosmic-ui-design-skill

# Or copy the directory
cp -r /path/to/cosmic-ui-design-skill ~/.config/claude-code/skills/
```

## Quick Start

### Using the Skill

Once uploaded, the skill is automatically available in Claude Code. Simply mention COSMIC, libcosmic, or applet development in your prompts:

```
"Review this COSMIC application for best practices"
"Help me create a panel applet for network monitoring"
"Fix the theming issues in my COSMIC app"
```

### Using Specialized Agents

This skill includes 7 specialized agents for different aspects of COSMIC development:

#### 1. **cosmic-architect** - Application Architecture
```bash
# Example usage in Claude Code
@cosmic-architect review this application structure

# Use shortcuts
@cosmic-architect /review-app-structure
@cosmic-architect /suggest-refactoring
```

**Best for:**
- Reviewing Application trait implementations
- State management patterns
- Message handling organization
- Async operation structure

#### 2. **cosmic-theme-expert** - Theming & Styling
```bash
@cosmic-theme-expert check for hard-coded values

# Use shortcuts
@cosmic-theme-expert /audit-theming
@cosmic-theme-expert /convert-hardcoded
```

**Best for:**
- Finding hard-coded colors/dimensions
- Theme integration
- Accessibility checks
- Light/dark mode compatibility

#### 3. **cosmic-applet-specialist** - Panel Applets
```bash
@cosmic-applet-specialist review this panel applet

# Use shortcuts
@cosmic-applet-specialist /review-applet
@cosmic-applet-specialist /fix-popup
```

**Best for:**
- Applet structure validation
- Popup management
- Panel integration
- Desktop entry configuration

#### 4. **cosmic-widget-builder** - Widget Composition
```bash
@cosmic-widget-builder improve this layout

# Use shortcuts
@cosmic-widget-builder /review-widgets
@cosmic-widget-builder /improve-layout
```

**Best for:**
- Widget selection and usage
- Layout patterns
- Custom widget creation
- Icon and text hierarchy

#### 5. **cosmic-error-handler** - Error Handling
```bash
@cosmic-error-handler remove all unwraps

# Use shortcuts
@cosmic-error-handler /remove-unwraps
@cosmic-error-handler /audit-error-handling
```

**Best for:**
- Eliminating unwrap/expect
- Adding proper logging
- Result propagation
- Graceful error recovery

#### 6. **cosmic-performance-optimizer** - Performance
```bash
@cosmic-performance-optimizer find bottlenecks

# Use shortcuts
@cosmic-performance-optimizer /find-bottlenecks
@cosmic-performance-optimizer /optimize-memory
```

**Best for:**
- Identifying blocking operations
- Memory optimization
- Async patterns
- View rendering efficiency

#### 7. **cosmic-code-reviewer** - Comprehensive Review
```bash
@cosmic-code-reviewer full review

# Use shortcuts
@cosmic-code-reviewer /full-review
@cosmic-code-reviewer /pre-commit-check
```

**Best for:**
- Complete code reviews
- Pre-commit checks
- All-in-one analysis
- Prioritized recommendations

## Example Workflows

### Creating a New Application

```bash
# 1. Generate from template
cargo generate gh:pop-os/cosmic-app-template

# 2. Ask for architecture review
@cosmic-architect review this application structure

# 3. Get theming guidance
@cosmic-theme-expert help me set up proper theming

# 4. Performance check
@cosmic-performance-optimizer review my update() method
```

### Creating a Panel Applet

```bash
# 1. Generate from template
cargo generate gh:pop-os/cosmic-applet-template

# 2. Get applet-specific guidance
@cosmic-applet-specialist review my applet setup

# 3. Fix popup management
@cosmic-applet-specialist /fix-popup

# 4. Final review
@cosmic-code-reviewer /pre-commit-check
```

### Code Review Workflow

```bash
# 1. Quick pre-commit check
@cosmic-code-reviewer /pre-commit-check

# 2. If issues found, use specialized agents:
@cosmic-error-handler /remove-unwraps
@cosmic-theme-expert /audit-theming
@cosmic-performance-optimizer /find-bottlenecks

# 3. Final comprehensive review
@cosmic-code-reviewer /full-review
```

## Features

### Comprehensive Coverage

- ✅ **Application Development**: Complete guidance for libcosmic apps
- ✅ **Applet Development**: Panel and dock widget patterns
- ✅ **Theming System**: Material-You inspired theming with OKLCH
- ✅ **Widget Library**: All libcosmic widgets and composition patterns
- ✅ **Wayland Integration**: Layer Shell protocol and popup management
- ✅ **Error Handling**: Safe Rust patterns without unwrap/expect
- ✅ **Performance**: Async patterns, memory optimization
- ✅ **Configuration**: cosmic-config usage and best practices
- ✅ **Build System**: just workflows and package management

### Based on Official Documentation

This skill is derived from:
- 📚 Official libcosmic Book: https://pop-os.github.io/libcosmic-book/
- 📚 COSMIC API Documentation: https://pop-os.github.io/libcosmic/
- 📚 System76 Blog Posts: https://blog.system76.com/
- 📚 Official Templates: cosmic-app-template, cosmic-applet-template
- 📚 Production Code: COSMIC Settings, Files, Terminal, etc.

### Code Quality Checklist

Every review includes checks for:
- [ ] Application trait implementation
- [ ] No hard-coded values (colors, dimensions, radii)
- [ ] No unwrap/expect calls
- [ ] Proper error logging
- [ ] Theme integration
- [ ] Performance optimization
- [ ] Widget best practices
- [ ] Documentation completeness

## Tips for Best Results

### 1. **Be Specific About Your Needs**

```bash
# Less specific
"Review this code"

# More specific
"@cosmic-theme-expert check this widget tree for hard-coded colors and suggest theme-based replacements"
```

### 2. **Use the Right Agent**

Match your task to the specialized agent:
- Architecture issues → `@cosmic-architect`
- Styling problems → `@cosmic-theme-expert`
- Applet-specific → `@cosmic-applet-specialist`
- General review → `@cosmic-code-reviewer`

### 3. **Leverage Shortcuts**

Shortcuts provide focused reviews:
```bash
@cosmic-error-handler /remove-unwraps       # Fast, focused
@cosmic-code-reviewer /full-review          # Comprehensive
@cosmic-applet-specialist /fix-popup        # Specific issue
```

### 4. **Iterative Development**

```bash
# 1. Build basic structure
@cosmic-architect help me structure this app

# 2. Add theming
@cosmic-theme-expert integrate theme properly

# 3. Optimize
@cosmic-performance-optimizer check for issues

# 4. Final review
@cosmic-code-reviewer /full-review
```

### 5. **Provide Context**

```bash
# Include relevant information
"I'm building a network monitor applet for COSMIC panel that shows connection status and speed. 
@cosmic-applet-specialist review this popup management code"
```

## Troubleshooting

### Skill Not Loading

1. Check the directory structure:
   ```
   cosmic-ui-design-skill/
   ├── SKILL.md
   ├── agents.json
   └── README.md
   ```

2. Verify JSON syntax in `agents.json`:
   ```bash
   cat agents.json | jq
   ```

3. Restart Claude Code

### Agent Not Responding

1. Try explicit mentions:
   ```
   @cosmic-architect please review this
   ```

2. Use shortcuts:
   ```
   @cosmic-architect /review-app-structure
   ```

3. Fall back to default:
   ```
   Review this COSMIC code for best practices
   ```

## Documentation Structure

### SKILL.md Contents

1. **Core Principles**: Design language, architecture, development standards
2. **Application Development**: Structure, traits, patterns
3. **Applet Development**: Panel integration, popups, Layer Shell
4. **Widget Usage**: Composition, layouts, custom widgets
5. **Theming & Styling**: Theme integration, custom styles, accessibility
6. **Error Handling**: Safe patterns, logging, recovery
7. **Performance**: Optimization, async patterns, memory management
8. **Build Workflow**: just commands, dependencies, toolchain
9. **Wayland Integration**: Layer Shell, popups, protocols
10. **Code Review Checklist**: Comprehensive review criteria
11. **Patterns & Anti-Patterns**: Good and bad examples
12. **Resources**: Official docs, templates, community

### Agent Capabilities

| Agent | Primary Focus | Best For |
|-------|--------------|----------|
| `cosmic-architect` | Architecture & Structure | App trait, state management, async |
| `cosmic-theme-expert` | Theming & Styling | Colors, spacing, accessibility |
| `cosmic-applet-specialist` | Panel Applets | Layer Shell, popups, panel config |
| `cosmic-widget-builder` | Widget Composition | Layouts, custom widgets, icons |
| `cosmic-error-handler` | Error Handling | Removing unwrap, logging, safety |
| `cosmic-performance-optimizer` | Performance | Async, memory, optimization |
| `cosmic-code-reviewer` | Comprehensive Reviews | All-in-one, pre-commit checks |

## Contributing

### Updating the Skill

To update this skill with new COSMIC features:

1. **Edit SKILL.md**: Add new patterns, update best practices
2. **Update agents.json**: Add new shortcuts or capabilities
3. **Test thoroughly**: Verify agents work with new content
4. **Document changes**: Update this README

### Reporting Issues

If you find issues or have suggestions:
1. Test with the default `@cosmic-code-reviewer` agent
2. Provide example code that demonstrates the issue
3. Include expected vs actual behavior
4. Note which agent was used

## Version History

### 1.0.0 (January 2026)
- Initial release
- 7 specialized agents
- Comprehensive SKILL.md with all COSMIC patterns
- Based on COSMIC Epoch 1 and latest libcosmic

## Resources

### Official COSMIC Resources
- **libcosmic Book**: https://pop-os.github.io/libcosmic-book/
- **API Docs**: https://pop-os.github.io/libcosmic/cosmic/
- **COSMIC Desktop**: https://system76.com/cosmic
- **App Template**: https://github.com/pop-os/cosmic-app-template
- **Applet Template**: https://github.com/pop-os/cosmic-applet-template

### Learning Resources
- **Rust Book**: https://doc.rust-lang.org/book/
- **Rust by Example**: https://doc.rust-lang.org/rust-by-example/
- **iced Tutorial**: https://book.iced.rs/

### Community
- **Pop!_OS Mattermost**: Join for developer discussions
- **COSMIC GitHub**: https://github.com/pop-os/cosmic-epoch
- **COSMIC Themes**: https://cosmicthemes.com/

## License

This skill document is provided as-is for use with Claude Code. Content is derived from official COSMIC documentation and best practices.

---

**Happy COSMIC Development! 🚀**

For questions or improvements, engage with the COSMIC community or contribute back to this skill.

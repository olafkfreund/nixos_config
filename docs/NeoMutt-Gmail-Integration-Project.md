# NeoMutt Gmail Integration Project

**Revolutionary CLI Email System with AI Enhancement**

A comprehensive project to integrate NeoMutt with Gmail accounts, featuring AI-powered email processing, beautiful Gruvbox theming, shell integration, and intelligent automation - all managed through NixOS configuration.

---

## 📋 **Project Overview**

### **Goal**
Create a powerful, AI-enhanced CLI email system that transforms email management into a seamless, productive, and beautiful experience fully integrated with the existing NixOS infrastructure.

### **Scope**
- Full NeoMutt configuration for 2 Gmail accounts
- AI-powered email processing with OpenAI integration
- Beautiful Gruvbox theming and terminal integration
- Shell integration with Zsh and Starship prompt
- SwayNC notifications for high-priority emails
- Conservative automation with user control
- Complete NixOS module implementation

---

## 🎯 **Project Requirements**

### **Accounts & Authentication**
- **Primary Account**: olaf@freundcloud.com
- **Secondary Account**: olaf.loken@gmail.com
- **Authentication**: OAuth2 (no app passwords)
- **Security**: No GPG encryption (user preference)
- **Approach**: Full CLI experience (no mobile app compatibility needed)

### **AI Integration**
- **Provider**: OpenAI (existing infrastructure)
- **Features**: Email summarization, smart replies, meeting detection, task extraction
- **Automation Level**: Conservative (user approval required)

### **Notification System**
- **Service**: SwayNC integration
- **Priority**: High-priority emails only
- **Actionable**: Mark read, reply, archive from notifications

### **Technical Requirements**
- **Platform**: NixOS module implementation
- **Theme**: Gruvbox consistency throughout
- **Shell**: Zsh integration with aliases and functions
- **Prompt**: Starship integration with email indicators
- **Secrets**: Agenix encrypted credential management

---

## 🏗️ **Implementation Phases**

### **Phase 1: Foundation Setup** ⏳ `Status: Planning`

#### **1.1 NixOS Module Structure**
- [ ] Create `modules/email/neomutt/default.nix`
- [ ] Create `modules/email/neomutt/accounts.nix`
- [ ] Create `modules/email/neomutt/theme.nix`
- [ ] Create `modules/email/neomutt/keybindings.nix`
- [ ] Create feature flag system for email module

#### **1.2 Account Configuration**
- [ ] Gmail OAuth2 setup for olaf@freundcloud.com
- [ ] Gmail OAuth2 setup for olaf.loken@gmail.com
- [ ] IMAP/SMTP configuration
- [ ] Folder mapping for Gmail labels
- [ ] Account switching mechanisms

#### **1.3 Basic NeoMutt Setup**
- [ ] Core NeoMutt configuration
- [ ] Email synchronization (mbsync/OfflineIMAP)
- [ ] Email sending (msmtp)
- [ ] Basic folder structure
- [ ] Initial key bindings

#### **1.4 Secrets Management**
- [ ] Create encrypted OAuth2 tokens with Agenix
- [ ] SMTP/IMAP credentials management
- [ ] Secure token refresh mechanisms
- [ ] Account-specific secret organization

**Phase 1 Deliverables:**
- Working NeoMutt with 2 Gmail accounts
- Basic email send/receive functionality
- Secure credential management
- NixOS module structure

---

### **Phase 2: Visual Enhancement** ⏳ `Status: Pending`

#### **2.1 Gruvbox Theme Implementation**
- [ ] Custom NeoMutt colorscheme matching existing Gruvbox setup
- [ ] Message list styling with color-coded priorities
- [ ] Sidebar folder navigation theming
- [ ] Status bar customization
- [ ] Thread view styling

#### **2.2 HTML Email & Media Support**
- [ ] HTML email rendering with w3m integration
- [ ] Image display using chafa/timg
- [ ] Attachment preview system
- [ ] PDF/document viewing integration
- [ ] Mime type handling optimization

#### **2.3 Advanced UI Features**
- [ ] Threaded conversation view
- [ ] Smart folder organization
- [ ] Enhanced message formatting
- [ ] Custom header display
- [ ] Progress indicators and status messages

**Phase 2 Deliverables:**
- Beautiful Gruvbox-themed email interface
- HTML email rendering with images
- Enhanced user experience
- Optimized attachment handling

---

### **Phase 3: Shell Integration** ⏳ `Status: Pending`

#### **3.1 Zsh Functions & Aliases**
- [ ] `email` - Quick NeoMutt launch
- [ ] `check-mail` - New email checking with count
- [ ] `compose "text"` - Quick compose function
- [ ] `email-search "query"` - Intelligent search
- [ ] `email-stats` - Email statistics display

#### **3.2 Starship Prompt Integration**
- [ ] New email indicator module (📧 with count)
- [ ] Email sync status display
- [ ] Unread count badge with color coding
- [ ] Connection status indicators
- [ ] Account switching indicators

#### **3.3 Terminal Integration**
- [ ] Email composition in preferred editor
- [ ] Terminal-optimized viewing
- [ ] Keyboard shortcut system
- [ ] Context-aware completions
- [ ] Background sync status

**Phase 3 Deliverables:**
- Seamless shell integration
- Starship prompt email indicators
- Convenient email workflow aliases
- Terminal-optimized experience

---

### **Phase 4: AI Intelligence** ⏳ `Status: Pending`

#### **4.1 Core AI Email Processing**
- [ ] Email summarization system using OpenAI
- [ ] Smart reply generation with context awareness
- [ ] Email importance scoring
- [ ] Content categorization (work, personal, newsletters)
- [ ] Language and tone analysis

#### **4.2 Meeting & Task Detection**
- [ ] Meeting request detection and parsing
- [ ] Calendar event suggestion system
- [ ] Task extraction from email content
- [ ] Deadline and follow-up identification
- [ ] Integration with existing Taskwarrior system

#### **4.3 AI Shell Functions**
- [ ] `ai-summarize-email <id>` - Email summarization
- [ ] `ai-reply-draft <id>` - Generate reply drafts
- [ ] `ai-extract-tasks <id>` - Extract action items
- [ ] `ai-schedule-meeting <id>` - Meeting detection
- [ ] `ai-email-insights` - Daily email analysis

#### **4.4 Conservative Automation**
- [ ] User approval workflows for all automation
- [ ] Suggestion system rather than automatic actions
- [ ] Configurable AI processing levels
- [ ] Manual override capabilities
- [ ] Audit trail for AI actions

**Phase 4 Deliverables:**
- AI-powered email intelligence
- Smart assistance features
- Task and meeting automation
- Conservative, user-controlled AI

---

### **Phase 5: Notifications & Workflow** ⏳ `Status: Pending`

#### **5.1 SwayNC Integration**
- [ ] Rich email notifications with previews
- [ ] Actionable notification buttons (Read, Reply, Archive)
- [ ] High-priority email filtering
- [ ] Notification batching and summaries
- [ ] Custom notification sounds and styling

#### **5.2 Email Workflow Automation**
- [ ] Smart filing suggestions (user-approved)
- [ ] Auto-categorization with manual review
- [ ] Email template system
- [ ] Bulk operation assistance
- [ ] Follow-up reminder system

#### **5.3 Search & Organization**
- [ ] Notmuch integration for fast search
- [ ] Tag-based organization system
- [ ] Advanced search syntax
- [ ] Saved search queries
- [ ] Email analytics and reporting

**Phase 5 Deliverables:**
- Intelligent notification system
- Streamlined email workflows
- Advanced search capabilities
- Productivity-focused organization

---

### **Phase 6: Monitoring & Analytics** ⏳ `Status: Pending`

#### **6.1 Email Monitoring Integration**
- [ ] Email sync metrics for Prometheus
- [ ] Performance monitoring (sync times, errors)
- [ ] Storage usage tracking
- [ ] Account health monitoring
- [ ] Integration with existing monitoring dashboard

#### **6.2 Productivity Analytics**
- [ ] Email volume and pattern analysis
- [ ] Response time tracking
- [ ] Email productivity insights
- [ ] Communication pattern visualization
- [ ] AI-generated productivity reports

#### **6.3 System Optimization**
- [ ] Email caching optimization
- [ ] Sync performance tuning
- [ ] Storage management
- [ ] Network usage optimization
- [ ] Battery life considerations (laptop use)

**Phase 6 Deliverables:**
- Comprehensive email monitoring
- Productivity analytics system
- Performance optimization
- Integration with existing observability

---

## 📁 **Project Structure**

### **NixOS Module Organization**
```
modules/
├── email/
│   ├── default.nix              # Main email module
│   ├── neomutt/
│   │   ├── default.nix          # NeoMutt configuration
│   │   ├── accounts.nix         # Gmail account setup
│   │   ├── theme.nix            # Gruvbox theming
│   │   ├── keybindings.nix      # Custom key bindings
│   │   ├── ai-integration.nix   # AI processing functions
│   │   └── notifications.nix    # SwayNC integration
│   ├── sync/
│   │   ├── mbsync.nix          # Email synchronization
│   │   └── monitoring.nix       # Sync monitoring
│   └── shell/
│       ├── zsh-integration.nix  # Shell functions
│       └── starship.nix         # Prompt integration
```

### **Configuration Files**
```
home/
├── email/
│   ├── neomutt/
│   │   ├── neomuttrc            # Main config
│   │   ├── colors-gruvbox       # Theme file
│   │   ├── bindings             # Key bindings
│   │   └── accounts/
│   │       ├── freundcloud.com  # Account configs
│   │       └── gmail.com
│   └── scripts/
│       ├── ai-email-processor   # AI processing scripts
│       ├── email-notifications  # Notification scripts
│       └── email-analytics      # Analytics scripts
```

### **Secret Management**
```
secrets/
├── email-oauth-freundcloud.age  # OAuth2 tokens
├── email-oauth-gmail.age        # OAuth2 tokens
├── email-smtp-freundcloud.age   # SMTP credentials
└── email-smtp-gmail.age         # SMTP credentials
```

---

## 🔧 **Technical Implementation Details**

### **Gmail OAuth2 Setup**
1. **Google Cloud Console** project creation
2. **OAuth2 credentials** generation for desktop application
3. **Token generation** using oauth2ms or similar tool
4. **Refresh token** management and automated renewal
5. **Secure storage** using Agenix encryption

### **NeoMutt Configuration Strategy**
- **Account-specific** configurations with shared base settings
- **Modular approach** allowing easy account addition/removal
- **Performance optimization** with proper caching and indexing
- **Security considerations** with secure credential handling

### **AI Integration Architecture**
- **Email processing pipeline** with configurable AI analysis levels
- **Context preservation** for intelligent reply generation
- **Privacy protection** ensuring email content security
- **Rate limiting** to manage API usage and costs
- **Fallback mechanisms** for offline or API unavailability

### **Shell Integration Design**
- **Non-intrusive** integration that doesn't slow down shell startup
- **Background processing** for email checking and sync
- **Caching mechanisms** for fast status display
- **Error handling** with graceful degradation

---

## 📊 **Success Metrics**

### **Functionality Metrics**
- [ ] Both Gmail accounts working seamlessly
- [ ] HTML emails rendering properly with images
- [ ] AI summarization accuracy > 90%
- [ ] Notification system working for high-priority emails
- [ ] Shell integration responsive (< 100ms for status)

### **Performance Metrics**
- [ ] Email sync time < 30 seconds for normal loads
- [ ] Search response time < 2 seconds
- [ ] Startup time < 3 seconds
- [ ] Memory usage < 500MB for typical workload
- [ ] Battery impact minimal on laptop

### **User Experience Metrics**
- [ ] Email workflow efficiency improvement
- [ ] Reduced time spent on email management
- [ ] Improved email response times
- [ ] Better email organization and searchability
- [ ] Seamless integration with existing workflow

---

## 🚀 **Getting Started**

### **Phase 1 Kickoff**
1. **Review requirements** and validate approach
2. **Set up development environment** for testing
3. **Create initial OAuth2 credentials** for Gmail accounts
4. **Begin NixOS module structure** implementation
5. **Document progress** and update this file regularly

### **Development Guidelines**
- **Modular design** - Each component should be independently testable
- **Security first** - All credentials properly encrypted and managed
- **Performance conscious** - Optimize for speed and resource usage
- **User-friendly** - Conservative automation with clear user control
- **Documentation** - Comprehensive docs for maintenance and extension

---

## 📝 **Notes & Considerations**

### **Security Notes**
- OAuth2 tokens stored encrypted with Agenix
- No plaintext credentials in configuration
- Regular token refresh automation
- Audit trail for all automated actions

### **Performance Considerations**
- Background sync to avoid blocking user workflow
- Intelligent caching for frequently accessed emails
- Lazy loading for large mailboxes
- Resource usage monitoring and optimization

### **Future Enhancements**
- Multi-provider email support (non-Gmail)
- Advanced AI features (sentiment analysis, auto-responses)
- Mobile notification bridging
- Team collaboration features
- Email analytics dashboard

---

## 📅 **Timeline Estimate**

- **Phase 1**: 2-3 weeks (Foundation)
- **Phase 2**: 1-2 weeks (Visual Enhancement)
- **Phase 3**: 1 week (Shell Integration)
- **Phase 4**: 2-3 weeks (AI Intelligence)
- **Phase 5**: 1-2 weeks (Notifications & Workflow)
- **Phase 6**: 1 week (Monitoring & Analytics)

**Total Estimated Time**: 8-12 weeks for complete implementation

---

**Last Updated**: January 2025  
**Project Status**: Phase 1 - Planning  
**Next Milestone**: Begin NixOS module structure implementation
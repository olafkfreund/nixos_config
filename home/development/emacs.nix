{
  lib,
  pkgs,
  config,
  ...
}: {
  programs.emacs = {
    enable = true;
    package = pkgs.emacs30-nox;
    extraPackages = epkgs:
      with epkgs; [
        # Theme and UI
        gruvbox-theme
        doom-modeline
        all-the-icons
        bufferbin

        # Start page and dashboard
        dashboard
        page-break-lines
        all-the-icons-dired
        projectile

        # File navigation and search
        fzf

        # Security and Secrets
        sops
        age
        agenix

        # Additional Nix tools
        nix-sandbox
        nixos-options

        # LSP support
        lsp-mode
        lsp-ui
        lsp-treemacs
        lsp-ivy

        # Development tools
        company
        flycheck
        magit
        projectile
        treemacs
        treemacs-all-the-icons
        treemacs-nerd-icons
        rainbow-delimiters
        which-key
        helpful
        counsel
        ivy
        swiper
        yasnippet
        yasnippet-snippets

        # AI and coding assistance
        copilot
        gptel # ChatGPT integration
        copilot-chat # Now available in nixpkgs

        # Nix development
        nix-mode
        nix-update
        nixpkgs-fmt
        direnv
        envrc

        # Terraform development
        terraform-mode
        hcl-mode
        company-terraform

        # Markdown support
        markdown-mode
        markdown-toc
        grip-mode # GitHub-flavored markdown preview

        # Python development
        python-mode
        python-pytest
        python-docstring
        blacken # Format on save with black
        py-isort # Python import sorting

        # Go development
        go-mode
        go-eldoc # Documentation integration
        go-guru # Additional Go tools
        gotest # Test integration
        go-tag # Struct tag management
        go-gen-test # Test generation

        # Other language-specific packages
        yaml-mode
        web-mode
        typescript-mode
        rust-mode
        lua-mode
        json-mode
        docker-compose-mode

        # Email and communication
        mu4e
        mu4e-views

        # RSS reader
        elfeed
        elfeed-org

        # Org mode and note-taking
        org
        org-roam
        org-bullets
        org-present
        org-download

        # Writing and documentation
        olivetti
      ];
  };

  # Ensure org-roam directory exists
  home.activation.createOrgRoamDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/org-roam
  '';

  # Create nixos-banner.txt file with proper permissions
  home.file = {
    ".emacs.d/nixos-banner.txt" = {
      text = ''
        ███╗   ██╗██╗██╗  ██╗ ██████╗ ███████╗    ███████╗███╗   ███╗ █████╗  ██████╗███████╗
        ████╗  ██║██║╚██╗██╔╝██╔═══██╗██╔════╝    ██╔════╝████╗ ████║██╔══██╗██╔════╝██╔════╝
        ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║███████╗    █████╗  ██╔████╔██║███████║██║     ███████╗
        ██║╚██╗██║██║ ██╔██╗ ██║   ██║╚════██║    ██╔══╝  ██║╚██╔╝██║██╔══██║██║     ╚════██║
        ██║ ╚████║██║██╔╝ ██╗╚██████╔╝███████║    ███████╗██║ ╚═╝ ██║██║  ██║╚██████╗███████║
        ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝    ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝
      '';
      executable = false;
    };

    ".emacs.d/early-init.el".text = ''
            ;; Prevent package.el from modifying this file
            (setq package-enable-at-startup nil)

            ;; Pre-declare org-evil-motion-mode variable to avoid "void variable" errors
            (defvar org-evil-motion-mode nil
              "Non-nil if Org-Evil-Motion mode is enabled.
      Use the command `org-evil-motion-mode' to change this variable.")
    '';

    ".emacs.d/init.el".text = ''
      ;; Initialize package system
      (require 'package)
      (setq package-archives nil)
      (package-initialize)

      ;; Set up use-package
      (require 'use-package)
      (setq use-package-always-ensure nil) ;; Important for NixOS: packages are already installed

      ;; Set custom-file to prevent Emacs from modifying init.el
      (setq custom-file (expand-file-name "custom-vars.el" user-emacs-directory))
      (when (file-exists-p custom-file)
        (load custom-file))

      ;; Load main configuration
      (load-file "~/.emacs.d/config.el")
    '';

    ".emacs.d/config.el".text = ''
      ;; Basic UI settings
      (menu-bar-mode -1)
      (when (fboundp 'tool-bar-mode)
        (tool-bar-mode -1))
      (when (fboundp 'scroll-bar-mode)
        (scroll-bar-mode -1))
      (setq inhibit-startup-screen t)
      (setq initial-scratch-message nil)

      ;; Line numbers
      (global-display-line-numbers-mode t)

      ;; Theme setup (Gruvbox)
      (use-package gruvbox-theme
        :config
        (load-theme 'gruvbox-dark-medium t))

      ;; Font setup
      (set-face-attribute 'default nil :height 110)

      ;; Configuration for nix-sandbox - isolated Nix environments for Emacs
      (use-package nix-sandbox
        :config
        ;; Set up Nix Sandbox to provide isolated compilation environments
        (setq nix-sandbox-rc-directory "~/.config/nix-sandbox")

        ;; Enable flycheck integration with nix-sandbox
        (with-eval-after-load 'flycheck
          (setq flycheck-command-wrapper-function
                (lambda (command)
                  (apply 'nix-sandbox-shell-command nix-sandbox-rc-directory command)))

          ;; Use sandbox environment for executables
          (setq flycheck-executable-find
                (lambda (cmd)
                  (nix-sandbox-executable-find nix-sandbox-rc-directory cmd))))

        ;; Key bindings for nix-sandbox
        :bind (("C-c n s" . nix-sandbox-shell)
               ("C-c n b" . nix-sandbox-compile)
               ("C-c n r" . nix-sandbox-run-command)))

      ;; Configuration for nixos-options - browse and insert NixOS options
      (use-package nixos-options
        :config
        ;; Function to check when nixos-option should activate
        (defun my/nixos-file-p ()
          "Return non-nil if the current buffer is likely a NixOS configuration file."
          (and buffer-file-name
               (or (string-match-p "/\\(configuration\\|hardware\\|modules\\|packages\\)\\.nix$" buffer-file-name)
                   (string-match-p "\\.nix$" buffer-file-name))))

        ;; Set up company backend for nixos-options
        (with-eval-after-load 'company
          (add-to-list 'company-backends '(company-nixos-options)))

        ;; Key bindings for nixos-options
        :bind (:map nix-mode-map
                    ("C-c C-o" . nixos-options-doc)
                    ("C-c C-d" . nixos-options-doc-at-point)))

      ;; FZF configuration - Fuzzy finder integration
      (use-package fzf
        :config
        ;; Set FZF path (uses the system fzf via Nix)
        (setq fzf/executable "fzf")

        ;; Default directory to start in (projectile project root or default-directory)
        (setq fzf/position-bottom t)
        (setq fzf/window-height 15)

        ;; Add args passed to fzf binary
        (setq fzf/args "-x --color=16 --print-query --margin=1,0 --no-hscroll")

        ;; Configure preview window
        (setq fzf/args-for-preview "--preview 'bat --style=numbers --color=always --line-range :500 {}'")

        ;; Set up key bindings for common operations
        :bind
        (("C-c f f" . fzf)               ;; Find files in current directory
         ("C-c f d" . fzf-directory)     ;; Find files in specified directory
         ("C-c f g" . fzf-grep)          ;; Grep in current directory
         ("C-c f p" . fzf-git-files)     ;; Find files tracked by git
         ("C-c f b" . fzf-switch-buffer) ;; Find and switch buffers
         ("M-p" . fzf-projectile)))      ;; Find files in projectile project

      ;; SOPS configuration for encrypted secrets
      (use-package sops-el
        :config
        ;; Set default SOPS config file location
        (setq sops-default-config-file "~/.sops.yaml")

        ;; Enable automatic decryption for .sops.yaml files
        (add-to-list 'auto-mode-alist '("\\.sops\\.ya?ml\\'" . sops-yaml-mode))
        (add-to-list 'auto-mode-alist '("\\.sops\\.json\\'" . sops-json-mode))

        ;; Enable automatic sops mode based on file content
        (add-hook 'yaml-mode-hook 'sops-yaml-mode-maybe)
        (add-hook 'json-mode-hook 'sops-json-mode-maybe)

        ;; Configure SOPS with age encryption (if used)
        (when (file-exists-p "~/.config/sops/age/keys.txt")
          (setq sops-age-keyfile "~/.config/sops/age/keys.txt"))

        ;; Configure with PGP (if used)
        (when (executable-find "gpg")
          (setq sops-use-gpg t))

        ;; Key bindings for SOPS operations
        :bind (:map sops-mode-map
                    ("C-c C-s e" . sops-encrypt-buffer)
                    ("C-c C-s d" . sops-decrypt-buffer)
                    ("C-c C-s c" . sops-show-comment)))

      ;; Dashboard configuration
      (use-package dashboard
        :init
        (setq dashboard-banner-logo-title "Welcome to NixOS Emacs")
        (setq dashboard-startup-banner "~/.emacs.d/nixos-banner.txt")
        (setq dashboard-center-content t)
        :config
        ;; Fix the all-the-icons dependency issue
        (when (package-installed-p 'all-the-icons)
          (setq dashboard-icon-type 'all-the-icons)
          (setq dashboard-set-heading-icons t)
          (setq dashboard-set-file-icons t))
        (setq dashboard-set-navigator t)
        (setq dashboard-set-init-info t)
        (setq dashboard-items '((recents . 5)
                                (projects . 5)
                                (bookmarks . 3)))
        (dashboard-setup-startup-hook))

      ;; Add NixOS config as a default project
      (use-package projectile
        :config
        (projectile-mode +1)

        ;; Define key bindings for projectile
        (define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map)

        ;; Set projectile completion system to use ivy
        (setq projectile-completion-system 'ivy)

        ;; Add NixOS config directory as a known project
        (when (file-directory-p "/home/${config.home.username}/.config/nixos")
          (setq projectile-project-search-path '("/home/${config.home.username}/.config/nixos"))

          ;; Add custom function to open NixOS config quickly
          (defun open-nixos-config ()
            "Open NixOS configuration directory in projectile"
            (interactive)
            (projectile-switch-project-by-name "/home/${config.home.username}/.config/nixos"))

          ;; Add custom project type for NixOS configurations
          (projectile-register-project-type 'nixos
                                          '("flake.nix" "configuration.nix")
                                          :project-file "flake.nix"
                                          :compile "nixos-rebuild build"
                                          :test "nixos-rebuild test"
                                          :run "nixos-rebuild switch"
                                          :test-suffix "_test")))

      ;; Doom modeline configuration
      (use-package doom-modeline
        :hook (after-init . doom-modeline-mode)
        :custom
        (doom-modeline-height 25)
        (doom-modeline-bar-width 3)
        (doom-modeline-icon t)
        (doom-modeline-major-mode-icon t)
        (doom-modeline-minor-modes nil)
        (doom-modeline-enable-word-count t)
        (doom-modeline-buffer-file-name-style 'relative-to-project)
        (doom-modeline-display-default-persp-name t)
        (doom-modeline-modal-icon t))

      ;; Copilot Configuration
      (use-package copilot
        :hook (prog-mode . copilot-mode)
        :config
        (define-key copilot-mode-map (kbd "C-TAB") 'copilot-accept-completion)
        (define-key copilot-mode-map (kbd "C-<tab>") 'copilot-accept-completion))

      ;; Copilot Chat Configuration
      (use-package copilot-chat
        :after copilot
        :config
        (setq copilot-chat-model "gpt-4o-mini") ;; Default model
        (setq copilot-chat-max-tokens 4096)
        (setq copilot-chat-show-response-inline nil)
        (setq copilot-chat-dedicated-window t)
        (setq copilot-chat-prompts
              '(("explain-code" . "Explain this code: {{buffer-text}}")
                ("optimize-code" . "Optimize this code: {{buffer-text}}")
                ("document-code" . "Write documentation for this code: {{buffer-text}}")
                ("find-bugs" . "Find bugs in this code: {{buffer-text}}")
                ("suggest-tests" . "Suggest tests for this code: {{buffer-text}}")))

        ;; Set up keybindings for copilot-chat
        (global-set-key (kbd "C-c C-c") 'copilot-chat-mode))


      ;; LSP mode configuration
      (use-package lsp-mode
        :hook ((python-mode . lsp)
               (rust-mode . lsp)
               (go-mode . lsp)
               (typescript-mode . lsp)
               (js-mode . lsp)
               (web-mode . lsp)
               (c-mode . lsp)
               (c++-mode . lsp)
               (terraform-mode . lsp))
        :commands lsp
        :config
        (setq lsp-keymap-prefix "C-c l")
        (setq lsp-enable-indentation t)
        (setq lsp-enable-on-type-formatting t)
        (setq lsp-enable-symbol-highlighting t)
        (setq lsp-headerline-breadcrumb-enable t)
        (setq lsp-modeline-diagnostics-enable t)
        ;; Language-specific LSP configurations
        (lsp-register-client
         (make-lsp-client :new-connection (lsp-stdio-connection '("terraform-ls" "serve"))
                          :major-modes '(terraform-mode)
                          :server-id 'terraform-ls))

        (lsp-register-client
         (make-lsp-client :new-connection (lsp-stdio-connection '("pyright-langserver" "--stdio"))
                          :major-modes '(python-mode)
                          :server-id 'pyright
                          :multi-root t))

        (lsp-register-client
         (make-lsp-client :new-connection (lsp-stdio-connection '("gopls"))
                          :major-modes '(go-mode)
                          :server-id 'gopls
                          :priority 0)))

      ;; LSP UI enhancements
      (use-package lsp-ui
        :after lsp-mode
        :config
        (setq lsp-ui-doc-enable t)
        (setq lsp-ui-doc-position 'at-point)
        (setq lsp-ui-sideline-enable t)
        (setq lsp-ui-sideline-show-code-actions t)
        (setq lsp-ui-sideline-show-diagnostics t))

      ;; Treemacs integration for project tree view
      (use-package lsp-treemacs
        :after (lsp-mode treemacs))

      ;; Treemacs configuration with icons
      (use-package treemacs
        :config
        (setq treemacs-position 'left
              treemacs-width 35
              treemacs-indentation 2
              treemacs-git-integration t
              treemacs-collapse-dirs 3
              treemacs-silent-refresh t
              treemacs-change-root-without-asking t
              treemacs-sorting 'alphabetic-asc
              treemacs-show-hidden-files t
              treemacs-persist-file (expand-file-name "treemacs-persist" user-emacs-directory))

        :bind
        (("C-c t t" . treemacs)
         ("C-c t b" . treemacs-bookmark)
         ("C-c t f" . treemacs-find-file)
         ("C-c t p" . treemacs-projectile)))

      ;; Treemacs all-the-icons integration
      (use-package treemacs-all-the-icons
        :if (display-graphic-p)
        :after (treemacs all-the-icons)
        :config
        ;; Use all-the-icons as the default theme
        (treemacs-load-theme "all-the-icons"))

      ;; Treemacs nerd-icons integration
      (use-package treemacs-nerd-icons
        :if (display-graphic-p)
        :after treemacs
        :config
        ;; Uncomment this line and comment out the all-the-icons theme if you prefer nerd icons
        ;; (treemacs-load-theme "nerd-icons")
        )

      ;; Company for autocompletion
      (use-package company
        :hook (after-init . global-company-mode)
        :config
        (setq company-minimum-prefix-length 1
              company-idle-delay 0.1))

      ;; Magit for Git integration
      (use-package magit
        :bind ("C-x g" . magit-status))

      ;; Projectile for project management
      (use-package projectile
        :config
        (projectile-mode +1)
        (define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map))

      ;; Flycheck for real-time syntax checking
      (use-package flycheck
        :init (global-flycheck-mode))

      ;; Nix mode configuration with performance optimizations
      (use-package nix-mode
        :mode "\\.nix\\'"
        ;; Remove automatic LSP connection to prevent hanging
        ;; :hook (nix-mode . lsp-deferred)
        :config
        ;; Performance optimizations for nix-mode
        (setq blink-matching-delay 0.5) ;; Reduce blink matching delay
        (setq font-lock-maximum-decoration 2) ;; Reduce font-lock decoration level
        (setq jit-lock-defer-time 0.05) ;; Increase jit-lock defer time slightly

        ;; Large file optimizations
        (defun my/nix-mode-setup ()
          ;; Disable features that can cause hangs for large Nix files
          (when (> (buffer-size) 100000)  ;; For files larger than ~100KB
            (font-lock-mode -1)
            (when (bound-and-true-p lsp-mode)
              (lsp-disconnect)))

          ;; Base nix-mode settings
          (setq-local indent-tabs-mode nil)
          (setq-local tab-width 2)
          (setq-local nix-indent-function 'nix-indent-line)

          ;; Manually enable LSP if desired via M-x lsp command
          (local-set-key (kbd "C-c C-l") 'lsp))

        (add-hook 'nix-mode-hook 'my/nix-mode-setup))

      ;; Configure nixd as a more efficient LSP server for Nix
      (with-eval-after-load 'lsp-mode
        (lsp-register-client
         (make-lsp-client
          :new-connection (lsp-stdio-connection
                           (lambda ()
                             (if (executable-find "nixd")
                                 '("nixd" "--log-file" "/tmp/nixd.log" "--log-level" "error")
                               '("nixd"))))
          :major-modes '(nix-mode)
          :server-id 'nixd
          :priority 1
          ;; Set initialization options to reduce workload
          :initialization-options '(:diagnostics (:enabled t)
                                    :formatting (:enabled t)
                                    :completion (:enable t)))))

      ;; Format Nix code on save with nixpkgs-fmt (only when explicitly enabled)
      (use-package nixpkgs-fmt
        :if (executable-find "nixpkgs-fmt")
        :commands (nixpkgs-fmt nixpkgs-fmt-buffer nixpkgs-fmt-on-save-mode)
        :init
        ;; Don't enable formatting on save by default - can be enabled per project
        ;; :hook (nix-mode . nixpkgs-fmt-on-save-mode)
        )

      ;; Nix prettify symbols mode - keep disabled by default for performance
      (use-package nix-prettify-mode
        :commands nix-prettify-mode)

      ;; direnv integration for loading environment from .envrc files
      (use-package envrc
        :config
        (envrc-global-mode))

      ;; Terraform mode configuration
      (use-package terraform-mode
        :mode ("\\.tf\\'" "\\.tfvars\\'")
        :hook (terraform-mode . lsp-deferred)
        :config
        (add-hook 'terraform-mode-hook
                  (lambda ()
                    (setq-local indent-tabs-mode nil)
                    (setq-local terraform-indent-level 2))))

      ;; Company backend for Terraform
      (use-package company-terraform
        :after (company terraform-mode)
        :config
        (company-terraform-init))

      ;; Markdown mode configuration
      (use-package markdown-mode
        :mode ("\\.md\\'" "\\.markdown\\'")
        :config
        ;; Use pandoc for markdown processing if available, otherwise fallback to markdown
        (setq markdown-command
              (cond
               ((executable-find "pandoc") "pandoc -f markdown -t html")
               ((executable-find "multimarkdown") "multimarkdown")
               (t "markdown")))
        (setq markdown-fontify-code-blocks-natively t)
        (setq markdown-enable-wiki-links t)
        (add-hook 'markdown-mode-hook 'visual-line-mode))

      ;; Markdown TOC generation
      (use-package markdown-toc
        :after markdown-mode
        :config
        (setq markdown-toc-user-toc-structure-manipulation-fn 'identity))

      ;; GitHub-flavored Markdown preview with grip-mode
      (use-package grip-mode
        :after markdown-mode
        :config
        (setq grip-preview-use-webkit nil))

      ;; Python mode configuration
      (use-package python-mode
        :mode "\\.py\\'"
        :hook (python-mode . lsp-deferred)
        :config
        (setq python-indent-offset 4)
        (setq python-shell-interpreter "python3"))

      ;; Format Python code on save with black
      (use-package blacken
        :hook (python-mode . blacken-mode)
        :config
        (setq blacken-line-length 88))

      ;; Sort Python imports on save with isort
      (use-package py-isort
        :hook (python-mode . py-isort-enable-on-save)
        :config
        (setq py-isort-options '("--profile" "black")))

      ;; Python docstring support
      (use-package python-docstring
        :hook (python-mode . python-docstring-mode))

      ;; Python test framework with pytest
      (use-package python-pytest
        :after python-mode
        :config
        (setq python-pytest-confirm nil))

      ;; Go mode configuration
      (use-package go-mode
        :mode "\\.go\\'"
        :hook (go-mode . lsp-deferred)
        :config
        (add-hook 'go-mode-hook
                  (lambda ()
                    (setq-local tab-width 4)
                    (setq-local indent-tabs-mode t))))

      ;; Go documentation lookup
      (use-package go-eldoc
        :hook (go-mode . go-eldoc-setup))

      ;; Go code navigation
      (use-package go-guru
        :hook (go-mode . go-guru-hl-identifier-mode))

      ;; Go testing tools
      (use-package gotest
        :after go-mode
        :config
        (define-key go-mode-map (kbd "C-c C-t") 'go-test-current-file))

      ;; Go struct tag management
      (use-package go-tag
        :after go-mode
        :config
        (setq go-tag-args (list "-transform" "camelcase")))

      ;; Go test generation
      (use-package go-gen-test
        :after go-mode)

      ;; Email configuration (mu4e)
      (use-package mu4e
        :config
        (setq mu4e-maildir "~/Mail"
              mu4e-get-mail-command "mbsync -a"
              mu4e-update-interval 300
              mu4e-compose-signature-auto-include t
              mu4e-view-show-images t
              mu4e-view-show-addresses t
              mu4e-compose-format-flowed t
              mu4e-compose-complete-addresses t)
        ;; Define multiple email accounts if needed
        ;; Example:
        (setq mu4e-contexts
              `(,(make-mu4e-context
                  :name "Personal"
                  :match-func (lambda (msg)
                                (when msg
                                  (string-prefix-p "/personal" (mu4e-message-field msg :maildir))))
                  :vars '((user-mail-address . "olaf.loken@gmail.com")
                          (user-full-name . "Your Name")
                          (mu4e-sent-folder . "/personal/Sent")
                          (mu4e-drafts-folder . "/personal/Drafts")
                          (mu4e-trash-folder . "/personal/Trash")
                          (mu4e-refile-folder . "/personal/Archive")))
                ,(make-mu4e-context
                  :name "Work"
                  :match-func (lambda (msg)
                                (when msg
                                  (string-prefix-p "/work" (mu4e-message-field msg :maildir))))
                  :vars '((user-mail-address . "olaf@freundcloud.com")
                          (user-full-name . "Your Work Name")
                          (mu4e-sent-folder . "/work/Sent")
                          (mu4e-drafts-folder . "/work/Drafts")
                          (mu4e-trash-folder . "/work/Trash")
                          (mu4e-refile-folder . "/work/Archive"))))))

      ;; RSS Feed Reader with Elfeed
      (use-package elfeed
        :config
        (setq elfeed-feeds
              '(("https://news.ycombinator.com/rss" tech news)
                ("https://planet.nixos.org/rss20.xml" nix nixos)
                ("https://lwn.net/headlines/rss" linux)
                ;; Add more feeds as needed
               )))

      ;; Org-mode enhancements
      (use-package org
        :config
        (setq org-directory "~/org")
        (setq org-default-notes-file (concat org-directory "/notes.org"))
        (setq org-log-done t)
        (setq org-startup-indented t)
        (setq org-startup-with-inline-images t)
        (setq org-pretty-entities t)
        (setq org-hide-emphasis-markers t))

      ;; Org-roam for networked note-taking
      (use-package org-roam
        :custom
        (org-roam-directory (file-truename "~/org-roam"))
        :config
        ;; Create org-roam directory if it doesn't exist
        (unless (file-directory-p org-roam-directory)
          (make-directory org-roam-directory t))
        ;; Initialize org-roam
        (org-roam-db-autosync-mode))

      ;; Additional language specific modes
      (use-package yaml-mode
        :mode "\\.ya?ml\\'")

      ;; Web mode
      (use-package web-mode
        :mode (("\\.html?\\'" . web-mode)
               ("\\.css\\'" . web-mode)
               ("\\.jsx?\\'" . web-mode)
               ("\\.tsx?\\'" . web-mode))
        :config
        (setq web-mode-markup-indent-offset 2)
        (setq web-mode-code-indent-offset 2)
        (setq web-mode-css-indent-offset 2))

      ;; Rainbow delimiters for better visualizing nested parentheses
      (use-package rainbow-delimiters
        :hook (prog-mode . rainbow-delimiters-mode))

      ;; Which-key for command assistance - completely revised configuration
      (use-package which-key
        ;; Initialize which-key earlier in the startup process
        :demand t
        :init
        ;; Use these settings before loading which-key
        (setq which-key-separator " → ")
        (setq which-key-prefix-prefix "+")
        (setq which-key-sort-order 'which-key-key-order-alpha)

        ;; Show which-key earlier when pressing C-h
        (setq which-key-show-early-on-C-h t)

        :config
        ;; Use right-bottom layout as per https://github.com/justbur/emacs-which-key
        ;; Shows which-key on right if there's room, otherwise bottom
        (which-key-setup-side-window-right-bottom)

        ;; Set a shorter delay time for which-key to pop up (seconds)
        (setq which-key-idle-delay 0.3)
        (setq which-key-idle-secondary-delay 0.05)

        ;; Maximum height/width of which-key popup (in % of frame size)
        (setq which-key-side-window-max-height 0.33)
        (setq which-key-allow-evil-operators t)
        (setq which-key-show-operator-state-maps t)

        ;; Use standard prefix key replacement ("<f1>" → "F1")
        (setq which-key-replacement-alist
              '((("TAB" . nil) . ("↹" . nil))
                (("RET" . nil) . ("⏎" . nil))
                (("DEL" . nil) . ("⌫" . nil))
                (("SPC" . nil) . ("␣" . nil))))

        ;; Show prefix on top
        (setq which-key-show-prefix 'top)

        ;; Add additional key bindings to access which-key directly
        (global-set-key (kbd "C-h b") 'which-key-show-top-level)
        (global-set-key (kbd "C-h m") 'which-key-show-major-mode)

        ;; Explicitly enable which-key mode
        (which-key-mode 1))
    '';

    ".emacs.d/custom-vars.el".text = ''
      ;; This file is for custom-set-variables and custom-set-faces.
      ;; It is automatically generated by Emacs.
    '';
  };

  # Add all required Emacs packages
  home.packages = with pkgs; [
    # Base packages
    mu
    isync
    offlineimap
    fzf # Required for Emacs fzf integration
    bat # For fzf preview functionality
    sops # Required for sops plugin
    age # For age encryption
    # agenix # For agenix secret management

    # Language servers and development tools
    nixd # Nix LSP server
    nixpkgs-fmt # Nix formatter
    terraform-ls # Terraform LSP server
    nodePackages.typescript-language-server # TS/JS language server
    nodePackages.vscode-langservers-extracted # HTML/CSS/JSON/ESLint
    nodePackages.bash-language-server # Shell language server
    pyright # Python LSP server
    black # Python formatter
    python311Packages.isort # Python import sorting
    gopls # Go LSP server
    gotools # Go tools (guru, etc.)
    golangci-lint # Go linter
    rust-analyzer # Rust LSP server
    haskell-language-server # Haskell LSP server
    clang-tools # C/C++ language server

    # Additional tools
    grip # GitHub-flavored Markdown preview
    direnv # Directory environment management
    pandoc # Universal document converter for markdown
  ];
}

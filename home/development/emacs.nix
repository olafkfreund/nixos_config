{
  config,
  lib,
  pkgs,
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

        # Start page and dashboard
        dashboard
        page-break-lines
        all-the-icons-dired
        projectile

        # Evil mode and extensions
        evil
        evil-collection
        evil-commentary
        evil-surround

        # Additional Evil packages
        evil-anzu
        evil-args
        evil-escape
        evil-exchange
        evil-goggles
        evil-indent-plus
        evil-leader
        evil-lion
        evil-matchit
        evil-mc
        evil-multiedit
        evil-nerd-commenter
        evil-numbers
        evil-org
        evil-snipe
        evil-textobj-entire
        evil-visualstar
        evil-terminal-cursor-changer
        treemacs-evil

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
        evil-mu4e

        # RSS reader
        elfeed
        elfeed-org

        # Org mode and note-taking
        org
        org-roam
        org-bullets
        org-present
        org-download
        org-evil

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

      ;; Set evil-want-keybinding to nil BEFORE evil is loaded
      (setq evil-want-keybinding nil)

      ;; Configure evil-want-integration early
      (setq evil-want-integration t)
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

      ;; Dashboard configuration
      (use-package dashboard
        :init
        (setq dashboard-banner-logo-title "Welcome to Emacs")
        (setq dashboard-startup-banner 'official)
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
        :after evil
        :config
        (projectile-mode +1)

        ;; Define key bindings for projectile
        (define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map)

        ;; Only set evil keybindings if evil-normal-state-map is available
        (with-eval-after-load 'evil
          (when (and (featurep 'evil) (boundp 'evil-normal-state-map))
            (define-key evil-normal-state-map (kbd "<leader> p") 'projectile-command-map)))

        ;; Set projectile completion system to use ivy
        (setq projectile-completion-system 'ivy)

        ;; Add NixOS config directory as a known project
        (when (file-directory-p "/home/olafkfreund/.config/nixos")
          (setq projectile-project-search-path '("/home/olafkfreund/.config/nixos"))

          ;; Add custom function to open NixOS config quickly
          (defun open-nixos-config ()
            "Open NixOS configuration directory in projectile"
            (interactive)
            (projectile-switch-project-by-name "/home/olafkfreund/.config/nixos"))

          ;; Add keybinding for quick access (only if evil-leader is available)
          (with-eval-after-load 'evil-leader
            (evil-leader/set-key "N" 'open-nixos-config))

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

      ;; Evil mode configuration
      (use-package evil
        :init
        ;; evil-want-keybinding is set in early-init.el
        (setq evil-vsplit-window-right t)
        (setq evil-split-window-below t)
        (setq evil-undo-system 'undo-redo)
        :config
        (evil-mode 1))

      ;; Evil collection for better evil integration
      (use-package evil-collection
        :after evil
        :config
        (evil-collection-init))

      ;; Evil leader for Vim-like leader key functionality
      (use-package evil-leader
        :after evil
        :config
        (global-evil-leader-mode)
        (evil-leader/set-leader "<SPC>")
        (evil-leader/set-key
          "f" 'find-file
          "b" 'switch-to-buffer
          "k" 'kill-buffer
          "g" 'magit-status
          "p" 'projectile-command-map
          "t" 'treemacs
          "l" 'lsp-command-map
          "d" 'dashboard-refresh-buffer
          ;; Fix for key sequence error - separate keys with more distinct prefixes
          "cc" 'copilot-chat-mode
          "ca" 'copilot-chat-ask
          "cg" 'copilot-chat-generate
          "ce" 'copilot-chat-explain
          "cx" 'copilot-chat-explain-inline)) ;; Changed from "ci" to "cx" to avoid conflict

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

      ;; Evil commentary for commenting code
      (use-package evil-commentary
        :after evil
        :config
        (evil-commentary-mode))

      ;; Evil surround for delimiters manipulation
      (use-package evil-surround
        :after evil
        :config
        (global-evil-surround-mode 1))

      ;; Evil matchit for jumping between matching tags/blocks
      (use-package evil-matchit
        :after evil
        :config
        (global-evil-matchit-mode 1))

      ;; Evil numbers for incrementing/decrementing
      (use-package evil-numbers
        :after evil
        :config
        (define-key evil-normal-state-map (kbd "C-a") 'evil-numbers/inc-at-pt)
        (define-key evil-normal-state-map (kbd "C-x") 'evil-numbers/dec-at-pt))

      ;; Evil snipe for better 2-char searching
      (use-package evil-snipe
        :after evil
        :config
        (evil-snipe-mode 1)
        (evil-snipe-override-mode 1))

      ;; Evil multicursor support
      (use-package evil-mc
        :after evil
        :config
        (global-evil-mc-mode 1))

      ;; Evil visualstar for searching visual selections
      (use-package evil-visualstar
        :after evil
        :config
        (global-evil-visualstar-mode))

      ;; Evil terminal cursor changer for terminal mode
      (use-package evil-terminal-cursor-changer
        :after evil
        :config
        (unless (display-graphic-p)
          (evil-terminal-cursor-changer-activate)))

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
               (nix-mode . lsp)
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
         (make-lsp-client :new-connection (lsp-stdio-connection '("nixd"))
                          :major-modes '(nix-mode)
                          :server-id 'nixd))

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

      ;; Treemacs evil integration
      (use-package treemacs-evil
        :after (treemacs evil))

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

      ;; Nix mode configuration
      (use-package nix-mode
        :mode "\\.nix\\'"
        :hook (nix-mode . lsp-deferred)
        :config
        (add-hook 'nix-mode-hook
                  (lambda ()
                    (setq-local indent-tabs-mode nil)
                    (setq-local tab-width 2)
                    (setq-local nix-indent-function 'nix-indent-line))))

      ;; Format Nix code on save with nixpkgs-fmt
      (use-package nixpkgs-fmt
        :if (executable-find "nixpkgs-fmt")
        :hook (nix-mode . nixpkgs-fmt-on-save-mode))

      ;; Nix prettify symbols mode
      (use-package nix-prettify-mode
        :hook (nix-mode . nix-prettify-mode))

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
                  :vars '((user-mail-address . "personal@example.com")
                          (user-full-name . "Your Name")
                          (mu4e-sent-folder . "/personal/Sent")
                          (mu4e-drafts-folder . "/personal/Drafts")
                          (mu4e-trash-folder . "/personal/Trash")
                  :match-func (lambda (msg)
                                (when msg
                                  (string-prefix-p "/work" (mu4e-message-field msg :maildir))))
                  :vars '((user-mail-address . "work@example.com")
                          (user-full-name . "Your Work Name")
                          (mu4e-sent-folder . "/work/Sent")
                          (mu4e-drafts-folder . "/work/Drafts")
                          (mu4e-trash-folder . "/work/Trash")
                          (mu4e-refile-folder . "/work/Archive"))))))

      ;; Ensure mu4e is fully loaded before loading evil-mu4e
      (use-package evil-mu4e
        :after (evil mu4e)
        :defer t
        :config
        ;; Ensure mu4e is fully initialized before configuring evil-mu4e
        (with-eval-after-load 'mu4e
          (require 'evil-mu4e)))

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

      ;; Fix for org-evil
      (use-package org-evil
        :after (evil org)
        :demand t  ;; Ensure it's loaded immediately after dependencies
        :config
        ;; Make sure org-evil is properly initialized before accessing its features
        (require 'org-evil-core)
        (require 'org-evil-motion)

        ;; Define the mode variable if it doesn't exist
        (unless (boundp 'org-evil-motion-mode)
          (defvar org-evil-motion-mode nil
            "Non-nil if Org-Evil-Motion mode is enabled.")
          (make-variable-buffer-local 'org-evil-motion-mode))

        ;; Ensure org-evil motion mode is properly initialized
        (when (fboundp 'org-evil-motion-mode)
          (add-hook 'org-mode-hook 'org-evil-motion-mode)))

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

      ;; Which-key for command assistance
      (use-package which-key
        :config
        ;; Configure which-key to display on the left side
        (setq which-key-side-window-location 'left)

        ;; Set a smaller delay time for which-key to pop up (seconds)
        (setq which-key-idle-delay 0.5)

        ;; Maximum height of which-key popup (in % of frame height)
        (setq which-key-side-window-max-height 0.33)

        ;; Width of which-key popup (in % of frame width)
        (setq which-key-side-window-max-width 0.33)

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

        ;; Enable which-key mode
        (which-key-mode))

      ;; Additional evil bindings for language-specific modes
      (evil-define-key 'normal python-mode-map
        (kbd "<leader>tt") 'python-pytest-function
        (kbd "<leader>tf") 'python-pytest-file
        (kbd "<leader>tp") 'python-pytest-project
        (kbd "<leader>tr") 'python-pytest-repeat)

      (evil-define-key 'normal go-mode-map
        (kbd "<leader>tt") 'go-test-current-test
        (kbd "<leader>tf") 'go-test-current-file
        (kbd "<leader>tp") 'go-test-current-project)

      (evil-define-key 'normal terraform-mode-map
        (kbd "<leader>ti") 'terraform-init
        (kbd "<leader>tp") 'terraform-plan
        (kbd "<leader>ta") 'terraform-apply)

      (evil-define-key 'normal markdown-mode-map
        (kbd "<leader>tt") 'markdown-toc-generate-toc
        (kbd "<leader>tp") 'grip-mode)
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

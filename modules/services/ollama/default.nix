{
  config,
  lib,
  pkgs,
  pkgs-stable,
  ...
}:
with lib; let
  cfg = config.ai.ollama;
in {
  options.ai.ollama = {
    enable = mkEnableOption {
      default = false;
      description = "Enable the OLLAMA service";
    };
    enableRag = mkEnableOption {
      default = false;
      description = "Enable RAG capabilities with vector database";
    };
    allowBrokenPackages = mkOption {
      type = types.bool;
      default = false;
      description = "Allow installation of broken packages like spaCy";
    };
    ragDirectory = mkOption {
      type = types.str;
      default = "/mnt/data/rag-files";
      description = "Directory for storing files to be scanned for RAG";
    };
  };
  config = mkMerge [
    (mkIf cfg.enable {
      services.ollama = {
        enable = true;
        package = pkgs.ollama;
        acceleration = "cuda";
        host = "0.0.0.0";
        loadModels = [
          "mistral-small3.1"
          "GandalfBaum/llama3.2-claude3.7"
          "nomic-embed-text"
        ];
        user = "ollama";
      };

      services.open-webui = {
        enable = true;
        host = "0.0.0.0";
        port = 8080;
        package = pkgs-stable.open-webui;
        environment = {
          OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
          WEBUI_AUTH = "False";
        };
      };
      environment.systemPackages = [
        pkgs.alpaca
      ];
    })

    (mkIf (cfg.enable && cfg.enableRag) {
      # Vector database for RAG
      services.chromadb = {
        enable = true;
        port = 8000;
        host = "0.0.0.0";
      };

      # Skip broken packages regardless of allowBrokenPackages setting
      # This prevents build errors with Python 3.12 + spaCy/llama-index
      nixpkgs.config.allowBroken = false;

      # Add RAG-related tools to system packages - avoid spaCy and llama-index
      environment.systemPackages = with pkgs; [
        python3Packages.chromadb
        python3Packages.transformers
        python3Packages.sentence-transformers
        # Document processing packages - minimal set to avoid dependency issues
        python3Packages.pypdf
        python3Packages.docx2txt
        python3Packages.python-pptx
        python3Packages.pillow
        python3Packages.markdown
      ];

      # Create directories for RAG files with proper permissions
      systemd.tmpfiles.rules = [
        "d /var/lib/open-webui/rag 0755 nobody nobody - -"
        "d ${cfg.ragDirectory} 0755 ollama ollama - -"
        "d /var/lib/chromadb 0755 nobody nobody - -"
      ];

      # Configure Open WebUI to support RAG with file scanning
      services.open-webui.environment = {
        # Existing configuration
        OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
        WEBUI_AUTH = "False";
        # RAG configuration - using direct ChromaDB integration
        WEBUI_EMBEDDING_ENGINE = "ollama";
        WEBUI_EMBEDDING_MODEL = "nomic-embed-text";
        WEBUI_RAG = "True";
        WEBUI_DB_PATH = "/var/lib/open-webui/rag";
        CHROMA_SERVER_HOST = "127.0.0.1";
        CHROMA_SERVER_PORT = "8000";
        CHROMA_SERVER_HTTP_PORT = "8000"; # Explicitly set HTTP port
        # Collection settings
        WEBUI_COLLECTION_NAME = "open_webui_collection";
        # Backend settings
        BACKEND_TYPE = "chromadb"; # Explicitly set the backend type
        # File scanning directories
        WEBUI_FILE_SYSTEM_PATHS = "${cfg.ragDirectory}";
        # Enable file watching to auto-index new files
        WEBUI_WATCH_FILESYSTEM = "True";
        # Debug mode to identify issues
        WEBUI_DEBUG = "True";
      };
    })
  ];
}

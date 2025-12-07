# Ollama and RAG Configuration Guide

This module provides a NixOS configuration for setting up [Ollama](https://ollama.ai/) with Retrieval-Augmented Generation (RAG) capabilities using ChromaDB as the vector database.

## Table of Contents

- [Features](#features)
- [Configuration Options](#configuration-options)
- [Usage Examples](#usage-examples)
- [RAG File Support](#rag-file-support)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

## Features

- **Local LLM Execution**: Run powerful large language models locally on your machine
- **RAG Support**: Query your documents and get AI responses based on your own data
- **File Scanning**: Automatically scan and index documents from designated folders
- **ChromaDB Integration**: High-performance vector database for semantic search
- **AMD ROCm Support**: Optimized for AMD GPUs with ROCm acceleration
- **CUDA Support**: Optimized for NVIDIA GPUs with CUDA acceleration

## Configuration Options

This module exposes the following NixOS options:

| Option                          | Type    | Default                     | Description                                                                   |
| ------------------------------- | ------- | --------------------------- | ----------------------------------------------------------------------------- |
| `ai.ollama.enable`              | boolean | `false`                     | Enable the Ollama service                                                     |
| `ai.ollama.enableRag`           | boolean | `false`                     | Enable RAG with ChromaDB integration                                          |
| `ai.ollama.ragDirectory`        | string  | `/var/lib/ollama/rag-files` | Directory for storing files to be scanned for RAG                             |
| `ai.ollama.allowBrokenPackages` | boolean | `false`                     | Allow installation of AI packages that might be marked as broken (like spaCy) |

## Usage Examples

### Basic Ollama Setup

```nix
# In your configuration.nix or host configuration
{
  ai.ollama = {
    enable = true;
  };
}
```

### Enabling RAG with Default Settings

```nix
# In your configuration.nix or host configuration
{
  ai.ollama = {
    enable = true;
    enableRag = true;
  };
}
```

### Custom RAG Configuration

```nix
# In your configuration.nix or host configuration
{
  ai.ollama = {
    enable = true;
    enableRag = true;
    ragDirectory = "/home/user/documents/rag-files"; # Custom directory for RAG files
    allowBrokenPackages = true; # Allow potentially broken packages like spaCy
  };
}
```

### GPU Acceleration with AMD ROCm

```nix
# In your configuration.nix or host configuration
{
  ai.ollama = {
    enable = true;
    enableRag = true;
  };

  # Configure ROCm acceleration (modern package-based approach)
  services.ollama.package = pkgs.ollama-rocm;
  services.ollama.rocmOverrideGfx = "11.0.0"; # Set to your GPU architecture
  services.ollama.environmentVariables = {
    HCC_AMDGPU_TARGET = "gfx1100"; # Set to your GPU architecture
    ROC_ENABLE_PRE_VEGA = "1";
    HSA_OVERRIDE_GFX_VERSION = "11.0.0"; # Set to your GPU architecture
  };
}
```

### GPU Acceleration with NVIDIA CUDA

```nix
# In your configuration.nix or host configuration
{
  ai.ollama = {
    enable = true;
    enableRag = true;
  };

  # Configure CUDA acceleration (modern package-based approach)
  services.ollama.package = pkgs.ollama-cuda;
}
```

## RAG File Support

The RAG system supports the following file types:

- PDF documents (`.pdf`)
- Microsoft Word documents (`.docx`)
- Microsoft PowerPoint presentations (`.pptx`)
- Microsoft Excel spreadsheets (`.xlsx`)
- Text files (`.txt`)
- Markdown files (`.md`)
- HTML files (`.html`)
- Rich Text Format files (`.rtf`)
- CSV files (`.csv`)
- JSON files (`.json`)

### Adding Files to RAG

Simply place your files in the configured RAG directory, and they will be automatically indexed:

```bash
cp your-document.pdf /path/to/your/rag-directory/
```

The system will scan the directory for new files and add them to the vector database. This process occurs:

- When files are added to the directory
- When the Open WebUI service starts up
- When you manually trigger indexing from the Open WebUI interface

## Using RAG in Open WebUI

Open WebUI is available at `http://localhost:8080` by default. Once logged in:

1. Go to the "RAG" section in the sidebar
2. You'll see all your indexed documents
3. Create new chats and ask questions about your documents
4. The AI will reference your documents when providing answers

## Troubleshooting

### RAG Not Finding Document Content

If the RAG system isn't finding content from your documents:

1. Check that you're using a model that supports context (recommended: `mistral-small`, `llama3`, or similar)
2. Verify the files are in the correct directory and properly indexed
3. Ensure the embedding model is properly loaded (default: `nomic-embed-text`)
4. Check the ChromaDB logs for any errors: `journalctl -u chromadb`

### GPU Acceleration Issues

For ROCm (AMD) issues:

- Verify your GPU is supported by ROCm
- Check that the `gfx` version matches your hardware
- Examine the Ollama logs: `journalctl -u ollama`

For CUDA (NVIDIA) issues:

- Ensure NVIDIA drivers are properly installed
- Verify CUDA compatibility with your GPU model
- Check CUDA-related logs: `journalctl -u ollama | grep -i cuda`

## Advanced Configuration

### ChromaDB Settings

The ChromaDB vector database is configured automatically with the RAG setup. If you need custom settings:

```nix
services.chromadb = {
  enable = true;
  port = 8000;  # Default port
  host = "0.0.0.0";  # Listen on all interfaces
  # Add any other ChromaDB configurations here
};
```

### Open WebUI Custom Configuration

To customize the Open WebUI interface for Ollama:

```nix
services.open-webui = {
  enable = true;
  host = "0.0.0.0";
  port = 8080;
  environment = {
    # Default RAG configuration (automatically set when enableRag = true)
    WEBUI_EMBEDDING_ENGINE = "ollama";  # Can be "openai", "ollama", etc.
    WEBUI_EMBEDDING_MODEL = "nomic-embed-text";  # Default embedding model
    WEBUI_RAG = "True";
    WEBUI_DB_PATH = "/var/lib/open-webui/rag";
    CHROMA_SERVER_HOST = "127.0.0.1";
    CHROMA_SERVER_PORT = "8000";

    # Other custom settings
    WEBUI_AUTH = "False";  # Disable authentication
  };
};
```

### Using Multiple RAG Directories

If you want to scan multiple directories, you can set up a comma-separated list:

```nix
services.open-webui.environment = {
  # ...existing settings...
  WEBUI_FILE_SYSTEM_PATHS = "/path/to/dir1,/path/to/dir2,/path/to/dir3";
};
```

### Customizing Embedding Models

For better embeddings with specific types of documents:

```nix
services.ollama.loadModels = [
  "mistral-small3.1"  # Main language model
  "nomic-embed-text"  # General text embedding model
  "jina-embeddings-v2-base-en"  # Alternative embedding model
];

services.open-webui.environment = {
  # ...existing settings...
  WEBUI_EMBEDDING_MODEL = "jina-embeddings-v2-base-en";  # Use a different embedding model
};
```

## Recommended Models

For the best RAG experience, we recommend using models with good context handling:

1. **mistral-small** - Good balance of performance and accuracy
2. **llama3** - Excellent comprehension and reasoning
3. **openchat** - Strong in conversation and document Q&A
4. **GandalfBaum/llama3.2-claude3.7** - Hybrid model with enhanced reasoning

For embedding models:

1. **nomic-embed-text** - Default embedding model with good performance
2. **all-minilm** - Lighter alternative for basic RAG needs

## Resources

- [Ollama Documentation](https://github.com/ollama/ollama/tree/main/docs)
- [ChromaDB Documentation](https://docs.trychroma.com/)
- [Open WebUI Documentation](https://docs.openwebui.com/)
- [RAG Best Practices](https://docs.llamaindex.ai/en/stable/optimizing/rag_best_practices/)

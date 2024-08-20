{ pkgs, ... }: {

  # Enable the Ollama service, which is a tool for generating text based on input
  # It uses a machine learning model to generate responses
  services.ollama = {

    # Enable the Ollama service
    enable = true;

    # The Ollama package to use
    package = pkgs.ollama;

    # The type of hardware acceleration to use. We're using CUDA for our GPU
    acceleration = "cuda";

    # The models to load. These are the specific models that Ollama will use to generate responses
    loadModels = [ "deepseek-coder-v2" "llama3.1" ];

    # The user that the Ollama service will run as
    user = "ollama";
  };

  # Enable the Next.js Ollama LLM UI service, which is a web UI for the Ollama service
  services.nextjs-ollama-llm-ui = {

    # Enable the service
    enable = true;

    # The package to use for the service
    package = pkgs.nextjs-ollama-llm-ui;
    
  };
}

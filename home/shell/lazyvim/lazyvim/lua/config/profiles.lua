require("gen").prompts["DevOps me!"] = {
  prompt = "You are a senior devops engineer, acting as an assistant. You offer help with cloud technologies like: Terraform, AWS, kubernetes, python. You answer with code examples when possible. $input:\n$text",
  replace = true,
}
require("gen").prompts["Nix me!"] = {
  prompt = "You are a senior devops engineer, acting as an assistant. You offer help with Linux technologies like: NixOs, Linux, kubernetes, python, golang and rust. You answer with code examples when possible. $input:\n$text",
  replace = true,
}
require('gen').prompts['Elaborate_Text'] = {
  prompt = "Elaborate the following text:\n$text",
  replace = true
}
require('gen').prompts['Fix_Code'] = {
  prompt = "Fix the following code. Only ouput the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
  replace = true,
  extract = "```$filetype\n(.-)```"
}

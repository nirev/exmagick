defmodule Mix.Tasks.Compile.ExMagick do
  use Mix.Task

  @shortdoc "compiles the exmagick library"
  def run(_) do
    distroot = Path.absname(Path.expand("priv", __DIR__))
    buildroot = Mix.Project.build_path()

    runcmd("make", [
      "--quiet",
      "distroot=#{distroot}",
      "buildroot=#{buildroot}",
      "compile",
      "install"
    ])

    Mix.Project.build_structure()
  end

  defp runcmd(cmd, args) do
    {_, 0} = System.cmd(cmd, args, into: IO.stream(:stdio, :line))
  end
end

defmodule ExMagick.Mixfile do
  use Mix.Project

  @source_url "https://github.com/Xerpa/exmagick"
  @version "1.0.0"

  def project do
    [
      app: :exmagick,
      name: "ExMagick",
      version: @version,
      elixir: "~> 1.3",
      package: package(),
      deps: deps(),
      docs: docs(),
      aliases: aliases(),
      dialyzer: [
        paths: ["_build/dev/lib/exmagick/ebin/Elixir.ExMagick.beam"],
        plt_file: System.get_env("DIALYZER_PLT") || ".dialyzer.plt"
      ],
      compilers: [:exMagick | Mix.compilers()]
    ]
  end

  defp package do
    [
      description:
        "ExMagick is a library for manipulating images interfacing " <>
          "with GraphicsMagick. It's implemented using Erlang NIFs " <>
          "(Native Implemented Functions).",
      maintainers: ["Guilherme nirev", "Diego Dsouza", "Renan Milhouse"],
      licenses: ["BSD-3-Clause"],
      files: [
        "AUTHOR",
        "bin",
        "lib",
        "makefile",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "LICENSE.md"
      ],
      links: %{
        "Changelog" => "https://hexdocs.pm/exmagick/changelog.html",
        "GitHub" => @source_url
      }
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.3.5", only: [:dev]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md": [],
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      formatters: ["html"]
    ]
  end

  defp aliases do
    [clean: ["clean", &make_clean/1]]
  end

  defp make_clean(_) do
    File.rm_rf("priv")
    build_dir = Path.dirname(Mix.Project.build_path())

    if File.exists?(build_dir) do
      for env <- File.ls!(build_dir) do
        buildroot = Path.join(build_dir, env)

        {_, 0} =
          System.cmd(
            "make",
            ["buildroot=#{buildroot}", "clean", "--quiet"],
            into: IO.stream(:stdio, :line)
          )
      end
    end
  end
end

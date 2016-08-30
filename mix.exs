defmodule Mix.Tasks.Compile.ExMagick do
  use Mix.Task

  @shortdoc "compiles the exmagick library"
  def run(_) do
    distroot  = Path.absname (Path.expand "priv", __DIR__)
    buildroot = Mix.Project.build_path
    runcmd("make", ["--quiet", "distroot=#{distroot}", "buildroot=#{buildroot}", "compile", "install"])
    Mix.Project.build_structure
  end

  defp runcmd(cmd, args) do
    {_, 0} = System.cmd(cmd, args, into: IO.stream(:stdio, :line))
  end
end

defmodule ExMagick.Mixfile do
  use Mix.Project

  def project do
    [ app: :exmagick,
      version: "0.0.3",
      elixir: "~> 1.2",
      description: description,
      package: package,
      deps: deps,
      aliases: aliases,
      dialyzer: [paths: ["_build/dev/lib/exmagick/ebin/Elixir.ExMagick.beam"]],
      compilers: [:exMagick | Mix.compilers]
    ]
  end

  defp description do
    """
    ExMagick is a library for manipulating images interfacing with GraphicsMagick.
    It's implemented using Erlang NIFs (Native Implemented Functions).
    """
  end

  defp package do
    [
      maintainers: ["Guilherme nirev", "Diego Dsouza", "Renan Milhouse"],
      licenses: ["BSD-3"],
      links: %{"GitHub" => "https://github.com/Xerpa/exmagick"},
      files: ["AUTHOR", "bin", "COPYING", "lib", "Makefile", "mix.exs", "README.md"]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.3.5", only: [:dev]},
      {:earmark, "~> 0.1", only: :dev},
      {:ex_doc, "~> 0.11", only: :dev}
    ]
  end

  defp aliases do
    [clean: ["clean", &make_clean/1]]
  end

  defp make_clean(_) do
    File.rm_rf "priv"
    build_dir = Path.dirname Mix.Project.build_path
    if File.exists? build_dir do
      for env <- File.ls!(build_dir) do
        buildroot = Path.join build_dir, env
        {_, 0} = System.cmd("make", ["buildroot=#{buildroot}", "clean", "--quiet"], into: IO.stream(:stdio, :line))
      end
    end
  end
end

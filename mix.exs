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
      deps: deps,
      elixir: "~> 1.1",
      version: "0.0.1",
      aliases: aliases,
      compilers: [:exMagick | Mix.compilers]
    ]
  end

  defp deps do
    []
  end

  defp aliases do
    [clean: ["clean", &make_clean/1]]
  end

  defp make_clean(_) do
    File.rm_rf "priv"
    dirname = Path.dirname Mix.Project.build_path
    for env <- File.ls! dirname do
      buildroot = Path.join dirname, env
      {_, 0} = System.cmd("make", ["buildroot=#{buildroot}", "clean", "--quiet"], into: IO.stream(:stdio, :line))
    end
  end
end

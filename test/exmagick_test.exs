defmodule ExMagickTest do
  use ExUnit.Case, async: true

  setup do
    tmpdir = Enum.reduce_while(0..100, nil, fn _, _ ->
      rand = :erlang.unique_integer([:positive])
      path = Path.join System.tmp_dir!, "#{rand}"
      case (File.mkdir path) do
        :ok -> {:halt, path}
        _   -> {:cont, nil}
      end
    end)
    on_exit fn ->
      File.rm_rf! tmpdir
    end
    {:ok, [tmpdir: tmpdir]}
  end

  setup_all do
    {:ok, [images: Path.expand("images/", __DIR__)]}
  end

  test "image_load(:png) and image_save(:jpg)", context do
    src = Path.join context[:images], "elixir.png"
    dst = Path.join context[:tmpdir], "elixir.jpg"
    ExMagick.image!
    |> ExMagick.image_load!(src)
    |> ExMagick.image_dump!(dst)
    assert (File.exists? dst)
  end

  test "image_load(:pdf) and image_save(:jpg)", context do
    src = Path.join context[:images], "elixir.pdf"
    dst = Path.join context[:tmpdir], "elixir.jpg"
    ExMagick.image!
    |> ExMagick.image_load!(src)
    |> ExMagick.image_dump!(dst)
    assert (File.exists? dst)
  end

  test "image_load(:pdf) and image_save([:jpg])", context do
    src = Path.join context[:images], "elixir.pdf"
    dst = Path.join context[:tmpdir], "elixir%0d.jpg"
    ExMagick.image!
    |> ExMagick.image_load!(src)
    |> ExMagick.flag!(:adjoin, false)
    |> ExMagick.image_dump!(dst)
    refute (File.exists? dst)
    assert 10 == length(File.ls! context[:tmpdir])
  end

end

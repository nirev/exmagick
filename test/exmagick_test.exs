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
  
  test "convert png image to png|jpg", context do
    src = Path.join context[:images], "elixir.png"
    dst = Path.join context[:tmpdir], "elixir.jpg"
    {:ok, image} = ExMagick.image
    assert :ok == ExMagick.image_load image, src
    assert :ok == ExMagick.image_dump image, dst
    assert (File.exists? dst)
  end
  
end
